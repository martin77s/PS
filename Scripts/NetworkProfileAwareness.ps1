#requires -ver 4.0

param([switch]$Install)

# Define the event subscription query
$subscriptionQuery = @'
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="Microsoft-Windows-NetworkProfile/Operational">
     *[System[(EventID=4004)]]
    </Select>
  </Query>
</QueryList>
'@  

# Define code to run in ether case (Domain connected or not)
$codeToRun = @{
    
    DomainAuthenticated = {
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS' -Name EnableBitsMaxBandwidth -Value 1
    }

    PublicOrPrivate = {
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS' -Name EnableBitsMaxBandwidth -Value 0
    }

}

# Internal variables
$eventLogsource = 'NetworkProfileAwareness'
$taskName = 'NetworkProfileAwareness'

# Internal logic
New-EventLog -LogName Application -Source $eventLogsource -ErrorAction SilentlyContinue

if(-not $Install) {
    $profiles = @((Get-NetConnectionProfile).NetworkCategory)
    if($profiles -contains [Microsoft.PowerShell.Cmdletization.GeneratedTypes.NetConnectionProfile.NetworkCategory]::DomainAuthenticated) {
        Write-EventLog -LogName Application -Source $eventLogsource -EntryType Information -EventId 0 -Message 'DomainAuthenticated profile'
        & $codeToRun.DomainAuthenticated
    } else {
        Write-EventLog -LogName Application -Source $eventLogsource -EntryType Information -EventId 1 -Message 'Public/Private profile'
        & $codeToRun.PublicOrPrivate
    }
} else {
    Add-Type -AssemblyName System.Web
    $taskDefinition = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <RegistrationInfo>
    <Date>{0:yyyy-MM-dd}T{0:HH:mm:ss}</Date>
    <Author>{1}</Author>
    </RegistrationInfo>
    <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>{2}</Subscription>
    </EventTrigger>
    </Triggers>
    <Principals>
    <Principal id="Author">
        <UserId>S-1-5-18</UserId>
        <RunLevel>HighestAvailable</RunLevel>
    </Principal>
    </Principals>
    <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable>
    <IdleSettings>
        <StopOnIdleEnd>false</StopOnIdleEnd>
        <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Priority>7</Priority>
    </Settings>
    <Actions Context="Author">
    <Exec>
        <Command>{3}</Command>
        <Arguments>-ExecutionPolicy bypass -NoProfile -File {4}</Arguments>
    </Exec>
    </Actions>
</Task>
'@ -f (Get-Date), 
        $eventLogsource, 
        ([System.Web.HttpUtility]::HtmlEncode(
             -join (($subscriptionQuery -split "`n" ).Trim())
        )),
        "$PSHOME\powershell.exe",
        $MyInvocation.MyCommand.Source

    $tempXmlFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('{0}.xml' -f $taskName)
    $taskDefinition | Out-File $tempXmlFile -Encoding ascii
    C:\Windows\System32\schtasks.exe /CREATE /TN $taskName /XML $tempXmlFile /F
    Remove-Item -Path $tempXmlFile -Force
}