break

# How to return multiple values from a function?
function Get-Something {
    'Martin'
    'MSFT'
}
$result = Get-Something


# From PSv1
$t1 = New-Object -TypeName psobject
$t1 | Add-Member -MemberType NoteProperty -Name Color -Value Black
$t1 | Add-Member -MemberType NoteProperty -Name Size -Value L
$t1


# The "israeli" way
$t2 = '' | Select-Object Color, Size
$t2.Color = 'Green'
$t2.Size = 'XL'
$t2


# PSv2
$t3 = New-Object -TypeName psobject -Property @{
    Color = 'Red'
    Size  = 'M'
}
$t3


# PSv3
$t4 = [PSCustomObject]@{
    Color = 'Yellow'
    Size  = 'XS'
}
$t4


# Adding other member types
$file = Get-Item C:\Temp\scraps\blah.txt
$file | Add-Member -MemberType AliasProperty -Name Size -Value Length
$file.Size


$obj = New-Object PSObject
$obj | Add-Member NoteProperty -Name Name -Value ''
$obj | Get-Member

$obj | Add-Member -MemberType ScriptMethod -Name SetName -Value {
    $this.Name = Read-Host 'Please enter your name' }

$obj | Get-Member
$obj.SetName()
$obj.Name