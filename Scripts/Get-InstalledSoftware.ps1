[cmdletbinding()]
param(
	[parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
	[string[]]$ComputerName = $env:ComputerName 
) 

begin {
	$UninstallRegKey = 'SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall'
} 

process {

	foreach($Computer in $ComputerName) {

		if(Test-Connection -ComputerName $Computer -Count 1 -ea 0) {

			Write-Verbose "Working on $Computer"
			$operatingSystem = (Get-WmiObject -ComputerName $Computer -Class Win32_OperatingSystem).Caption
			if ((Get-WmiObject -Class Win32_OperatingSystem -ComputerName $Computer -ErrorAction SilentlyContinue).OSArchitecture -eq '64-bit') {
				$RegistryViews = @('Registry32','Registry64')
			} else {
				$RegistryViews = @('Registry32')
			}

			foreach($RegistryView in $RegistryViews) {
				$HKLM = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Computer, $RegistryView)
				$UninstallRef = $HKLM.OpenSubKey($UninstallRegKey)
				$Applications = $UninstallRef.GetSubKeyNames()

				foreach ($App in $Applications) {
					$AppRegistryKey = $UninstallRegKey + "\\" + $App
					$AppDetails = $HKLM.OpenSubKey($AppRegistryKey)
					$AppGUID = $App
					$AppDisplayName = $($AppDetails.GetValue("DisplayName"))
					$AppVersion = $($AppDetails.GetValue("DisplayVersion"))
					$AppPublisher = $($AppDetails.GetValue("Publisher"))
					$AppInstalledDate = $($AppDetails.GetValue("InstallDate"))
					$AppUninstall = $($AppDetails.GetValue("UninstallString"))

					if($AppDisplayName) {
						New-Object PSObject -Property @{
							ComputerName = $Computer.ToUpper()
							AppName = $AppDisplayName
							AppVersion = $AppVersion
							AppVendor = $AppPublisher
							InstalledDate = if($AppInstalledDate) {
								if($AppInstalledDate -notmatch '\d*/\d*/\d*') { 
									[datetime]::ParseExact($AppInstalledDate, 'yyyyMMdd', $null) 
								} else {
									Get-Date -Date $AppInstalledDate
								}
							};
							UninstallKey = $AppUninstall
							AppGUID = $AppGUID
						}
					}
				}
			}

		} else {
			Write-Warning "$Computer is unavailable"
		}
	}
}
end {}


# Example:
# Get-InstalledSoftware.ps1 | Where { $_.InstalledDate } | Select-Object -First 4
