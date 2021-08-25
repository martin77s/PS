#************************************************
# CheckMaxTokenSize.ps1
# Version 1.0
# Date: 7/19/2013
# Author: Tim Springston [MS]
# Description:  Query for all token items (groups, SIDs, useraccountcontrol) and calculate an
# estimated current token size for the logged on user. Calls out if the token is potentially too 
# large for consistently successful use based on operating system defaults.
# KB http://support.microsoft.com/kb/327825
#************************************************
cls

$SecurityGlobalScope  = 0
$SecurityDomainLocalScope = 0
$SecurityUniversalInternalScope = 0
$SecurityUniversalExternalScope = 0

#Obtain domain SID for group SID comparisons.
$UserIdentity = [Security.Principal.WindowsIdentity]::GetCurrent().User
$DomainSID = $UserIdentity.AccountDomainSid

foreach ($GroupSid in [Security.Principal.WindowsIdentity]::GetCurrent().Groups) 
      {     
      $Group = [adsi]"LDAP://<SID=$GroupSid>"
      $GroupType = $Group.groupType
      $Count++
      #Count number of security groups in different scopes.
      switch -exact ($GroupType)
            {"-2147483646" 	{
							#Domain Global scope
                            $SecurityGlobalScope++
							#Write-Host "$GroupSid is a domain global group."
                           	}
            "-2147483644"  	{
							#Domain Local scope
						    $SecurityDomainLocalScope++
							#Write-Host "$GroupSid is a domain local group."
                            }
            "-2147483640"   {
							#Universal scope; must separate local
							#domain universal groups from others.
							if ($GroupSid -match $DomainSID)
                                {
								$SecurityUniversalInternalScope++
								#Write-Host "$GroupSid is a universal group in users domain."
								}
								else
									{
									$SecurityUniversalExternalScope++
									#Write-Host "$GroupSid is a universal group outside of users domain."
									}
                            }
            }

      }

#Determine OS and computer role
$OS = Get-WmiObject -Class Win32_OperatingSystem
$cs =  gwmi -Namespace "root\cimv2" -class win32_computersystem
$DomainRole = $cs.domainrole
switch -regex ($DomainRole) {
	[0-1]{
		 #Workstation.
		$RoleString = "client"
		if ($OS.BuildNumber -eq 3790)									
		{$OSString = "Windows XP"}
			elseif (($OS.BuildNumber -eq 6001) -or ($OS.BuildNumber -eq 6002))
				{$OSString = "Windows Vista"}
					elseif (($OS.BuildNumber -eq 7600) -or ($OS.BuildNumber -eq 7601))
							{$OSString = "Windows 7" }
						elseif
							($OS.BuildNumber -eq 9200)
							{$OSString =  "Windows 8"}
		}
	[2-3]{
		 #Member server.
		 $RoleString = "member server"
		 if ($OS.BuildNumber -eq 3790)
	 		{$OSString =  "Windows Server 2003"}
			elseif (($OS.BuildNumber -eq 6001) -or ($OS.BuildNumber -eq 6002))
				{$OSString =  "Windows Server 2008 RTM"}
				elseif (($OS.BuildNumber -eq 7600) -or ($OS.BuildNumber -eq 7601))
					{$OSString =  "Windows Server 2008 R2"}
					elseif ($OS.BuildNumber -eq 9200)
						{$OSString = "Windows Server 2012"}
		 }
	[4-5]{
		 #Domain Controller
		 $RoleString = "domain controller"
		 if ($OS.BuildNumber -eq 3790)
	 		{$OSString =  "Windows Server 2003"}
			elseif (($OS.BuildNumber -eq 6001) -or ($OS.BuildNumber -eq 6002))
				{$OSString =  "Windows Server 2008 RTM"}
				elseif (($OS.BuildNumber -eq 7600) -or ($OS.BuildNumber -eq 7601))
					{$OSString =  "Windows Server 2008 R2"}
					elseif ($OS.BuildNumber -eq 9200)
						{$OSString = "Windows Server 2012"}
		 }
	}



#Give some messaging about the user and environment so that an admin can just ask for user 
# to send the output and it should have all the info that is needed.
$UsernameString = "'" + $env:USERNAME + "'"
Write-Host "Checking the token of user $UsernameString in domain $env:userdnsdomain for token sizing issues per Knowledge Base article http://support.microsoft.com/kb/327825." 
Write-Host "The computer is $OSString and is a $RoleString."
Write-Host "There are $Count groups in the token."
#Reset the counter in case the script is ran twice.
$Count = 0
Write-Host "$SecurityGlobalScope are domain global scope security groups."
Write-Host "$SecurityDomainLocalScope are domain local security groups."
Write-Host "$SecurityUniversalInternalScope are universal security groups inside of the users domain."
Write-Host "$SecurityUniversalExternalScope are universal security groups outside of the users domain."

$SIDCounter = 0
$username = $env:username
$ADRoot = ([System.DirectoryServices.DirectoryEntry]"LDAP://RootDSE").defaultNamingContext
$ADFilter = "(&(samAccountName=$username))"
$ADPropertyList = "sidhistory"
$ADScope = "SUBTREE"
$ADPageSize = 1000
$ADSearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($ADRoot)") 
$ADSearcher = New-Object System.DirectoryServices.DirectorySearcher 
$ADSearcher.SearchRoot = $ADSearchRoot
$ADSearcher.PageSize = $ADPageSize 
$ADSearcher.Filter = $ADFilter 
$ADSearcher.SearchScope = $ADScope

if ($ADPropertyList){foreach ($ADProperty in $ADPropertyList){[Void]$ADSearcher.PropertiesToLoad.Add($ADProperty)}}
	$ADResults = $ADSearcher.FindAll()
   	$SearchResult=@()
  	foreach ($ADResult in $ADResults){
  	$ADObject = New-Object System.DirectoryServices.DirectoryEntry("$($ADResult.Path)")
  	$SearchResult += $ADObject
	}

$SIDCounter = 0
if ($ADObject.SidHistory -ne $null)
	{
	$SIDHistObj = New-Object PSObject -Property $ADObject.Properties
	foreach ($SID in $SIDHistObj.SidHistory)
		{
		#Write-Host "$SID  is in the SIDHistory."
		$SIDCounter++
		}
	}

	
Write-host "There are $SIDCounter SIDs in the users SIDHistory."
$SIDHistObj = $null
$userList = $null

#Next, get useraccountcontrol value of the user object to check to see whether
#trusted for delegation is set on the account.
$ADRoot = ([System.DirectoryServices.DirectoryEntry]"LDAP://RootDSE").defaultNamingContext
$ADFilter = "(&(samAccountName=$username))"
$ADPropertyList = "useraccountcontrol"
$ADScope = "SUBTREE"
$ADPageSize = 1000
$ADSearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($ADRoot)") 
$ADSearcher = New-Object System.DirectoryServices.DirectorySearcher 
$ADSearcher.SearchRoot = $ADSearchRoot
$ADSearcher.PageSize = $ADPageSize 
$ADSearcher.Filter = $ADFilter 
$ADSearcher.SearchScope = $ADScope

if ($ADPropertyList){foreach ($ADProperty in $ADPropertyList){[Void]$ADSearcher.PropertiesToLoad.Add($ADProperty)}}
$ADResults = $ADSearcher.FindOne()

$userUACList = @()
if($ADResults -is [System.DirectoryServices.SearchResult]){

	$UACObj = New-Object PSObject -Property $ADResults.Properties
	$userUACList += $UACObj

}

$UACValue = $UACObj.useraccountcontrol
$TrustedforDelegation = $false
$UACObj = $null
$userUACList = $null
#Commented out the output of the UAC value.
Write-Host "The current userAccountControl value is $UACValue."

if (($UACValue -eq 524288) -or ($UACValue -eq 524800) -or ($UACValue -eq 16777216) -or ($UACValue -eq 528416) -or ($UACValue -eq 16781344))
	{$TrustedforDelegation = $true}

#Calculate the current token size, taking into account whether or not the account is trusted for delegation or not.
$TokenSize = 0
if ($TrustedforDelegation -eq $true)
	{
	$TokenSize = 2 * (1200 + (40 * ($SecurityDomainLocalScope + $SecurityUniversalExternalScope + $SIDCounter)) + (8 * ($SecurityGlobalScope  + $SecurityUniversalInternalScope)))
	Write-Host "Token size is $Tokensize and the user is trusted for delegation."
	}
	else
		{
		$TokenSize = 1200 + (40 * ($SecurityDomainLocalScope + $SecurityUniversalExternalScope + $SIDCounter)) + (8 * ($SecurityGlobalScope  + $SecurityUniversalInternalScope))
		Write-Host "Token size is $Tokensize and the user is not trusted for delegation."
		}


#Assess OS so we can alert based on default for proper OS version. Windows 8 and Server 2012 allow for a larger token size safely.
$ProblemDetected = $false
if (($OS.BuildNumber -lt 9200) -and ($Tokensize -ge 12000))
	{
	$ProblemDetected = $true
	}
if (($OS.BuildNumber -ge 9200) -and ($Tokensize -ge 48000))
	{
	$ProblemDetected = $true
	}
if ($ProblemDetected -eq $true)
	{
	Write-Host "******************************************"
	Write-Host "Problem detected. The token was too large for consistent authorization. Alter the maximum size per KB http://support.microsoft.com/kb/327825 and consider reducing direct and transitive group memberships." -foregroundcolor "red"
	}
	else
		{
		Write-Host "******************************************"
		Write-Host "Problem not detected." -foregroundcolor "green"

		}