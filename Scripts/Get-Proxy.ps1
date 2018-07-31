
$regKeyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'

$proxyValues = [ordered]@{'Enabled' = [bool](Get-ItemProperty $regKeyPath -Name ProxyEnable -ErrorAction SilentlyContinue).ProxyEnable}
$proxyValues.Add('AutoConfigURL', (Get-ItemProperty $regKeyPath -Name AutoConfigURL -ErrorAction SilentlyContinue).AutoConfigURL)
$proxyValues.Add('BypassAdresses', (Get-ItemProperty $regKeyPath -Name ProxyOverride -ErrorAction SilentlyContinue).ProxyOverride)
$proxyValues.Add('BypassLocalEnabled', $proxyValues['BypassAdresses'] -match '<local>')

$ProxyServer = (Get-ItemProperty $regKeyPath -Name ProxyServer -ErrorAction SilentlyContinue).ProxyServer
if($ProxyServer -match '=') {
    $ProxyServer -split ';' | ForEach-Object {
        if($_ -match '((?<protocol>\w+)=(?<address>.*):(?<port>\d+))') {
            $proxyValues.Add(('{0}Address' -f $Matches.protocol), $Matches.address)
            $proxyValues.Add(('{0}Port' -f $Matches.protocol), $Matches.port)
        }
    }
}
else {
    'http', 'https' , 'ftp' , 'socks' | ForEach-Object {
        $proxyValues.Add(('{0}Address' -f $_), ($ProxyServer -split ':')[0])
        $proxyValues.Add(('{0}Port' -f $_), ($ProxyServer -split ':')[1])
    }
}

New-Object -TypeName PSObject -Property $proxyValues