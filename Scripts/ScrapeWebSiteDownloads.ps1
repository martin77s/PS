param (
    [System.Management.Automation.PSCredential] $Credential,
    [array] $DocumentTypes = @('pdf', 'doc', 'docx', 'xls', 'xlsx', 'xlsm', 'xlsxm', 'ppt', 'pptx', 'jpg', 'gif', 'mp4', 'm4v', 'mp3', 'mov', 'avi', 'wmv', 'wma'),
    [string] $OutputPath = 'C:\Temp\',
    [switch] $UseCredentialAsPSCred,
    [Parameter(Mandatory = $true)][string] $Site
)
if ($Credential) {
    $Username = $Credential.UserName
    $Password = $Credential.GetNetworkCredential().Password
    $CredentialString = "$($Username):$($Password)"
    $CredentialEncoded = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($CredentialString))
    $BasicAuthValue = "Basic $($CredentialEncoded)"
    $Headers = @{ Authorization = $BasicAuthValue }
}
try { $data = Invoke-WebRequest -Uri $site }
catch { "unable to gather data from $($site)" }
if (!(Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -Type Directory -Force | Out-Null
}
$OutputPath = $OutputPath.TrimEnd('\')
if ($data) {
    [array]$Links = @()
    $Links += ($data.Links).Href
    $Filter = '(?i)(' + (($DocumentTypes | % { [regex]::escape($_) }) -join '|') + ')$'
    [array]$FilesToDownload = $Links -match $Filter
 
    $i = 1
    $iTotal = $FilesToDownload.Count
    foreach ($File in $FilesToDownload) {
        $Filename = Split-Path $File -Leaf
        $OutputFile = Join-Path $OutputPath -ChildPath $Filename
        Write-Progress -Activity "Downloading $($File)." -PercentComplete (($i / $iTotal) * 100) -Id 1 -Status "File $($i) of $($iTotal)"
        $params = @{ }
        $params.Add('Uri', $File)
        $params.Add('OutFile', $OutputFile)
        if ($Credential) {
            if ($UseCredentialAsPSCred -and $Headers) {
                $params.add('Headers', $Headers)
            } Else {
                $params.Add('Credential', $Credential)
            }
        }
        try { Invoke-WebRequest @params }
        catch { Write-Progress -Status "Error downloading $($File)." -Activity "Downloading $($File)." }
        $i++
    }
    Write-Progress -Activity 'Finished.' -Completed
}