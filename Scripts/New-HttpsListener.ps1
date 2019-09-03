$wmiParams = @{
    
    ApplicationName = 'WinRM/Config/Listener'
    
    SelectorSet     = @{Address = '*'; Transport='HTTPS'}
    
    ValueSet        = @{

        Hostname =  [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties() | 
            ForEach-Object { '{0}.{1}' -f $_.Hostname,$_.DomainName }

        CertificateThumbprint = Get-ChildItem -Path 'Cert:\LocalMachine\My' | 
            Where-Object { $_.Subject -like "CN=$env:COMPUTERNAME*" } |
                Select-Object -ExpandProperty ThumbPrint
    }
}

New-WSManInstance @wmiParams