# Set script varaibles
$sourceFolder = 'C:\Temp\Source'
$targetFolder = 'C:\Temp\Target'
$anchorRegPath = 'HKLM:\SOFTWARE\CopyDeltaWsus'
$anchorRegVal = 'AnchorTimeStamp'


# Get the anchor time stamp
    try {
    $anchorTimeStamp = [datetime](Get-ItemProperty -Path $anchorRegPath -Name $anchorRegVal -ErrorAction SilentlyContinue | 
        Select-Object -ExpandProperty $anchorRegVal)
} catch {
    $anchorTimeStamp = [datetime]::MinValue
}
Write-Verbose -Message ('Using {0} as the anchor time stamp' -f $anchorTimeStamp) -Verbose


# Scan the candidates for copy
$filesToCopy = @(dir -Path $sourceFolder -File -Force -Recurse | 
    Where-Object { $_.LastWriteTime -gt $anchorTimeStamp } | Sort-Object -Descending -Property LastWriteTime)


# Copy the files
$filesToCopy | ForEach-Object {
    $target = $_.DirectoryName -replace [regex]::Escape($sourceFolder), $targetFolder
    if(-not (Test-Path -Path $target)) { $null = New-Item -Path $target -ItemType Directory }
    Copy-Item -Path $_.FullName -Destination $target -Force -Verbose
}


# Save the new anchor time stamp
if($filesToCopy.Count -gt 0) {
    $newAnchorTimeStamp = ($filesToCopy[0].LastWriteTime).AddSeconds(1)
} else {
    $newAnchorTimeStamp = Get-Date
}
Set-ItemProperty -Path $anchorRegPath -Name $anchorRegVal -Value ('{0:yyyy-MM-dd HH:mm:ss}' -f $newAnchorTimeStamp) -Force