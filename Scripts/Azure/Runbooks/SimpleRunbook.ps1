$connectionName = Get-AutomationVariable -Name 'AutomationConnectionName'
$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

try
{
    "Authenticating..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | Out-Null
}
catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

Write-Output ('')
Get-AzureRmResourceGroup | ForEach-Object {
    Write-Output ('Resources in [{0}]:' -f $_.ResourceGroupName)

    Get-AzureRmResource -ResourceGroupName $_.ResourceGroupName | ForEach-Object {
        Write-Output ($_.Name + ' of type ' +  $_.ResourceType)
    }
    Write-Output ('')
}