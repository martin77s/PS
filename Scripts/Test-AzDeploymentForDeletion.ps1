param(
    [string] $Resourcegroup,
    [string] $Templatefile,
    [string] $TemplateParameterFile
)

$params = @{
    ResourcegroupName     = $ResourceGroup
    Templatefile          = $Templatefile
    TemplateParameterFile = $TemplateParameterFile
    Mode                  = 'Complete'
}

$result = Get-AzResourceGroupDeploymentWhatIfResult @params
$deleted = $result.Changes | Where-Object { $_.ChangeType -eq 'Delete' }

if ($deleted.Count -gt 0) {
    Throw "$($deleted.Count) resources would be removed"
}