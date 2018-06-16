<#

# Define Deployment Variables
$templateName = 'azuredeploy.json'
$location = 'westeurope'
$resourceGroupName = 'rg-contoso-test'
$resourceDeploymentName = 'contoso-template-deployment'
$templatePath = Join-Path -Path $PWD -ChildPath $templateName

# Create the Resource Group
$rgParams = @{
    Name     = $resourceGroupName
    Location = $location
    Verbose  = $true
    Force    = $true
}; New-AzureRmResourceGroup @rgParams


# Deploy the Resources
$deploymentParams = @{
    Name              = $resourceDeploymentName
    ResourceGroupName = $resourceGroupName
    TemplateFile      = $templatePath
    Verbose           = $true
    Force             = $true
}; New-AzureRmResourceGroupDeployment @deploymentParams


#>


function Test-azLogin {
    try {
        if(-not (Get-Module AzureRM.profile)) {

            [void](Import-Module AzureRM.profile -ErrorAction Stop)

        }
        $return = Get-AzureRmContext -ErrorAction Stop

    } catch [System.Management.Automation.PSInvalidOperationException] {
        $return = Login-AzureRmAccount
    } catch {
        Write-Error $_.Exception.Message
    }
    [bool]$return
}


function Get-azLocation {
    Get-AzureRmLocation | 
        Select-Object @{N='Zone';E={
            $_.DisplayName -replace 'East|West|Southeast|South|North|Northeast|Central|\s|\d'
        }}, DisplayName, Location, Providers |
                Sort-Object -Property Zone, Location
}


function Get-azRandomName {
    param(
        [string] $Prefix, 
        [int] $MaxLength = 24
    )
    $TotalLength = $MaxLength - ($Prefix.Length)
    if($TotalLength -gt 0) {
        $rnd = (1..$TotalLength | % {'abcdefghijklmnopqrstuvwxyz0123456789'.ToCharArray() | Get-Random}) -join ''
        "$Prefix$rnd"
    } else {
        throw 'Prefix exceeds maximum length'
    }
}


