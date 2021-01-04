param(
	$ComputersFile = 'C:\Temp\computers.txt',
	$DNSServers = '192.168.68.240', '1.1.1.1'
)


$doneList = $ComputersFile -replace '\.txt', '-done.txt'
$errorList = $ComputersFile -replace '\.txt', '-errors.txt'

if(Test-Path -Path $ComputersFile -PathType Leaf) {
    $computers = Get-Content -Path $ComputersFile
    foreach ($computerName in $computers) {
        try {
            $primaryNic = @(Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled='true'" -ComputerName $computerName -ErrorAction Stop | 
                Where-Object { $_.DefaultIPGateway })[0]
            if($primaryNic.DHCPEnabled) {
                '{0} has DHCP enabled. Refreshing lease..' -f $computerName
                $primaryNic.InvokeMethod('RenewDHCPLease', $null)
            } else {
                '{0} is using static IP configuration. Updating DNS servers..' -f $computerName
                $primaryNic.SetDNSServerSearchOrder($DNSServers)
            }
            Add-Content -Path $doneList -Value $computerName
        } catch {
            '{0} - Error: {1}' -f $computerName, $_.Exception.Message
            Add-Content -Path $errorList -Value ($computerName + ': ' + $_.Exception.Message)
        }
    }
} else {
    Write-Error -Message 'Computers file does not exist in the specified path'
}