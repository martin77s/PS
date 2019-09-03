#Requires -Version 4
<#
    Name        : ArchiveCalendar.ps1
    Version     : 0.0.0.2
    Last Update : 2018/12/30
    Created by  : Martin Schvartzman, Microsoft
    References  :
    https://msdn.microsoft.com/en-us/library/office/dd633696(v=exchg.80).aspx
    https://blogs.msdn.microsoft.com/brijs/2010/09/09/how-to-convert-exchange-items-entryid-to-ews-unique-itemid-via-ews-managed-api-convertid-call/
    https://msdn.microsoft.com/en-us/library/microsoft.exchange.webservices.data.extendedpropertydefinition_members(v=exchg.80).aspx
#>

[cmdletbinding(DefaultParameterSetName='CredsFile')]
param(
    [Parameter(Position=0, Mandatory=$true)]
    [string[]] $Mailbox,

    [Parameter(Position=1)]
    [int] $ItemAgeInDays = 365,

    [Parameter(Position=2)]
    [switch] $Impersonate,

    [Parameter(Position=3, ParameterSetName='CredsObject')]
    [PSCredential] $Credential,

    [Parameter(Position=3, ParameterSetName='CredsFile')]
    [string] $CredentialFile = '.\creds.xml',

    [Parameter(Position=4, ParameterSetName='CredsFile')]
    [switch] $Create
)


#region Settings

$settings = New-Object -TypeName PSObject -Property @{

    # Exchange Web Services API Version (2010 = 1.1 | 2016 = 2.2)
    EWSVersion         = 2.2

    # Exchange CAS array or server FQDN to the exchange web service:
    EWSUrl             = 'https://outlook.office365.com/EWS/Exchange.asmx'

    # The starting point for archive (in months)
    MonthsBackToScan   = 12*10

    # Send the report to the user or not
    EmailReportToUser  = $true

    # Email subject mask
    EmailReportSubject = 'Archive calendar report for {0}'

    # Email body mask
    EmailReportBody    = 'Archived {0} item(s).<br/>For more information, please see attached logs'

    # SMTP server with port
    EmailSmtpServer    = 'smtp.office365.com:587'

    # EWS timeout in milliseconds
    EWSTimeout         = 180000

    # Item page size (max 1000)
    ItemPageSize       = 1000

    # EWS tracing enabled (affects performace)
    EWSTraceEnabled    = $false

    # Verbose messages in console
    VerboseProcess     = $true
}

#endregion


#region Helper functions

function Get-ScriptPath {
    if($PsScriptRoot) {
        $PsScriptRoot
    } else {
        $invocation = (Get-Variable MyInvocation -Scope 1)
        if($invocation.Value.MyCommand.Path) {
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
    if(-not $HostOnly) {
        Add-Content -Value $Message -Path $globals.CurrentLogProcess -Encoding UTF8
    }
}


function Assert-Prerequisites {

    $regVal = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Exchange\Web Services\$($settings.EWSVersion)"
    if (-not ($regVal)) {
        throw ('Microsoft Exchange Web Services Managed API is not installed. Please download and install from https://www.microsoft.com/en-us/download/details.aspx?id=42951')
    }
    else {
        $globals.EWSModulePath = Join-Path -Path $regVal.'Install Directory' -ChildPath 'Microsoft.Exchange.WebServices.dll'
    }

    $logsFolder = Join-Path -Path (Get-ScriptPath) -ChildPath Logs
    if (-not (Test-Path -Path $logsFolder -PathType Container)) {
        [void](New-Item -Path $logsFolder -ItemType Directory -Force -ErrorAction Stop)
    }

    if ($settings.ItemPageSize -gt 1000) {
        $settings.ItemPageSize = 1000
    }


    switch($PSCmdlet.ParameterSetName) {

        'CredsObject' {
            $globals.Creds = $Credential
        }

        'CredsFile' {
            if($Create) {
                $globals.Creds = Get-Credential -Message 'Please enter the credentials with impersonation permissions'
                if ($globals.Creds) {
                    $globals.Creds | Export-Clixml -Path (Join-Path -Path (Get-ScriptPath) -ChildPath 'creds.xml')
                }
            } else {
               $globals.Creds = Import-Clixml -Path $CredentialFile
            }
        }
    }
    if (-not ($globals.Creds)) { throw 'Credentials not provided' }
}


function Initialize-Service {
    param(
        [string] $CurrentMailbox
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

    try { $Service.AutodiscoverUrl($CurrentMailbox, $validateRedirectionUrlCallback) } catch {}
    $Service.HttpHeaders.Add('X-AnchorMailbox', $CurrentMailbox)
    if($Impersonate) {
        $Service.ImpersonatedUserId = New-Object -TypeName Microsoft.Exchange.WebServices.Data.ImpersonatedUserId `
            -ArgumentList ([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress), $CurrentMailbox
    }
    return $Service
}


function Send-MailReport {
    param($UserEmail)

    $attachments = dir -Path @($globals.CurrentLogProcess, $globals.CurrentLogItems) -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
    $smtpServer, $smtpPort = $settings.EmailSmtpServer -split ':'

    $emailParams = @{
        To          = $UserEmail
        From        = $globals.Creds.UserName
        Subject     = ($settings.EmailReportSubject -f $globals.CurrentMailbox)
        Body        = ($settings.EmailReportBody -f $globals.CurrentItemsMoved)
        Attachments = $attachments
        Priority    = 'Low'
        BodyAsHtml  = $true
        SmtpServer  = $smtpServer
        Port        = $smtpPort
        Credential  = $globals.Creds
        UseSsl      = $true
    }
    Send-MailMessage @emailParams

}


function Get-TargetFolders {
    $targetFolders = @{}
    $folderView = New-Object -TypeName Microsoft.Exchange.WebServices.Data.FolderView -ArgumentList 1000
    ($globals.EWSService).FindFolders([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Calendar, $folderView) |
        Where-Object { $_.DisplayName -match '^\d{4}$' } | ForEach-Object {
            $targetFolders.Add($_.DisplayName, $_.Id)
    }
    $targetFolders
}


function New-TargetFolder {
    param([string]$Year)
    $calFolder = New-Object -TypeName Microsoft.Exchange.WebServices.Data.CalendarFolder -ArgumentList $globals.EWSService
    $calFolder.DisplayName = $Year
    $calFolder.Save([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Calendar)
}


#endregion


#region Variables

$globals = New-Object -TypeName PSObject -Property @{
    Creds                 = $null
    EWSModulePath         = $null
    EWSModule             = $null
    EWSService            = $null
    CurrentMailbox        = $null
    CurrentCalendar       = $null
    CurrentLogItems       = $null
    CurrentLogProcess     = $null
    CurrentTargetFolders  = $null
    CurrentItemsMoved     = 0
    TotalItemsMoved       = 0
}

#endregion


#region Initializations

Write-Log 'Verifying Prerequisites' -HostOnly
Assert-Prerequisites

Write-Log 'Loading the Microsoft Exchange Web Services Managed API module' -HostOnly
$globals.EWSModule = Import-Module -Name $globals.EWSModulePath -DisableNameChecking -PassThru

#endregion


#region Main process

$MaximumArchiveDate = (Get-Date).AddDays(-1*$ItemAgeInDays)

foreach ($mbx in $Mailbox) {

    $globals.CurrentMailbox = ($mbx -split '@')[0]
    $globals.CurrentItemsMoved = 0

    $globals.CurrentLogItems   = Join-Path -Path (Get-ScriptPath) -ChildPath ('Logs\{0:yyyMMddHHmmss}_{1}.csv' -f (Get-Date), $globals.CurrentMailbox)
    $globals.CurrentLogProcess = Join-Path -Path (Get-ScriptPath) -ChildPath ('Logs\{0:yyyMMddHHmmss}_{1}.log' -f (Get-Date), $globals.CurrentMailbox)


    Write-Log "Initializing connection to mailbox: $mbx"
    $globals.EWSService = Initialize-Service -CurrentMailbox $mbx


    Write-Log -Message 'Connecting to the calendar folder'
    $globals.CurrentCalendar = [Microsoft.Exchange.WebServices.Data.Folder]::Bind(
        $globals.EWSService, [Microsoft.Exchange.WebServices.Data.WellknownFolderName]::Calendar)


    Write-Log -Message 'Getting target archive folders'
    $globals.CurrentTargetFolders = Get-TargetFolders


    $startArchiveDate = $MaximumArchiveDate.AddMonths(-1*$settings.MonthsBackToScan)
    $endArchiveDate = $startArchiveDate.AddYears(1)
    $breakLoop = 0

    Write-Log -Message ('Initializing folder view with date range ({0:dd/MM/yyyy} to {1:dd/MM/yyyy})' -f $startArchiveDate, $MaximumArchiveDate)

    while($endArchiveDate -le $MaximumArchiveDate -and $breakLoop -le 1) {

        Write-Log -Message ('Getting appointments from date range ({0:dd/MM/yyyy} to {1:dd/MM/yyyy})' -f $startArchiveDate, $endArchiveDate)

        $calView = New-Object -TypeName Microsoft.Exchange.WebServices.Data.CalendarView -ArgumentList $startArchiveDate, $endArchiveDate, $settings.ItemPageSize
        $calView.Traversal = [Microsoft.Exchange.WebServices.Data.FolderTraversal]::Shallow
        $calView.PropertySet = New-Object -TypeName Microsoft.Exchange.WebServices.Data.PropertySet -ArgumentList (
            [Microsoft.Exchange.WebServices.Data.AppointmentSchema]::Subject,
            [Microsoft.Exchange.WebServices.Data.AppointmentSchema]::Id,
            [Microsoft.Exchange.WebServices.Data.AppointmentSchema]::End,
            [Microsoft.Exchange.WebServices.Data.AppointmentSchema]::AppointmentType
        )

        do {
            $appointments = ($globals.EWSService).FindAppointments([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Calendar, $calView)

            if($appointments.TotalCount -gt 0) {

                foreach($appt in $appointments.Items) {

                    if([Microsoft.Exchange.WebServices.Data.AppointmentType]::Occurrence, [Microsoft.Exchange.WebServices.Data.AppointmentType]::Exception -notcontains $appt.AppointmentType) {

                        try {

                            if(-not $globals.CurrentTargetFolders.ContainsKey([string]$appt.End.Year)) {
                                New-TargetFolder -Year $appt.End.Year
                                $globals.CurrentTargetFolders = Get-TargetFolders
                            }

                            $appt.Move($globals.CurrentTargetFolders[[string]$appt.End.Year]) | Out-Null
                            $globals.CurrentItemsMoved++

                            New-Object PSObject -Property @{
                                Subject = $appt.Subject
                                Year    = $appt.End.Year
                            } | Export-Csv -NoTypeInformation -Path $globals.CurrentLogItems -Append -Encoding UTF8

                        } catch {
                            Write-Log -Message ('Error moving item [{0}] to [{1}]: {2}' -f $appt.Subject, $appt.End.Year, $_.Exception.Message)
                        }
                    }
                }
                $calView.StartDate = $appointments.Items[-1].End
            }
        } while ($appointments.MoreAvailable)

        $startArchiveDate = $endArchiveDate
        $endArchiveDate = $startArchiveDate.AddYears(1)
        if($endArchiveDate -ge $MaximumArchiveDate) { $breakLoop++; $endArchiveDate = $MaximumArchiveDate }
    }

    Write-Log -Message ('Moved {0} item(s)' -f $globals.CurrentItemsMoved)

    if($settings.EmailReportToUser) {
        Send-MailReport -UserEmail $mbx
    }

    $globals.TotalItemsMoved += $globals.CurrentItemsMoved
}

#endregion


#region Cleanup

Write-Log -Message 'Unloading the Microsoft Exchange Web Services Managed API module' -HostOnly
Remove-Module -Name $globals.EWSModule

Write-Log -Message ('Moved a total of {0} items(s)' -f $globals.TotalItemsMoved) -HostOnly

#endregion

