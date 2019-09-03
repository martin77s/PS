function Get-MsiProductInformation {
    param($Path)
    $msis = Get-ChildItem -File -Path $Path -Filter '*.msi'
    foreach($msi in $msis) {
        $WI = New-Object -ComObject WindowsInstaller.Installer
        $DB = $WI.GetType().InvokeMember("OpenDatabase","InvokeMethod", $Null, $WI, @($msi.FullName, 0))

        $query = 'SELECT * FROM Property'
        $View = $DB.GetType().InvokeMember("OpenView","InvokeMethod",$Null,$DB,($query))
        $View.GetType().InvokeMember("Execute", "InvokeMethod", $Null, $View, $Null)
        $Rec = $View.GetType().InvokeMember("Fetch","InvokeMethod",$Null,$View,$Null)

        $props = @{}
        while ($Rec -ne $null) {
            $props[$rec.GetType().InvokeMember("StringData", "GetProperty", $Null, $rec, 1)] = $rec.GetType().InvokeMember("StringData", "GetProperty", $Null, $rec, 2)
            $rec = $View.GetType().InvokeMember("Fetch","InvokeMethod",$Null,$View,$Null)
        }

        New-Object PSObject -Property @{
            ProductName    = $props.ProductName    
            ProductVersion = $props.ProductVersion 
            ProductCode    = $props.ProductCode    
        }
    }
}

# Example:
# Get-MsiProductInformation -Path C:\Installs