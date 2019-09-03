function Get-LogonReport {
    param($ComputerName = $Env:COMPUTERNAME)

    $filterXml = '<QueryList><Query Id="0" Path="Security"><Select Path="Security">*[System[(EventID=4624)]]</Select></Query></QueryList>'
    $logonTypes = @{
        2 = 'Interactive'
        3 = 'Network'
        4 = 'Batch'
        5 = 'Service'
        6 = 'Proxy'
        7 = 'Unlock'
        8 = 'NetworkCleartext'
        9 = 'NewCredentials'
        10 = 'RemoteInteractive'
        11 = 'CachedInteractive'
        12 = 'CachedRemoteInteractive'
        13 = 'CachedUnlock'
    }
    $ComputerName | ForEach-Object {
        $Computer = $_; Get-WinEvent -FilterXml $filterXml -ComputerName $Computer
    } | Select-Object @{N='ComputerName';E={$Computer}},
    @{N='Identity';E={'{0}\{1}' -f $_.Properties[6].Value, $_.Properties[5].Value}},
    @{N='SID';E={$_.Properties[4].Value}},
    @{N='LogonType';E={'{0}' -f ($logonTypes[[int]($_.Properties[8].Value)])}},
    @{N='AuthenticationType';E={$_.Properties[10].Value}}
}