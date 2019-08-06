param($NetworkName = $null)

if($NetworkName) {
    [pscustomobject]@{
        NetworkName = $NetworkName
        Password = (netsh.exe wlan show profile "$NetworkName" key=clear) | % {
            if($_ -match 'Key Content\s+: (?<Password>.*)') { $Matches.Password } }
    }

} else {
    (netsh.exe wlan show profiles) | % { 
        if($_ -match 'All User Profile\s+: (?<NetworkName>.*)|Current User Profile\s+: (?<NetworkName>.*)') { 
            $Matches.NetworkName }} | % { Get-WifiPassword -NetworkName "$_" }
}
