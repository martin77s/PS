function Add-ExtendedAttribute {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [Alias(‘FullName’, ‘PSPath’)]
        [string[]]$Path,
 
        [Parameter(Mandatory = $true)]
        [ValidateRange(0,287)]
        [int[]]$ExtendedAttributeId
 
    )
    begin {
        $oShell = New-Object -ComObject Shell.Application
    }
 
    process {
        $Path | ForEach-Object {
 
            if (Test-Path -Path $_ -PathType Leaf) {
 
                $FileItem = Get-Item -Path $_ 
                $oFolder = $oShell.Namespace($FileItem.DirectoryName)
                $oItem = $oFolder.ParseName($FileItem.Name)
 
                $ExtendedAttributeId | ForEach-Object { 
                    $ExtPropName = $oFolder.GetDetailsOf($oFolder.Items, $_)
                    $ExtValName = $oFolder.GetDetailsOf($oItem, $_)
              
                    $params = @{
                        InputObject = $FileItem
                        MemberType = ‘NoteProperty’
                        Name = $ExtPropName
                        Value = $ExtValName
                    }
                    $FileItem = Add-Member @params -PassThru
                }
            }
            $FileItem
        }
 
    }
 
    end {
        $oShell = $null
    }
}