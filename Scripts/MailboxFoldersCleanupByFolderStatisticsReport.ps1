#Requires -Version 5.1

<#
    Name        : MailboxFoldersCleanupByFolderStatisticsReport.ps1
    Version     : 0.0.0.1
    Last Update : 2020/08/30
    Created by  : Martin Schvartzman, Microsoft

    References  :
    https://docs.microsoft.com/en-us/exchange/client-developer/exchange-web-services/folders-and-items-in-ews-in-exchange
    https://msdn.microsoft.com/en-us/library/office/dd633696(v=exchg.80).aspx
    https://docs.microsoft.com/en-us/exchange/client-developer/exchange-web-services/ews-throttling-in-exchange#throttling-considerations-for-applications-that-use-ews-impersonation
    https://docs.microsoft.com/en-us/dotnet/api/microsoft.exchange.webservices.data.deletemode?view=exchange-ews-api

    Notes       :
    .\MailboxFoldersCleanupByFolderStatisticsReport.ps1 -Mailbox martin@schvartzman.onmicrosoft.com -Credential (Get-Credential) -Path C:\Temp\FoldersToDelete.csv -DeleteMode HardDelete -Impersonate -WhatIf
#>


[cmdletbinding(DefaultParameterSetName = 'CredsFile', SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0, Mandatory = $true,
        HelpMessage = 'The mailbox SmtpAddress')]
    [Alias('SMTP')] [string] $Mailbox,

    [Parameter(Position = 1, ParameterSetName = 'CredsObject',
        HelpMessage = "The credentials object acquired using 'Get-Credential'")]
    [Alias('Cred')] [PSCredential] $Credential,

    [Parameter(Position = 1, ParameterSetName = 'CredsFile',
        HelpMessage = "The deserialized encypted credentials object exported using 'Export-CliXml'")]
    [Alias('CredsFile')] [string] $CredentialFile = '.\creds.xml',

    [Parameter(Position = 2, ParameterSetName = 'CredsFile',
        HelpMessage = 'Use to prompt for the credentials to be encrypted and saved on disk')]
    [Alias('Prompt')] [switch] $CreateCredentialFile,

    [Parameter(Position = 3,
        HelpMessage = "Use to impersonate the mailbox owner. Requires the impersonate privilige on the supplied credentials' identity")]
    [Alias('UseImpersonation')] [switch] $Impersonate,

    [Parameter(Position = 4, Mandatory = $true,
        HelpMessage = 'Path to the MailboxFolderStatistics CSV report file containing *ONLY* the folders to be deleted')]
    [ValidateScript( { Test-Path -Path $_ -PathType Leaf })] $Path,

    [Parameter(Position = 5,
        HelpMessage = 'Determine the deletion mode (move to deleted itesm, move to dumpster, permanently delete')]
    [ValidateSet('MoveToDeletedItems', 'SoftDelete', 'HardDelete')] $DeleteMode = 'HardDelete'
)


#region Settings

$settings = New-Object -TypeName PSObject -Property @{

    # Exchange Web Services API Version
    EWSVersion                     = 2.2

    # Exchange CAS array or server FQDN to the exchange web service:
    EWSUrl                         = 'https://outlook.office365.com/EWS/Exchange.asmx'

    # EWS timeout in milliseconds
    EWSTimeout                     = 180000

    # Item page size (max 1000)
    ItemPageSize                   = 1000

    # EWS tracing enabled (affects performace)
    EWSTraceEnabled                = $false

    # Show verbose messages in the console
    VerboseProcess                 = $true

    # DeleteMode:
    # HardDelete                   = A folder is permanently removed from the store.
    # MoveToDeletedItems           = A folder is moved to the Deleted Items folder.
    # SoftDelete                   = A folder is moved to the dumpster if the dumpster is enabled.
    DeleteMode                     = $DeleteMode # (Changed to be a script parameter)

    # How many folder items to iterate before the next sleep (milliseconds)
    FolderIterationModulusForSleep = 100

    # How long to sleep (in milliseconds) to avoid the EWS throttling policy
    SleepMilliseconds              = 1000
}

#endregion


#region Variables

$globals = New-Object -TypeName PSObject -Property @{
    Creds                = $null
    EWSModulePath        = $null
    EWSModule            = $null
    EWSService           = $null
    LogFile              = $null
    FolderIterationCount = 0
}

#endregion


#region Helper functions

function Get-ScriptPath {
    if ($PsScriptRoot) {
        $PsScriptRoot
    } else {
        $invocation = (Get-Variable MyInvocation -Scope 1)
        if ($invocation.Value.MyCommand.Path) {
            Split-Path $invocation.Value.MyCommand.Path -Parent
        } else {
            $PWD.Path
        }
    }
}


function Write-Log {
    param($Message, [switch]$HostOnly)
    $Message = '{0:yyyy/MM/dd HH:mm:ss} - {1}' -f (Get-Date), $Message
    Write-Verbose -Message $Message -Verbose:$settings.VerboseProcess
    if (-not $HostOnly) {
        Add-Content -Value $Message -Path $globals.LogFile -Encoding UTF8 -WhatIf:$false
    }
}


function Assert-Prerequisites {

    $regVal = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Exchange\Web Services\$($settings.EWSVersion)"
    if (-not ($regVal)) {
        throw ('Microsoft Exchange Web Services Managed API is not installed. Please download and install from https://www.microsoft.com/en-us/download/details.aspx?id=42951')
    } else {
        $globals.EWSModulePath = Join-Path -Path $regVal.'Install Directory' -ChildPath 'Microsoft.Exchange.WebServices.dll'
    }

    $logsFolder = Join-Path -Path (Get-ScriptPath) -ChildPath Logs
    if (-not (Test-Path -Path $logsFolder -PathType Container)) {
        [void](New-Item -Path $logsFolder -ItemType Directory -Force -ErrorAction Stop -WhatIf:$false)
    }
    $globals.LogFile = Join-Path -Path (Get-ScriptPath) -ChildPath ('Logs\{0:yyyMMddHHmmss}_{1}.log' -f (Get-Date), $Mailbox)

    if ($settings.ItemPageSize -gt 1000) {
        $settings.ItemPageSize = 1000
    }

    switch ($PSCmdlet.ParameterSetName) {

        'CredsObject' {
            $globals.Creds = $Credential
        }

        'CredsFile' {
            if ($CreateCredentialFile) {
                $globals.Creds = Get-Credential -Message 'Please enter the credentials to save'
                if ($globals.Creds) {
                    $globals.Creds | Export-Clixml -Path $CredentialFile
                }
            } else {
                $globals.Creds = Import-Clixml -Path $CredentialFile
            }
        }
    }
    if (-not ($globals.Creds)) { throw 'Credentials not provided' }

    Write-Log 'Loading the Microsoft Exchange Web Services Managed API module' -HostOnly
    $globals.EWSModule = Import-Module -Name $globals.EWSModulePath -DisableNameChecking -PassThru
}


function Initialize-Service {
    param(
        [string] $Mailbox,
        [switch] $Impersonate
    )

    $Service = New-Object -TypeName Microsoft.Exchange.WebServices.Data.ExchangeService
    $Service.Timeout = $settings.EWSTimeout
    $Service.Url = $settings.EWSUrl
    $Service.Credentials = New-Object -TypeName Microsoft.Exchange.WebServices.Data.WebCredentials -ArgumentList $globals.Creds

    if ($settings.EWSTraceEnabled) {
        $Service.TraceEnabled = $true
        $Service.TraceFlags = [Microsoft.Exchange.WebServices.Data.TraceFlags]::DebugMessage -bor
        [Microsoft.Exchange.WebServices.Data.TraceFlags]::EwsResponse -bor
        [Microsoft.Exchange.WebServices.Data.TraceFlags]::EwsResponseHttpHeaders
        $Service.TraceEnablePrettyPrinting = $true
        $Service.EnableScpLookup = $false
    }

    $validateRedirectionUrlCallback = {
        param([string] $url)
        if ($url) { $true } else { $false }
    }

    try { $Service.AutodiscoverUrl($Mailbox, $validateRedirectionUrlCallback) } catch {}
    $Service.HttpHeaders.Add('X-AnchorMailbox', $Mailbox)
    if ($Impersonate) {
        $Service.ImpersonatedUserId = New-Object -TypeName Microsoft.Exchange.WebServices.Data.ImpersonatedUserId `
            -ArgumentList ([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress), $Mailbox
    }
    return $Service
}


function Get-ParentPath {
    param($Path, $Delimiter = '/')
    $items = $Path -split $Delimiter
    $items[0..($items.Count - 2)] -join $Delimiter
}


function Convert-FormatId {
    param($Mailbox, $folderId, [ValidateSet('EWS', 'OWA')]$Format = 'EWS', [switch]$EncodeEwsId)
    $alternateId = New-Object Microsoft.Exchange.WebServices.Data.AlternateId
    $alternateId.Mailbox = $Mailbox
    Switch ($Format) {
        'EWS' {
            $alternateId.Format = [Microsoft.Exchange.WebServices.Data.IdFormat]::OwaId
            $alternateId.UniqueId = [System.Web.HttpUtility]::UrlEncode($folderId)
            $convertedId = ($globals.EWSService).ConvertId($alternateId, [Microsoft.Exchange.WebServices.Data.IdFormat]::EwsId)
            if ($EncodeEwsId) {
                $returnId = [System.Web.HttpUtility]::UrlEncode($convertedId.UniqueId)
            } else {
                $returnId = $convertedId.UniqueId
            }
        }
        'OWA' {
            $alternateId.Format = [Microsoft.Exchange.WebServices.Data.IdFormat]::EwsId
            $alternateId.UniqueId = $folderId
            $convertedId = ($globals.EWSService).ConvertId($alternateId, [Microsoft.Exchange.WebServices.Data.IdFormat]::OwaId)
            $returnId = [System.Web.HttpUtility]::UrlDecode($convertedId.UniqueId)
        }
    }
    return $returnId
}


function Remove-MailboxFolder {
    param($FolderObject = $null)
    $iReturn = 0
    if ($FolderObject) {
        try {
            $globals.FolderIterationCount++
            if (($globals.FolderIterationCount % $settings.FolderIterationModulusForSleep) -eq 0) { Start-Sleep -Milliseconds $settings.SleepMilliseconds }
            $folder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($globals.EWSService, [Microsoft.Exchange.WebServices.Data.FolderId]$FolderObject.FolderId)
            if ($folder) {
                Write-Log -Message ("Deleting folder '{0}'" -f $FolderObject.Path)
                try {
                    $folder.Delete([Microsoft.Exchange.WebServices.Data.DeleteMode]::($settings.DeleteMode))
                    $iReturn = 1
                } catch { Write-Log -Message ("Error deleting folder '{0}': {1}" -f $FolderObject.Path, $_.Exception.Message) }
            } else {
                Write-Log -Message ("Error. Folder '{0}' not found." -f $FolderObject.Path)
            }
        } catch {
            Write-Log -Message ("Error binding to folder '{0}: {1}" -f $FolderObject.Path, $_.Exception.Message)
        }
    }
    $iReturn
}

#endregion


#region Main process

Write-Log 'Verifying prerequisites' -HostOnly
Assert-Prerequisites

Write-Log "Initializing connection to mailbox: $Mailbox"
$globals.EWSService = Initialize-Service -Mailbox $Mailbox -Impersonate:$Impersonate

Write-Log -Message 'Getting the mailbox folders to delete from the specified mailbox statistics report'
$foldersToRemove = Import-Csv -Path $Path -Delimiter ',' |
    Select-Object FolderPath, FolderId, @{N = 'Segments'; E = { ($_.FolderPath -split '\/').Count + 1 } } |
        Sort-Object Segments -Descending

if ($foldersToRemove.Count -gt 0) {
    Write-Log -Message ('Total folders to delete: {0}' -f $foldersToRemove.Count)
    $foldersRemoved = 0
    if ($pscmdlet.ShouldProcess($Mailbox, (('Remove {0} folders(s)' -f $foldersToRemove.Count)))) {
        foreach ($f in $foldersToRemove) {
            $folderObject = New-Object -TypeName PSObject -Property @{
                Path = $f.FolderPath
                FolderId = Convert-FormatId -Mailbox $Mailbox -folderId $f.FolderId -Format EWS
            }
            $foldersRemoved += (Remove-MailboxFolder -FolderObject $folderObject)
        }
    }
    Write-Log -Message ('Removed {0}/{1} folders(s)' -f $foldersRemoved, $foldersToRemove.Count)
} else {
    Write-Log -Message ("Couldn't find folders in mailbox: {0}. Please verify the provided credentials have the required permissions" -f $mailbox)
}

#endregion


