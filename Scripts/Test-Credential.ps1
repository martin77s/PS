<#
.SYNOPSIS
    Validates the supplied UserName and Password, or the Credential object against the Domain or the local computer

.DESCRIPTION
    This function will return a bolean value (True/False) depending if the credentials supplied (UserName + Password, UserName + SecuredString, or a Credential object)
    were successfully validated against the ActiveDirectory Domain or the local computer.

.EXAMPLE
    PS C:\>Test-Credential -UserName 'CONTOSO\Martin' -Password 'P@55w0rd!'

.EXAMPLE
    PS C:\>Test-Credential -UserName 'Martin@CONTOSO.COM' -Password 'P@55w0rd!'

.EXAMPLE
    PS C:\>Test-Credential -UserName 'Martin' -Password 'P@55w0rd!' -Domain 'CONTOSO'

.EXAMPLE
    PS C:\>Test-Credential -UserName '.\Administrator' -Password 'P@55w0rd!'

.EXAMPLE
    PS C:\>$SecuredPassword = Read-Host 'Please enter the password' -AsSecureString
    PS C:\>Test-Credential -UserName '.\Administrator' -SecuredPassword $SecuredPassword

.EXAMPLE
    PS C:\>$cred = Get-Credential
    PS C:\>Test-Credential -Credential $cred
#>
[CmdletBinding(DefaultParameterSetName = 'UserPassword', SupportsShouldProcess = $true)]
[OutputType([bool])]

Param (
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0, ParameterSetName = 'UserPassword')]
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0, ParameterSetName = 'UserSecuredPassword')]
    [ValidateNotNullOrEmpty()]
    [Alias('User', 'Name', 'UN')]
    [string] $UserName,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 1, ParameterSetName = 'UserPassword')]
    [AllowEmptyString()]
    [Alias('Secret')]
    [string] $Password,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 1, ParameterSetName = 'UserSecuredPassword')]
    [AllowEmptyString()]
    [Alias('SecureString')]
    [System.Security.SecureString] $SecuredPassword,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 2, ParameterSetName = 'UserPassword')]
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, Position = 2, ParameterSetName = 'UserSecuredPassword')]
    [AllowEmptyString()]
    [Alias('DomainName')]
    [string] $Domain = $ENV:USERDOMAIN,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Credential')]
    [System.Management.Automation.PSCredential] $Credential = [System.Management.Automation.PSCredential]::Empty
)

Process {

    switch ($PsCmdlet.ParameterSetName) {

        'Credential' {
            $Domain = ($Credential.UserName -split '\\')[0]
            $UserName = ($Credential.UserName -split '\\')[-1]
            $Password = $Credential.GetNetworkCredential().Password
            break
        }

        { $_ -match 'UserPassword|UserSecuredPassword' } {
            if ($UserName -match '(?<Domain>.*)\\(?<UserName>.*)|(?<UserName>.*)@(?<Domain>.*)') {
                $UserName = $Matches.UserName
                $Domain = $Matches.Domain
            }
        }

        'UserSecuredPassword' {
            $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($SecuredPassword)
            $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
        }
    }


    Add-Type -AssemblyName System.DirectoryServices.AccountManagement

    if (@('', '.', 'localhost', '127.0.0.1') -contains $Domain) {
        $Domain = $ENV:COMPUTERNAME
        $context = [System.DirectoryServices.AccountManagement.ContextType]::Machine
    } else {
        $context = [System.DirectoryServices.AccountManagement.ContextType]::Domain
    }

    if ($pscmdlet.ShouldProcess("$Domain\$UserName", "Test credential")) {

        $principal = New-Object System.DirectoryServices.AccountManagement.PrincipalContext $context, $Domain
        $negotiate = [System.DirectoryServices.AccountManagement.ContextOptions]::Negotiate
        $principal.ValidateCredentials($UserName, $Password, $negotiate)
        $principal.Dispose()
    }
}