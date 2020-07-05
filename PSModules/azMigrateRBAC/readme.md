# azMigrateRBAC

## Step #1 - Backup Role Assignments:

Backup all the role assignments from the source tenant using the PowerShell commands below to login to Azure to the current ("old") tenant, export the roles and permissions, login again to the target ("new") tenant and export the list of users to be used for the mappings.

```powershell
Import-Module AzMigrateRBAC
Login-Azure -TenantId $oldTenantId
Export-RBAC -Path C:\TargetFolder -SubscriptionId $subscriptionIdToMove
Login-Azure -TenantId $newTenantId
Export-UserList -Path C:\TargetFolder
```

## Step #2 - Edit the mappings file:

Locate the **UserMappings.csv** file and edit it to map the old users in the old tenant to the users in the new tenant. These users need to exist prior the next step.
You can use the **NewTenantUserList.csv** (created in the previous step by running the Export-UserList command) located in the target folder.
Actually, the only mappings you need to have in the **UserMappings.csv** file are the mappings for the identities listed in the **RBAC.htm** file. All the rest can be removed.

## Step #3 - Initiate the transfer: 

At this step, the Subscription owner in the source tenant can proceed to "Transfer" the subscription from the source tenant to the target tenant.
Do not perform this step without performing step #1 as executing this step will reset all the role assignments in the source tenant and those deleted role assignments cannot be restored from that point of time on-wards.

## Step #4 - Restore Role Assignments: 

Restore all the role assignments on to the target tenant using the PowerShell commands below to login to Azure to the new tenant

```powershell
Import-Module AzMigrateRBAC
Login-Azure -TenantId $newTenantId
Import-RBAC -Path C:\TargetFolder
```

## Important notes

    - The user initiating the subscription transfer needs to be invited from the source tenant to the destination tenant
    - Verify target Management group structure and policies
    - Recreate Managed Identities where needed
      See [https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/known-issues#will-managed-identities-be-recreated-automatically-if-i-move-a-subscription-to-another-directory]
    - Azure DevOps:
        - Switch directory at the organization level
        - Update Service Connections if using Service Principals (at the project level as well)
        - Update administrator and users (at the project level as well)
          See [https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/faq-azure-access?view=azure-devops#faq-connect]
