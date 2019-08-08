
Import-Module WebAdministration

$title = 'IIS Web Configuration Flags Report ({0})' -f (Get-Date)
$head = @'
    <style >
        table { border-collapse: collapse; }
        table, th, td { border: 1px solid black; padding: 5px; text-align: left; }
        th { background-color: #808080; color: white; }
        tr:hover { background-color: #E5E5E5; }
        .Bad { background-color: #FF5030; text-align: center; width: 100%; height: 100%; display: block; }
        .OK { background-color: #4CAF50; text-align: center; width: 100%; height: 100%; display: block; }
        .Warn { background-color: #FFAA00; text-align: center; width: 100%; height: 100%; display: block; }
    </style>
'@

function Expand-EnvironmentVarible {
    param($String)
    Get-ChildItem env: | ForEach-Object {
        if ($String -match $_.Name) {
            $String = $String -replace ('%{0}%' -f $_.Name), $_.Value
        }
    }
    $string
}

#$tempReportFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('{0:yyyyMMddHHmm}.html' -f (Get-Date))
$tempReportFile = Join-Path -Path ($PSScriptRoot) -ChildPath ('{0}.html' -f ($MyInvocation.MyCommand.Name -replace '\.ps1'))
$reportData = & {

    $root = @(New-Object PSObject -Property @{name=$ENV:COMPUTERNAME; physicalPath = 'C:\Windows\system32\inetsrv\config\applicationHost.config' })
    
    $sites = @(Get-Website | Select-Object -Property name, @{N = 'physicalPath'; E = {
            Join-Path -Path (Expand-EnvironmentVarible -String $_.PhysicalPath) -ChildPath web.config } })
    
    $apps = @(foreach ($site in $sites) {
        Get-WebApplication -Site $site.Name | Select-Object -Property @{N='name';E={ ('{0}/{1}' -f $site.Name, ($_.path -replace '/')) }},
            @{N='physicalPath'; E= { Join-Path -Path (Expand-EnvironmentVarible -String $_.PhysicalPath) -ChildPath web.config }} })

     $root + ($sites + $apps | Sort-Object -Property name) | ForEach-Object {

        $appName = $_.Name
        $path = $_.physicalPath

        if (Test-Path -Path $path -PathType Leaf -ErrorAction SilentlyContinue) {
            $xml = [xml](Get-Content -Path $path)

            $xPath = '//system.webServer/httpErrors'
            $node = $xml.SelectSingleNode($xPath)
            $httpErrors = $node.errorMode

            $xPath = '//system.web/compilation'
            $node = $xml.SelectSingleNode($xPath)
            $batch = $node.batch
            $debug = $node.debug
            $optimizeCompilations = $node.optimizeCompilations

            $xPath = '//system.web/customErrors'
            $node = $xml.SelectSingleNode($xPath)
            $customErrors = $node.mode

            $xPath = '//system.webServer/security/requestFiltering/requestLimits'
            $node = $xml.SelectSingleNode($xPath)
            $maxAllowedContentLength = $node.maxAllowedContentLength

            $xPath = '//system.web/httpRuntime'
            $node = $xml.SelectSingleNode($xPath)
            $maxRequestLength = $node.maxRequestLength

            $xPath = '//system.webServer/directoryBrowse'
            $node = $xml.SelectSingleNode($xPath)
            $directoryBrowse = $node.enabled

            New-Object -TypeName PSObject -Property @{
                Application             = $appName
                Debug                   = $debug
                Batch                   = $batch
                OptimizeCompilations    = $optimizeCompilations
                CustomErrors            = $customErrors
                HttpErrors              = $httpErrors
                maxRequestLength        = $maxRequestLength
                MaxAllowedContentLength = $maxAllowedContentLength
                DirectoryBrowse         = $directoryBrowse
            } | Select-Object Application , Debug, OptimizeCompilations, Batch, CustomErrors, HttpErrors, MaxRequestLength, MaxAllowedContentLength, DirectoryBrowse

        } else {
            '' | Select-Object @{N='Application';E={$appName}} , Debug, OptimizeCompilations, Batch, CustomErrors, HttpErrors, MaxRequestLength, MaxAllowedContentLength, DirectoryBrowse
        }
    } | ConvertTo-Html -Title $title -Head $head -PreContent "<h2>$title</h2>"
}

$pattern = '^<tr><td>(?<AppName>.*)</td><td>(?<Debug>.*)</td><td>(?<Batch>.*)</td><td>(?<OptimizeCompilations>.*)</td><td>(?<CustomErrors>.*)</td><td>(?<HttpErrors>.*)</td><td>(?<MaxRequestLength>.*)</td><td>(?<MaxAllowedContentLength>.*)</td><td>(?<DirectoryBrowse>.*)</td></tr>'
$html = $reportData | ForEach-Object {
    if ($_ -match $pattern) {
        '<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td>{4}</td><td>{5}</td><td>{6}</td><td>{7}</td><td>{8}</td></tr>' -f `
            $Matches.AppName,
        ('<span class="{0}">{1}</span>' -f $(if ($Matches.Debug -eq $true) { 'Bad' } else { 'OK' }), $Matches.Debug),
        ('<span class="{0}">{1}</span>' -f $(if ($Matches.Batch -eq $false) { 'Bad' } else { 'OK' }), $Matches.Batch),
        ('<span class="{0}">{1}</span>' -f $(if ($Matches.OptimizeCompilations -eq $false) { 'Bad' } else { 'OK' }), $Matches.OptimizeCompilations),
        ('<span class="{0}">{1}</span>' -f $(if ($Matches.CustomErrors -eq 'Off') { 'Bad' } else { 'OK' }), $Matches.CustomErrors),
        ('<span class="{0}">{1}</span>' -f $(if ($Matches.HttpErrors -eq 'detailed') { 'Bad' } else { 'OK' }), $Matches.HttpErrors),
        ('<span class="Warn">{0:n2}</span>' -f $(if ($Matches.maxRequestLength) { $Matches.maxRequestLength / 1kb } )),
        ('<span class="Warn">{0:n2}</span>' -f $(if ($Matches.maxAllowedContentLength) { $Matches.maxAllowedContentLength / 1mb })),
        ('<span class="{0}">{1}</span>' -f $(if ($Matches.DirectoryBrowse -eq $true) { 'Bad' } else { 'OK' }), $Matches.DirectoryBrowse)

    }
    else {
        $_
    }
}

$html | Out-File -FilePath $tempReportFile
Invoke-Item -Path $tempReportFile
