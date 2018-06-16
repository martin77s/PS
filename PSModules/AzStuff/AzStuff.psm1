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

    }
    catch [System.Management.Automation.PSInvalidOperationException] {
        $return = Login-AzureRmAccount
    }
    catch {
        Write-Error $_.Exception.Message
    }
    [bool]$return
}


function Get-azLocation {
    Get-AzureRmLocation |
        Select-Object @{N = 'Zone'; E = {
            $_.DisplayName -replace 'East|West|Southeast|South|North|Northeast|Central|\s|\d'
        }
    }, DisplayName, Location, Providers |
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
    }
    else {
        throw 'Prefix exceeds maximum length'
    }
}


function Get-azVMSize {
    param(
        [string] $Location,
        [stirng] $Filter,
        [switch] $NoGrouping
    )

    if($Location) {
        $locations = Get-AzureRmResourceProvider |
            Where-Object { $_.ResourceTypes.ResourceTypeName -contains 'locations/vmSizes' } |
            Select-Object -ExpandProperty Locations
    }
    else {
        $locations = $Location
    }

    $sizes = $locations | ForEach-Object { $location = $_; Get-AzureRmVMSize -Location $_ } |
        Select-Object Name, @{N = 'Location'; E = {$location}}

    if($Filter) {
        $sizes = $sizes | Where-Object { $_ -like $Filter }
    }

    if(-not $NoGrouping) {
        $sizes | Group-Object -Property Name |
            Select-Object Name, @{N = 'Locations'; E = {($_.Group | Select-Object -ExpandProperty Location) -join ', '}}
    }
    else {
        $sizes
    }
}


function Set-azVMAdminPassword {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string] $VMName,

        [Parameter(Mandatory = $true)]
        [PSCredential] $Credential
    )
    Set-AzureRmVMAccessExtension -Name MyVMAccessExt @PSBoundParameters
}