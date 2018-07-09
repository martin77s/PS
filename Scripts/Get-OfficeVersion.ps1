function Get-OfficeVersion {

    param([string[]]$ComputerName = $env:ComputerName)

    $UninstallRegKey = 'SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall'
    $selectedProperties = @('ComputerName', 'DisplayName', 'Version')

    foreach($Computer in $ComputerName) {

        if(Test-Connection -ComputerName $Computer -Count 1 -ErrorAction SilentlyContinue) {

            $OS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $Computer -ErrorAction SilentlyContinue
            if(-not $OS) {
                Write-Warning "$Computer is unreachable"
            }
            else {
                if ($OS.OSArchitecture -eq '64-bit') {
                    $RegistryViews = @('Registry32', 'Registry64')
                }
                else {
                    $RegistryViews = @('Registry32')
                }

                foreach($RegistryView in $RegistryViews) {
                    $HKLM = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Computer, $RegistryView)
                    $UninstallRef = $HKLM.OpenSubKey($UninstallRegKey)
                    $Applications = $UninstallRef.GetSubKeyNames()

                    foreach ($App in $Applications) {

                        $AppRegistryKey = '{0}\\{1}' -f $UninstallRegKey, $App
                        $AppDetails = $HKLM.OpenSubKey($AppRegistryKey)
                        $AppDisplayName = $($AppDetails.GetValue('DisplayName'))

                        if($AppDisplayName -match '^Microsoft Office') {

                            $AppInstalledDate = $($AppDetails.GetValue('InstallDate'))
                            New-Object PSObject -Property @{
                                ComputerName  = $Computer.ToUpper()
                                DisplayName   = $AppDisplayName
                                Version       = $($AppDetails.GetValue('DisplayVersion'))
                                Vendor        = $($AppDetails.GetValue('Publisher'))
                                InstalledDate = $(
                                    if($AppInstalledDate) {
                                        if($AppInstalledDate -notmatch '\d+/\d+/\d+') {
                                            [datetime]::ParseExact($AppInstalledDate, 'yyyyMMdd', $null)
                                        }
                                        else {
                                            Get-Date -Date $AppInstalledDate
                                        }
                                    })
                                UninstallKey  = $($AppDetails.GetValue('UninstallString'))
                                GUID          = $App
                            } | Select-Object -Property $selectedProperties
                        }
                    }
                }
            }
        }
        else {
            Write-Warning "$Computer is unavailable"
        }
    }
}


Get-OfficeVersion