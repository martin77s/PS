
function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    Write-Verbose "Getting SymbolicLink for $Path"

    $Root = Split-Path -Path $Path -Parent
    $LinkName = Split-Path -Path $Path -Leaf
    $TargetPath = $null

    $link = Get-Item -Path (Join-Path -Path $Root -ChildPath $LinkName) -ErrorAction SilentlyContinue
    if($link -and  $link.LinkType -eq 'SymbolicLink') { $TargetPath = $link.Target[0] }
    
    $returnValue = @{
        Path   = $Path
        TargetPath = $TargetPath
    }

    $returnValue
}


function Set-TargetResource {
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [System.String]
        $TargetPath
    )

    Write-Verbose "Creating a SymbolicLink from $Path to $TargetPath"

    $Root = Split-Path -Path $Path -Parent
    $LinkName = Split-Path -Path $Path -Leaf
    Set-Location -Path $Root
    New-Item -ItemType SymbolicLink -Name $LinkName -Target $TargetPath | Out-Null

}


function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [System.String]
        $TargetPath
    )

    Write-Verbose "Testing SymbolicLink for $Path"

    $current = Get-TargetResource -Path $Path
    return (($current.Path -eq $Path) -and ($current.TargetPath -eq $TargetPath))
}


Export-ModuleMember -Function *-TargetResource
