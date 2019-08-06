function Get-WmiObjectEx {
    param(
        [string] $ComputerName,
        [string] $Namespace = 'root\cimv2',
        [string] $Class,
        [string] $Filter,
        [int] $Timeout = 15
        ) 

    $ConnectionOptions = New-Object System.Management.ConnectionOptions 
    $EnumerationOptions = New-Object System.Management.EnumerationOptions
    $ConnectionOptions.Authentication = 'PacketPrivacy'

    $TimeoutSeconds = New-TimeSpan -Seconds $Timeout 
    $EnumerationOptions.set_timeout($TimeoutSeconds)

    $AssembledPath = '\\' + $ComputerName + '\' + $Namespace 
 
    $Scope = New-Object System.Management.ManagementScope $AssembledPath, $ConnectionOptions 
    $Scope.Connect()

    $QueryString = "SELECT * FROM " + $class 
    if ($Filter) { $QueryString += ' WHERE ' + $Filter}

    $query = New-Object System.Management.ObjectQuery $QueryString 
    $searcher = New-Object System.Management.ManagementObjectSearcher 
    $searcher.set_options($EnumerationOptions) 
    $searcher.Query = $QueryString 
    $searcher.Scope = $Scope

    return $searcher.get()
} 
