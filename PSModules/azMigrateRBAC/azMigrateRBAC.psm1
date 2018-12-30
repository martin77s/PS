#requires -Module AzureAD, Az.Accounts

function Login {
    Write-Host 'Login to Azure Active Directory'
    Import-Module -Name AzureAD
    Connect-AzureAD

    Write-Host 'Login to Azure Resource Manager'
    Import-Module -Name Az.Accounts
    Connect-AzAccount
}

function Find-AADUser {
    param([string] $userPrincipalName)
    $user = Get-AzureADUser -Filter "userPrincipalName eq '$userPrincipalName'"
    if (-not $user) {
        if ($userPrincipalName.Contains('#EXT#')) {
            $userPrincipalName = $userPrincipalName.SubString(0, $userPrincipalName.IndexOf("#")).Replace("_", "@")
            $user = Find-AADUser -userPrincipalName $userPrincipalName
        }
        else {
            $user = $null
        }
    }
    $user
}


function Assert-AADObjectId {

    [CmdletBinding()]

    Param(
        [Parameter(Mandatory)]
        [string] $ObjectId,

        [ValidateSet('User', 'Group', 'ServicePrincipal')]
        [string] $ObjectType
    )

    $NewObjectId = $null
    if ($ObjectIdTranslation.ContainsKey($ObjectId)) {

        $NewObjectId = $ObjectIdTranslation[$ObjectId]

    }
    else {

        switch ($ObjectType) {
            'Group' {
                $OldObject = $OldTenant.Groups | Where-Object { $_.ObjectId -eq $ObjectId }
                $Group = Get-AzureADGroup -Filter ("DisplayName eq '{0}'" -f $OldObject.DisplayName)
                if (!$Group) {
                    $Group = New-AzureADGroup -DisplayName $OldObject.DisplayName -MailEnabled $false -SecurityEnabled $true -MailNickName 'NotSet'

                    foreach ($member in $OldObject.Members) {
                        Add-AzureADGroupMember -ObjectId $Group.ObjectId -RefObjectId (Assert-AADObjectId -ObjectId $member.ObjectId -ObjectType $member.ObjectType)
                    }
                }
                else {
                    $Group = New-Object PSObject -Property @{'ObjectId' = (New-Guid).Guid}
                }
                $ObjectIdTranslation.Add($OldObject.ObjectId, $Group.ObjectId)
                $NewObjectId = $Group.ObjectId
                break
            }

            'ServicePrincipal' {
                $OldObject = $OldTenant.ServicePrincipals | Where-Object { $_.ObjectId -eq $ObjectId }
                $SPN = Get-AzureADServicePrincipal -Filter ("DisplayName eq '{0}'" -f $OldObject.DisplayName)

                if (!$SPN) {
                    $App = Get-AzureADApplication -Filter ("DisplayName eq '{0}'" -f $OldObject.DisplayName)

                    if (!$App) {
                        if (!$OldObject.ReplyURLs) { $OldObject.ReplyURLs = "http://localhost" }
                        if (!$OldObject.HomePage) { $OldObject.HomePage = "http://localhost" }
                        $App = New-AzureADApplication -DisplayName $OldObject.DisplayName -Homepage $OldObject.HomePage -ReplyUrls $OldObject.ReplyURLs
                        $SPN = New-AzureADServicePrincipal -AccountEnabled $true -AppId $App.AppId -AppRoleAssignmentRequired $true -DisplayName $OldObject.DisplayName -Tags {WindowsAzureActiveDirectoryIntegratedApp}
                    }
                    else {
                        $SPN = Get-AzureADServicePrincipal -Filter ("AppID eq '{0}'" -f $App.AppId)
                        if (!$SPN) {
                            $SPN = New-AzureADServicePrincipal -AccountEnabled $true -AppId $App.AppId -AppRoleAssignmentRequired $true -DisplayName $OldObject.DisplayName -Tags {WindowsAzureActiveDirectoryIntegratedApp}
                        }
                    }

                    if ($OldObject.Owners -ne 'None') {
                        Add-AzureADApplicationOwner -ObjectId $App.ObjectId -RefObjectId (Find-AADUser -userPrincipalName $OldObject.UserPrincipalName).ObjectId
                    }
                }
                $ObjectIdTranslation.Add($OldObject.ObjectId, $SPN.ObjectId)
                $NewObjectId = $SPN.ObjectId
                break
            }

            'User' {
                $OldObject = $OldTenant.Users | Where-Object { $_.ObjectId -eq $ObjectId }
                if ($OldObject.UserPrincipalName) {
                    $User = Find-AADUser -userPrincipalName $OldObject.UserPrincipalName
                    if (-not $User) {
                        $userPrincipalName = $OldObject.UserPrincipalName
                        if ($userPrincipalName -match '#EXT#') {
                            $userPrincipalName = $userPrincipalName.SubString(0, $userPrincipalName.IndexOf("#")).Replace("_", "@")
                        }
                        $userParams = @{
                            DisplayName       = $OldObject.DisplayName
                            UserPrincipalName = $userPrincipalName -replace '@.*', ('@{0}' -f $tenantSuffix)
                            mailNickname      = $userPrincipalName -replace '@.*'
                            UserType          = $OldObject.UserType
                            PasswordProfile   = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile -arg 'pAzzw0rd!', $true
                            AccountEnabled    = $false
                        }
                        $User = New-AzureADUser @userParams
                    }
                    $ObjectIdTranslation.Add($OldObject.ObjectId, $User.ObjectId)
                    $NewObjectId = $User.ObjectId
                }
                break
            }

            default {
                if ($OldTenant.Groups | Where-Object { $_.ObjectId -eq $ObjectId }) {
                    $NewObjectId = Assert-AADObjectId -ObjectId $ObjectId -ObjectType Group
                }
                elseif ($OldTenant.ServicePrincipals | Where-Object { $_.ObjectId -eq $ObjectId }) {
                    $NewObjectId = Assert-AADObjectId -ObjectId $ObjectId -ObjectType ServicePrincipal
                }
                else {
                    $NewObjectId = Assert-AADObjectId -ObjectId $ObjectId -ObjectType User
                }
            }
        }
    }
    return $NewObjectId
}

function Import-RBAC {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [Alias('Path', 'File')]
        [string] $FilePath
    )

    $oldTenant = $null
    try {
        $oldTenant = Import-Clixml -Path $FilePath
    }
    catch {
        throw 'Error: Exported xml files missing, make sure you are reading from the correct path'
    }

    try {

        Get-AzureADTenantDetail -ErrorAction Stop | Out-Null
    }
    catch {
        throw 'Error: Not connected to AzureAD. Please run Connect-AzureAD'
    }

    try {$context = Get-AzContext} catch {}
    if (-not $context.Tenant.Id) {
        throw 'Error: Not connected to Azure RM. Please run Connect-AzAccount'
    }

    $ObjectIdTranslation = @{}
    $sub = Select-AzSubscription -SubscriptionId $oldTenant.Subscription.SubscriptionId -ErrorAction Stop -WhatIf:$false
    if ($PSCmdlet.ShouldProcess(('Azure Subscription: {0} ({1})' -f $sub.Subscription.Name, $sub.Subscription.Id))) {

        $tenantSuffix = (Get-AzureADDomain).Name
        $tenantId = (Get-AzContext).Tenant.Id
        $currentRBAC = Get-AzRoleAssignment -Scope ('/subscriptions/{0}' -f $oldTenant.Subscription.SubscriptionId)

        foreach ($ace In  $oldTenant.Subscription.RBAC) {
            $ObjectId = (Assert-AADObjectId -ObjectId $ace.ObjectId -ObjectType $ace.ObjectType)
            if ($ObjectId) {
                if (-not ($currentRBAC | Where-Object -FilterScript {$_.ObjectId -eq $ObjectId -and $_.ObjectType -eq $ace.ObjectType -and $_.RoleDefinitionName -eq $ace.RoleDefinitionName})) {
                    New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $ace.RoleDefinitionName -Scope ('/subscriptions/{0}' -f $oldTenant.Subscription.SubscriptionId) -Verbose | Out-Null
                }
            }
        }

        $keyVaults = Get-AzKeyVault | Get-AzResource | Where-Object { $_.Properties.tenantId -ne $tenantId }
        foreach ($keyVault in $keyVaults) {
            $keyVault.Properties.tenantId = $tenantId
            foreach ($policy In $KeyVault.Properties.accessPolicies) {
                $newObjectId = Assert-AADObjectId -ObjectId $policy.objectId
                if ($newObjectId) {
                    $policy.tenantId = $tenantId
                    $policy.objectId = $newObjectId
                }
            }
            Set-AzResource -ResourceId $keyVault.Id -Properties $keyVault.Properties -Force -Verbose
        }
    }
}

function Export-RBAC {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SubscriptionId,

        [Parameter(Mandatory)]
        [Alias('Path')]
        [string] $OutputPath
    )

    try {

        Get-AzureADTenantDetail -ErrorAction Stop | Out-Null
    }
    catch {
        throw 'Error: Not connected to AzureAD. Please run Connect-AzureAD'
    }

    try {$context = Get-AzContext} catch {}
    if (-not $context.Tenant.Id) {
        throw 'Error: Not connected to Azure RM. Please run Connect-AzAccount'
    }

    $exportData = @{}

    Write-Verbose 'Reading Subscription RBACs' -Verbose
    $sub = Get-AzSubscription -SubscriptionId $SubscriptionId
    Set-AzContext -SubscriptionObject $sub | Out-Null
    $subscription = New-Object psobject -Property @{
        SubscriptionId   = $sub.Id
        SubscriptionName = $sub.Name
        RBAC             = (Get-AzRoleAssignment | Select-Object -Unique ObjectId, DisplayName, ObjectType, RoleDefinitionName)
    }
    $exportData.Subscription = $subscription

    Write-Verbose 'Reading Users' -Verbose
    $users = Get-AzureADUser -All $true | Select-Object -Property ObjectId, DisplayName, UserPrincipalName, UserType
    $exportData.Users = $users

    Write-Verbose 'Reading Groups' -Verbose
    $groups = Get-AzureADGroup -All $true | ForEach-Object {
        $Members = Get-AzureADGroupMember -ObjectId $_.ObjectId | ForEach-Object {
            if ($_.ObjectType -eq 'Group') {
                $_ | Select-Object -Property ObjectId, DisplayName, ObjectType
            }
            elseif ($_.ObjectType -eq 'User') {
                $_ | Select-Object -Property ObjectId, DisplayName, ObjectType, userPrincipalName
            }
        }
        New-Object -TypeName PSObject -Property @{
            ObjectId    = $_.ObjectId
            DisplayName = $_.DisplayName
            Members     = $Members
        }
    }
    $exportData.Groups = $groups

    Write-Verbose 'Reading Applications' -Verbose
    $apps = Get-AzureADApplication -All $true | ForEach-Object {
        $owners = Get-AzureADApplicationOwner -ObjectId $_.ObjectId
        New-Object -TypeName PSObject -Property @{
            ObjectId    = $_.ObjectId
            AppId       = $_.AppId
            DisplayName = $_.DisplayName
            Owners      = $(if ($owners) { $owners.DisplayName } else {'None'})
        }
    }
    $exportData.Applications = $apps

    Write-Verbose 'Reading Service Principal Names' -Verbose
    $spns = Get-AzureADServicePrincipal -All $true | ForEach-Object {
        $owners = Get-AzureADServicePrincipalOwner -ObjectId $_.ObjectId
        $servicePrincipal = New-Object -TypeName PSObject -Property @{
            ObjectId    = $_.ObjectId
            AppId       = $_.AppId
            DisplayName = $_.DisplayName
            HomePage    = $_.HomePage
            ReplyURLs   = $_.ReplyURLs
            Owners      = 'None'
        }
        if ($owners) {
            $servicePrincipal.Owners = $owners.DisplayName
            $servicePrincipal.UserPrincipalName = $owners.UserPrincipalName
        }
        $servicePrincipal
    }
    $exportData.ServicePrincipal = $spns

    Write-Verbose 'Exporting RBACs' -Verbose
    $outputFile = (Join-Path -Path $OutputPath -ChildPath "$($SubscriptionId).xml")
    $exportData | Export-Clixml -Path $outputFile
    Get-Item -Path $outputFile
}


Export-ModuleMember -Function Login, Export-RBAC, Import-RBAC