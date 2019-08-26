$svc = [ADSI] 'LDAP://cn=myGMSA,CN=Managed Service Accounts,DC=contoso,DC=coml'

$svc.AuthenticationType = 'Sealing,Secure'
$svc.RefreshCache('msDS-ManagedPassword')
$svc.'msDS-ManagedPassword'.Value
$gmsaBlob = $svc.'msDS-ManagedPassword'.Value

[UInt16] $pwdOffset = [BitConverter]::ToUInt16($gmsaBlob[8..9], 0) # Note: this value must not be 0x0000
[UInt16] $previousPwdOffset = [BitConverter]::ToUInt16($gmsaBlob[10..11], 0) # Note: if this value is 0x0000 then the account does not have any previous password

$pwdEnd = $pwdOffset
while (($gmsaBlob[$pwdEnd] -ne 0) -or ($gmsaBlob[$pwdEnd + 1] -ne 0)) { $pwdEnd += 2 }
[byte[]] $gmsaPwd = $gmsaBlob[$pwdOffset..$pwdEnd]
[BitConverter]::ToString($gmsaPwd)