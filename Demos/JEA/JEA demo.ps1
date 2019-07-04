#region Variables
$OperatorUserName = 'DnsOperator'
$OperatorPassword = 'P@55w0rd!' 
$DnsOperatorsGroupName = 'JEA_DNSOperators'
$ModuleName = 'JEA_DNSOperator'
$SessionName = 'JEA_DNS'
$RoleCapabilityName = 'DNSRoleCapability'
#endregion


#region Create the DnsOperator user and the group that will have access to the JEA endpoint
$userParams = @{
	Name = $OperatorUserName 
	SamAccountName = $OperatorUserName 
	AccountPassword = (ConvertTo-SecureString $OperatorPassword -AsPlainText -Force) 
	Description = $OperatorUserName
}
$OperatorUser = New-ADUser @userParams -PassThru
Enable-ADAccount -Identity $OperatorUser
$jeaDnsOperatorGroup = New-ADGroup -Name $DnsOperatorsGroupName -GroupScope DomainLocal -PassThru
Add-ADGroupMember -Identity $jeaDnsOperatorGroup -Members $OperatorUser
#endregion


#region Create the Module for the Role Capability file
New-Item -Path "$ENV:ProgramFiles\WindowsPowerShell\Modules\$ModuleName" -ItemType Directory
New-Item -Path "$ENV:ProgramFiles\WindowsPowerShell\Modules\$ModuleName\RoleCapabilities" -ItemType Directory
New-Item -Path "$ENV:ProgramFiles\WindowsPowerShell\Modules\$ModuleName\JEAConfigurations" -ItemType Directory
New-ModuleManifest -Path "$ENV:ProgramFiles\WindowsPowerShell\Modules\$ModuleName\$ModuleName.psd1"
#endregion


#region Create the Role Capability file (.psrc)
$params = @{
	Author = 'Martin Schvartzman'
	Description = 'DNS Operator Role Capability File'
	CompanyName = 'CONTOSO'
	Path = "$ENV:ProgramFiles\WindowsPowerShell\Modules\$ModuleName\RoleCapabilities\$RoleCapabilityName.psrc"
	VisibleFunctions = 'TabExpansion2', 'Get-WhoAmI'
	FunctionDefinitions = @{
		'Name' = 'Get-WhoAmI'
		'ScriptBlock' = { New-Object PSObject -Property @{
			ConnectedUser = $PsSenderInfo.ConnectedUser 
			RunningAs = whoami.exe
			}
		}
	}
	VisibleCmdlets = @(
		@{Name = 'Restart-Service'; Parameters = @{ Name = 'Name'; ValidateSet = 'DNS'} },
		@{Name = 'Start-Service'; Parameters = @{ Name = 'Name'; ValidateSet = 'DNS'} },
		@{Name = 'Stop-Service'; Parameters = @{ Name = 'Name'; ValidateSet = 'DNS'} },
		'Get-Service', 'Clear-DnsServerCache', 'Clear-DnsServerStatistics', 'Get-DnsServer', 'Get-DnsServerCache', 'Get-DnsServerDiagnostics'
	)
}
New-PSRoleCapabilityFile @params
#endregion


#region Create the PSSession configuration (using a .pssc file)
$UserRole = "$ENV:USERDOMAIN\$OperatorUserName"
$ConfParams = @{
	SessionType = 'RestrictedRemoteServer'
	RunAsVirtualAccount = $true
	RoleDefinitions = @{ $UserRole = @{ RoleCapabilities = $RoleCapabilityName} }
	TranscriptDirectory = "$ENV:ProgramData\JEA\Transcripts"
	Path = "$ENV:ProgramFiles\WindowsPowerShell\Modules\$ModuleName\JEAConfigurations\JEADNS.pssc"
}
New-PSSessionConfigurationFile @ConfParams
Register-PSSessionConfiguration -Name $SessionName -Path "$ENV:ProgramFiles\WindowsPowerShell\Modules\$ModuleName\JEAConfigurations\JEADNS.pssc"
#endregion


#region Test the JEA endpoint from the client
<#
$cred = Get-Credential CONTOSO\DnsOperator
Enter-PSSession -ComputerName DC1 -ConfigurationName JEA_DNS # This will fail
Enter-PSSession -ComputerName DC1 -ConfigurationName JEA_DNS -Credential $cred
Get-Command
Get-WhoAmI
Restart-Service -Name BITS
Restart-Service -Name DNS
#>
#endregion


#region View logs and transcripts
$filter = @'
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-WinRM/Operational">
    <Select Path="Microsoft-Windows-WinRM/Operational">*[System[(EventID=193)]]</Select>
  </Query>
</QueryList>
'@
Get-WinEvent -FilterXml $filter -MaxEvents 1 | Out-GridView
([xml](Get-WinEvent -FilterXml $filter -MaxEvents 1).ToXml()).Event.EventData.Data #.'#text'

# Explore the transcripts
dir "$ENV:ProgramData\JEA\Transcripts" | Sort-Object LastWriteTime

# View last log, search for "CommandInvocation"
psedit (dir "$ENV:ProgramData\JEA\Transcripts" | Sort-Object LastWriteTime | Select-Object -Last 1).FullName
#endregion