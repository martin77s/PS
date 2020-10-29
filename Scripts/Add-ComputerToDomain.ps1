[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $DomainName,
    [Parameter(Mandatory = $true)] [string] $DomainUser,
    [Parameter(Mandatory = $true)] [string] $DomainPassword
)

$creds = New-Object System.Management.Automation.PSCredential -ArgumentList ("$DomainName\$DomainUser",
    $DomainPassword | ConvertTo-SecureString -AsPlainText -Force
)
Add-Computer -DomainName $DomainName -Credential $creds -Restart -Force