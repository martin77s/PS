#requires -Module AzureAD, Az.Accounts

function Login {
    Connect-AzureAD
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

    [CmdletBinding(SupportsShouldProcess = $true)]

    Param(
        [Parameter(Mandatory)]
        [string] $ObjectId,

        [ValidateSet('User', 'Group', 'ServicePrincipal')]
        [string] $ObjectType
    )

    $NewObjectId = $ObjectIdTranslation[$ObjectId]

    if (!$NewObjectId) {

        switch ($ObjectType) {
            'Group' {
                $OldObject = $OldTenant.Groups | Where-Object { $_.ObjectId -eq $ObjectId }
                $Group = Get-AzureADGroup -Filter ("DisplayName eq '{0}'" -f $OldObject.DisplayName)
                if (!$Group) {
                    if ($PSCmdlet.ShouldProcess($OldObject.DisplayName, 'New-AzureADGroup')) {
                        $Group = New-AzureADGroup -DisplayName $OldObject.DisplayName -MailEnabled $false -SecurityEnabled $true -MailNickName 'NotSet'

                        foreach ($member in $OldObject.Members) {
                            Add-AzureADGroupMember -ObjectId $Group.ObjectId -RefObjectId (Assert-AADObjectId -ObjectId $member.ObjectId -ObjectType $member.ObjectType)
                        }
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
                    if ($PSCmdlet.ShouldProcess($OldObject.DisplayName, 'New-AzureADApplication')) {
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
                    else {
                        $SPN = New-Object PSObject -Property @{'ObjectId' = (New-Guid).Guid}
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

                    if ($User) {
                        Write-Verbose ("Caching {0} object id for old object ({1})" -f $User.ObjectId, $OldObject.ObjectId)
                        $ObjectIdTranslation.Add($OldObject.ObjectId, $User.ObjectId)
                        $NewObjectId = $User.ObjectId
                    }
                }
                else {
                    return $ObjectId
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
        $Path = ($PWD).Path
    )

    try {

        Get-AzureADTenantDetail -ErrorAction Stop | Out-Null
    }
    catch {
        throw 'Error: Not connected to AzureAD. Please run Connect-AzureAD'
    }

    try {$context = Get-AzContext} catch {}
    if (-not $context.Subscription.Id) {
        throw 'Error: Not connected to Azure RM. Please run Connect-AzAccount'
    }

    try {
        $ObjectIdTranslation = @{}
        $oldTenant = @{
            Subscriptions = (Import-Clixml -Path (Join-Path -Path $Path -ChildPath Subscriptions.xml))
            Users         = (Import-Clixml -Path (Join-Path -Path $Path -ChildPath Users.xml))
            Groups        = (Import-Clixml -Path (Join-Path -Path $Path -ChildPath Groups.xml))
            Applications  = (Import-Clixml -Path (Join-Path -Path $Path -ChildPath Applications.xml))
            SPNs          = (Import-Clixml -Path (Join-Path -Path $Path -ChildPath ServicePrincipal.xml))
        }
    }
    catch {
        throw 'Error: Exported xml files missing, make sure you are reading from the correct path'
    }

    foreach ($sub in $oldTenant.Subscriptions) {
        if ($PSCmdlet.ShouldProcess('Azure Subscription: {0}' -f $sub.Name)) {
            Select-AzSubscription -SubscriptionId $sub.SubscriptionId -ErrorAction Stop
            $currentRBAC = Get-AzRoleAssignment -Scope ('/subscriptions/{0}' -f $sub.SubscriptionId)

            $tenantId = (Get-AzContext).Tenant.Id
            $keyVaults = Get-AzKeyVault | Get-AzResource | Where-Object { $_.Properties.tenantId -ne $tenantId }
            foreach ($keyVault in $keyVaults) {
                $keyVault.Properties.tenantId = $tenantId
                foreach ($policy In $KeyVault.Properties.accessPolicies) {
                    $newObjectId = Find-AzureObjectId -ObjectId $policy.objectId
                    if ($newObjectId) {
                        $policy.tenantid = $tenantId
                        $policy.objectId = Find-AzureObjectId -ObjectId $policy.objectId
                    }
                }
                if ($PSCmdlet.ShouldProcess($keyVault, 'Set-AzResource')) {
                    Set-AzResource -ResourceId $keyVault.Id -Properties $keyVault.Properties -Force -Verbose
                }
            }

            foreach ($ace In $sub.RBAC) {

                if ($PSCmdlet.ShouldProcess($ace.DisplayName, 'New-AzRoleAssignment')) {
                    $ObjectId = (Assert-AADObjectId -ObjectId $ace.ObjectId -ObjectType $ace.ObjectType)

                    if ($ObjectId) {
                        if (-not ($currentRBAC | Where-Object -FilterScript {$_.ObjectId -eq $ObjectId -and $_.ObjectType -eq $ace.ObjectType -and $_.RoleDefinitionName -eq $ace.RoleDefinitionName})) {
                            New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $ace.RoleDefinitionName -Scope ('/subscriptions/{0}' -f $sub.SubscriptionId)
                        }
                    }
                }
            }
        }
    }
}

function Export-RBAC {
    [CmdletBinding()]
    param(
        $SubscriptionName = '*',
        $Path = ($PWD).Path
    )

    try {

        Get-AzureADTenantDetail -ErrorAction Stop | Out-Null
    }
    catch {
        throw 'Error: Not connected to AzureAD. Please run Connect-AzureAD'
    }

    try {$context = Get-AzContext} catch {}
    if (-not $context.Subscription.Id) {
        throw 'Error: Not connected to Azure RM. Please run Connect-AzAccount'
    }

    Write-Verbose 'Exporting Subscriptions' -Verbose
    $subscriptions = Get-AzSubscription | Where-Object { $_.Name -like $SubscriptionName } | ForEach-Object {
        Set-AzContext -SubscriptionObject $_ | Out-Null
        New-Object psobject -Property @{
            SubscriptionId   = $_.Id
            SubscriptionName = $_.Name
            RBAC             = (Get-AzRoleAssignment | Select-Object -Unique ObjectId, DisplayName, ObjectType, RoleDefinitionName)
        }
    }
    $subscriptions | Export-Clixml -Path (Join-Path -Path $Path -ChildPath Subscriptions.xml)


    Write-Verbose 'Exporting Users' -Verbose
    Get-AzureADUser -All $true | Select-Object -Property ObjectId, DisplayName, UserPrincipalName, UserType |
        Export-Clixml -Path (Join-Path -Path $Path -ChildPath Users.xml)


    Write-Verbose 'Exporting Groups' -Verbose
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
    $groups | Export-Clixml -Path (Join-Path -Path $Path -ChildPath Groups.xml)


    Write-Verbose 'Exporting Applications' -Verbose
    $apps = Get-AzureADApplication -All $true | ForEach-Object {
        $owners = Get-AzureADApplicationOwner -ObjectId $_.ObjectId
        New-Object -TypeName PSObject -Property @{
            ObjectId    = $_.ObjectId
            AppId       = $_.AppId
            DisplayName = $_.DisplayName
            Owners      = $(if ($owners) { $owners.DisplayName } else {'None'})
        }
    }
    $apps | Export-Clixml -Path (Join-Path -Path $Path -ChildPath Applications.xml)


    Write-Verbose 'Exporting Service Principal Names' -Verbose
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
    $spns | Export-Clixml -Path (Join-Path -Path $Path -ChildPath ServicePrincipal.xml)
}

