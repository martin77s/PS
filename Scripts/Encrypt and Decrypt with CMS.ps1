# Get the script content as string:
$scriptContent = Get-Content -Path C:\Temp\plainTextScript.ps1

# Create the certificate:
$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\CurrentUser\my `
    -KeyUsage KeyEncipherment, DataEncipherment, KeyAgreement -Type DocumentEncryptionCert

# Encrypt message:
$scriptContent | Protect-CmsMessage -To $cert -OutFile C:\Temp\encryptedScript.txt

# Verify the encrypted contents:
notepad C:\Temp\encryptedScript.txt

# Export the certificate:
$certPassword = 'Password1' | ConvertTo-SecureString -AsPlainText -Force
Export-PfxCertificate -Cert $cert -FilePath C:\Temp\CMS.pfx -Password $certPassword



# *** ON THE NEXT MACHINE ***


# Import the certificate:
$certPassword = 'Password1' | ConvertTo-SecureString -AsPlainText -Force
Import-PfxCertificate -FilePath C:\Temp\CMS.pfx -CertStoreLocation Cert:\CurrentUser\My -Password $certPassword


# Decrypt message (The cert needs to be installed on the machine):
$plainTextcode = Unprotect-CmsMessage -Path C:\Temp\encryptedScript.txt


# Invoke the code:
Invoke-Expression -Command $plainTextcode