<#
 ==========[DISCLAIMER]===========================================================================================================
  This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
  THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
  INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
  We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object
  code form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to market Your software
  product in which the Sample Code is embedded; (ii) to include a valid copyright notice on Your software product in which the
  Sample Code is embedded; and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or
  lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
 =================================================================================================================================

Script Name	: InstallAndConfigureIIS.ps1
Description	: This scripts installs the base recommended role services for the IIS Webserver role,
                  and configures the most common IIS settings according to the best practices
Author		: Martin Schvartzman, Microsoft (maschvar@microsoft.com)
Keywords	: IIS, BestPractices
Last Update	: 2018/05/06

#>

#region Configurable variables:

$WebsiteLogsFolder = 'C:\inetpub\logs\LogFiles'
$WinSxSFolder = 'D:\sources\sxs'

$DisableIPv6 = $false

#endregion


#region Install IIS:

$ComponentsToInstall = @(
    'NET-Framework-Features',
    'NET-Framework-45-Features',
    'Web-Default-Doc',
    'Web-Http-Errors',
    'Web-Static-Content',
    'Web-Http-Redirect',
    'Web-Http-Logging',
    'Web-Log-Libraries',
    'Web-Request-Monitor',
    'Web-Http-Tracing',
    'Web-Stat-Compression',
    'Web-Dyn-Compression',
    'Web-Filtering',
    'Web-CertProvider',
    'Web-IP-Security',
    'Web-Url-Auth',
    'Web-Windows-Auth',
    'Web-Net-Ext',
    'Web-Net-Ext45',
    'Web-AppInit',
    'Web-Asp-Net',
    'Web-Asp-Net45',
    'Web-ISAPI-Ext',
    'Web-ISAPI-Filter',
    'Web-Mgmt-Console',
    'Web-Scripting-Tools',
    'Web-Mgmt-Service'
)

if(-not (Test-Path -Path $WinSxSFolder)) {
    Write-Warning -Message 'WinSxS folder not found. Skipping NETFX 3.5 components'
    $ComponentsToInstall = $ComponentsToInstall | Where-Object { $_ -notmatch 'NET-Framework-Features|Web-Net-Ext|Web-Asp-Net' }
	Add-WindowsFeature -Name $ComponentsToInstall -IncludeManagementTools
} else {
	Add-WindowsFeature -Name $ComponentsToInstall -IncludeManagementTools -Source $WinSxSFolder
}
#endregion


#region Configure IIS and ASP.NET:


# ApplicationPools settings:
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/applicationPools/applicationPoolDefaults -Name queueLength -Value 5000
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/applicationPools/applicationPoolDefaults/processModel -Name idleTimeout -Value '00:00:00'
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/applicationPools/applicationPoolDefaults/recycling -Name logEventOnRecycle -Value 'Time,Requests,Schedule,Memory,IsapiUnhealthy,OnDemand,ConfigChange,PrivateMemory'
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/applicationPools/applicationPoolDefaults/recycling/periodicRestart -Name time -Value '00:00:00'
Add-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/applicationPools/applicationPoolDefaults/recycling/periodicRestart/schedule -Name . -Value @{value='04:00:00'}


# Website Logging settings:
New-Item -Path $WebsiteLogsFolder -ItemType Directory -Force | Out-Null
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/sites/siteDefaults/logFile -Name logExtFileFlags -Value 'Date,Time,ClientIP,UserName,SiteName,ComputerName,ServerIP,Method,UriStem,UriQuery,HttpStatus,Win32Status,BytesSent,BytesRecv,TimeTaken,ServerPort,Cookie,Host,HttpSubStatus'
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/sites/siteDefaults/logFile -Name directory -Value $WebsiteLogsFolder


# Windows Authentication settings:
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.webServer/security/authentication/windowsAuthentication -Name authPersistNonNTLM -Value $true
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.webServer/security/authentication/windowsAuthentication -Name useKernelMode -Value $true
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.webServer/security/authentication/windowsAuthentication -Name useAppPoolCredentials -Value $true


# HttpCompression settings:
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.webServer/httpCompression -Name minFileSizeForComp -Value 512
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.webServer/httpCompression -Name staticCompressionEnableCpuUsage -Value 65
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.webServer/httpCompression -Name dynamicCompressionEnableCpuUsage -Value 65
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter "system.webServer/httpCompression/scheme[@name='gzip']" -Name staticCompressionLevel -Value 9
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter "system.webServer/httpCompression/scheme[@name='gzip']" -Name dynamicCompressionLevel -Value 4
Add-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter "system.webServer/httpCompression/dynamicTypes" -Name "." -Value @{mimeType='application/json';enabled='True'}
Add-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter "system.webServer/httpCompression/dynamicTypes" -Name "." -Value @{mimeType='application/json; charset=utf-8';enabled='True'}


# Configuration History:
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/configHistory -Name maxHistories -Value 20
Set-WebConfigurationProperty -PSPath MACHINE/WEBROOT/APPHOST -Filter system.applicationHost/configHistory -Name period -Value '00:01:00'


# ASP.NET Concurrency:
Add-WebConfigurationProperty -PSPath MACHINE/WEBROOT -Filter system.net/connectionManagement -Name . -value @{address='*';maxconnection=50000} -Clr 2.0
Add-WebConfigurationProperty -PSPath MACHINE/WEBROOT -Filter system.net/connectionManagement -Name . -value @{address='*';maxconnection=50000} -Clr 4.0
New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\ASP.NET\2.0.50727.0 -Name MaxConcurrentRequestsPerCPU -Value 50000 -Force | Out-Null

#endregion


#region Configure OS settings


# Enable IIS operational auditing
$log = Get-WinEvent -ListLog Microsoft-IIS-Configuration/Operational
$log.IsEnabled = $true
$log.SaveChanges()


# Correctly disable IPv6:
if($DisableIPv6) {
	New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters -Name DisabledComponents -Value 0xff -Force | Out-Null
}


# Disable the File System Object component
C:\Windows\System32\regsvr32.exe scrrun.dll /u /s


# Processor Scheduling:
New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl -Name Win32PrioritySeparation -Value 24 -Force | Out-Null


# Disable SSL2 & SSL3 & TLS 1.0 + Enable TLS 1.1 & TLS 1.2:
$SslRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'

New-Item -Path "$SslRegPath\SSL 2.0\Server" -Force | Out-Null
New-ItemProperty -Path "$SslRegPath\SSL 2.0\Server" -Name Enabled -Value 0 –PropertyType DWORD | Out-Null

New-Item -Path "$SslRegPath\SSL 3.0\Server" -Force | Out-Null
New-ItemProperty -Path "$SslRegPath\SSL 3.0\Server" -Name Enabled -Value 0 –PropertyType DWORD | Out-Null

New-Item -Path "$SslRegPath\TLS 1.0\Server" -Force | Out-Null
New-Item -Path "$SslRegPath\TLS 1.0\Client" -Force | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.0\Server" -Name Enabled -Value 0 –PropertyType DWORD | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.0\Server" -Name DisabledByDefault -Value 1 –PropertyType DWORD | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.0\Client" -Name Enabled -Value 0 –PropertyType DWORD | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.0\Client" -Name DisabledByDefault -Value 1 –PropertyType DWORD | Out-Null

New-Item -Path "$SslRegPath\TLS 1.1\Server" -Force | Out-Null
New-Item -Path "$SslRegPath\TLS 1.1\Client" -Force | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.1\Server" -Name Enabled -Value 1 –PropertyType DWORD | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.1\Server" -Name DisabledByDefault -Value 0 –PropertyType DWORD | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.1\Client" -Name Enabled -Value 1 –PropertyType DWORD | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.1\Client" -Name DisabledByDefault -Value 0 –PropertyType DWORD | Out-Null

New-Item -Path "$SslRegPath\TLS 1.2\Server" -Force | Out-Null
New-Item -Path "$SslRegPath\TLS 1.2\Client" -Force | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.2\Server" -Name Enabled -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.2\Server" -Name DisabledByDefault -Value 0 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.2\Client" -Name Enabled -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path "$SslRegPath\TLS 1.2\Client" -Name DisabledByDefault -Value 0 -PropertyType DWORD -Force | Out-Null


#endregion










