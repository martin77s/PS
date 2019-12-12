break


#region Calculated property with a function

function Get-FriendlySize {
    param($Bytes)
    $sizes = 'Byte(s),KB,MB,GB,TB,PB,EB,ZB' -split ','
    for ($i = 0; ($Bytes -ge 1kb) -and ($i -lt $sizes.Count); $i++) {
        $Bytes /= 1kb
    }
    '{0:N2} {1}' -f $Bytes, $sizes[$i]
}

Get-FriendlySize -Bytes 123123
dir | Select-Object FullName, @{N = 'Size'; E = { Get-FriendlySize $_.Length } }
dir | Select-Object FullName, @{N = 'Size'; E = { Get-FriendlySize $_.Length } } | Sort-Object Size

#endregion



#region Overriding ToString()
function Get-FriendlySize {
    param($Bytes)
    $Bytes | Add-Member -MemberType ScriptMethod -Name ToString -Value {
        $sizes = 'Bytes,KB,MB,GB,TB,PB,EB,ZB' -split ','
        for ($i = 0; ($this -ge 1kb) -and ($i -lt $sizes.Count); $i++) {
            $this /= 1kb
        }
        '{0:N2} {1}' -f $this, $sizes[$i]
    } -Force -PassThru
}
$x = Get-FriendlySize -Bytes 1024
$x + 1
$x
$x.ToString()

#endregion



#region Overriding default formats

dir

$file = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'myFileSystemFormat.ps1xml'
$data = Get-Content -Path $PSHOME\FileSystem.format.ps1xml

$data -replace '<PropertyName>Length</PropertyName>', @'
<ScriptBlock>
if($$_ -is [System.IO.FileInfo]) {
    $this=$$_.Length; $sizes='Bytes,KB,MB,GB,TB,PB,EB,ZB' -split ','
    for($i=0; ($this -ge 1kb) -and ($i -lt $sizes.Count); $i++) {$this/=1kb}
    $N=2; if($i -eq 0) {$N=0}
    "{0:N$($N)} {1}" -f $this, $sizes[$i]
} else { $null }
</ScriptBlock>
'@ | Set-Content -Path $file

Update-FormatData -Path $file


dir

dir | Sort-Object Length


#endregion