$isSetByPolicy = $false
$gpResultFile = Join-Path -Path $env:TEMP -ChildPath ('{0:yyyyMMddHHmmss}-gpresult.xml' -f [datetime]::Now)
$lpResultFile = Join-Path -Path $env:TEMP -ChildPath ('{0:yyyyMMddHHmmss}-lpresult.inf' -f [datetime]::Now)

& "$env:windir\system32\gpresult.exe" /scope:computer /x $gpResultFile
if ($LASTEXITCODE -eq 0) {
    $rsopText = Get-Content -Path $gpResultFile
    $sections = $rsopText -match '\<\w+\:UserRightsAssignment\>' | Select-Object -Unique
    if ($sections) {
        $rsopXml = ([xml]$rsopText).Rsop
        foreach ($section in $sections) {
            $tag = $sections -replace '\s+\<|\>'
            $userRightsAssignment = $rsopXml.GetElementsByTagName($tag)
            if (($userRightsAssignment.GetEnumerator()).Name -contains 'SeServiceLogonRight') {
                Write-Warning -Message 'SeServiceLogonRight is set through domain group policy!'
                $isSetByPolicy = $true
            }
        }
    }
} else {
    Write-Warning -Message 'cannot determine domain group policy'
}

if (-not $isSetByPolicy) {
    & "$env:windir\system32\secedit.exe" /export /cfg $lpResultFile | Out-Null
    if ($LASTEXITCODE -eq 0) {
        if (@(Get-Content -Path $lpResultFile |
                    Where-Object { $_ -match 'SeServiceLogonRight = ' }).Count -gt 0) {
            Write-Warning -Message 'SeServiceLogonRight is set through local policy!'
            $isSetByPolicy = $true
        }
    } else {
        Write-Warning -Message 'cannot determine local policy'
    }
}
$gpResultFile, $lpResultFile | Remove-Item -Force -ErrorAction SilentlyContinue
$isSetByPolicy