
function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [parameter(Mandatory = $true)]
        [System.String]
        $SubInterface
    )

    Write-Verbose "Checking the MTU value on SubInterface $SubInterface"

    $MTU = 0  # 0 = Incase the subinterface is not found
    $output = netsh.exe interface ipv4 show interfaces interface="$SubInterface"
    if (($output -join "`n") -match 'Link MTU\s*:\s(?<MTU>\d*)\sbytes') {
        $MTU = $matches.MTU
    }

    $ret = @{
        SubInterface = [System.String]$SubInterface
        MTU = [System.UInt16]$MTU
    }

    $ret
}


function Set-TargetResource {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [System.String]
        $SubInterface,

        [System.UInt16]
        $MTU
    )

    Write-Verbose "Setting an MTU of $MTU on SubInterface $SubInterface"

    $output = netsh.exe interface ipv4 set subinterface "$SubInterface" mtu=$MTU store=persistent
    if(-not $?) {
        throw "Error setting MTU on $SubInterface"
    }

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1

}


function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [parameter(Mandatory = $true)]
        [System.String]
        $SubInterface,

        [System.UInt16]
        $MTU
    )

    Write-Verbose "Checking if SubInterface $SubInterface has an MTU of $MTU"

    $current = Get-TargetResource -SubInterface $SubInterface
    $current.MTU -eq $MTU
}


Export-ModuleMember -Function *-TargetResource
