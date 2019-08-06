# http://support.microsoft.com/kb/2915218
# Generates a <machineKey> element that can be copied + pasted into a Web.config file.
function Generate-MachineKey {
  [CmdletBinding()]
  param (
    [ValidateSet("AES", "DES", "3DES")]
    [string]$decryptionAlgorithm = 'AES',
    [ValidateSet("MD5", "SHA1", "HMACSHA256", "HMACSHA384", "HMACSHA512")]
    [string]$validationAlgorithm = 'HMACSHA256'
  )
  process {
    function BinaryToHex {
        [CmdLetBinding()]
        param($bytes)
        process {
            $builder = New-Object System.Text.StringBuilder
            foreach ($b in $bytes) {
              $builder = $builder.AppendFormat([System.Globalization.CultureInfo]::InvariantCulture, "{0:X2}", $b)
            }
            $builder
        }
    }
    switch ($decryptionAlgorithm) {
      "AES" { $decryptionObject = New-Object System.Security.Cryptography.AesCryptoServiceProvider }
      "DES" { $decryptionObject = New-Object System.Security.Cryptography.DESCryptoServiceProvider }
      "3DES" { $decryptionObject = New-Object System.Security.Cryptography.TripleDESCryptoServiceProvider }
    }
    $decryptionObject.GenerateKey()
    $decryptionKey = BinaryToHex($decryptionObject.Key)
    $decryptionObject.Dispose()
    switch ($validationAlgorithm) {
      "MD5" { $validationObject = New-Object System.Security.Cryptography.HMACMD5 }
      "SHA1" { $validationObject = New-Object System.Security.Cryptography.HMACSHA1 }
      "HMACSHA256" { $validationObject = New-Object System.Security.Cryptography.HMACSHA256 }
      "HMACSHA385" { $validationObject = New-Object System.Security.Cryptography.HMACSHA384 }
      "HMACSHA512" { $validationObject = New-Object System.Security.Cryptography.HMACSHA512 }
    }
    $validationKey = BinaryToHex($validationObject.Key)
    $validationObject.Dispose()
    [string]::Format([System.Globalization.CultureInfo]::InvariantCulture,
      "<machineKey decryption=`"{0}`" decryptionKey=`"{1}`" validation=`"{2}`" validationKey=`"{3}`" />",
      $decryptionAlgorithm.ToUpperInvariant(), $decryptionKey,
      $validationAlgorithm.ToUpperInvariant(), $validationKey)
  }
}


# ASP.NET 4.0 applications, just call Generate-MachineKey without parameters to generate a <machineKey> element:
Generate-MachineKey

# ASP.NET 2.0 and 3.5 applications do not support HMACSHA256. Instead, specify SHA1 to generate a compatible <machineKey> element:
Generate-MachineKey -validation SHA1
