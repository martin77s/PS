#region ### BUILD THE CONFIGURATION ###
 
# Declare the configuration:
Configuration TestDscWithoutWinRm {
    Import-DscResource –ModuleName PSDesiredStateConfiguration
    node localhost {
        File akada {
            Ensure          = 'Present'
            Type            = 'File'
            Contents        = 'Martin was here!'
            DestinationPath = 'C:\Temp\test.log'
        }
    }
}
 
# Run the configuration to create the MOF file:
TestDscWithoutWinRm
 
#endregion
 
 
#region ### APPLY THE CONFIGURATION FOR THE FIRST TIME ###
 
# This will NOT work without the WinRM service running:
Start-DscConfiguration -Wait -Verbose -Path .\TestDscWithoutWinRm
 
# This is one a workaround for the first apply:
Copy-Item -Path .\TestDscWithoutWinRm\localhost.mof C:\Windows\System32\Configuration\pending.mof -Force
Invoke-CimMethod -Namespace root/Microsoft/Windows/DesiredStateConfiguration -ClassName MSFT_DSCLocalConfigurationManager -Method PerformRequiredConfigurationChecks -Arguments @{Flags = [System.UInt32]1}
 
# This is another workaround for the first apply:
$configData = [byte[]][System.IO.File]::ReadAllBytes((Resolve-Path -Path '.\TestDscWithoutWinRm\localhost.mof'))
Invoke-CimMethod -Namespace root/Microsoft/Windows/DesiredStateConfiguration -ClassName MSFT_DSCLocalConfigurationManager -Method SendConfigurationApply -Arguments @{ConfigurationData = $configData; force = $true}
 
#endregion
 
 
#region ### RE-APPLY THE CURRENT CONFIGURATION ###
 
# This is the workaround for re-applying the current configuration:
Copy-Item -Path C:\Windows\System32\Configuration\current.mof C:\Windows\System32\Configuration\pending.mof -Force
Invoke-CimMethod -Namespace root/Microsoft/Windows/DesiredStateConfiguration -ClassName MSFT_DSCLocalConfigurationManager -Method ApplyConfiguration -Arguments @{force = [bool]$true}
 
#endregion
 
 
#region ### TEST THE CONFIGURATION ###
 
# This doesn't work without the WinRM service:
Test-DscConfiguration
 
# This is a workaround:
Invoke-CimMethod -Namespace root/Microsoft/Windows/DesiredStateConfiguration -ClassName MSFT_DSCLocalConfigurationManager -Method TestConfiguration
 
#endregion