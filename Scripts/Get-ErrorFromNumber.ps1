function Get-ErrorFromNumber {
	param($ErrorNumber)

    $err = [System.Runtime.InteropServices.Marshal]::GetExceptionForHR($ErrorNumber)
    if(-not $err) {
        $err = New-Object ComponentModel.Win32Exception $ErrorNumber
    }
    if(-not $err) {
         Write-Error "$ErrorNumber is not a known error code"
    } else {
        $err
    }

}; New-Alias -Name err -Value Get-ErrorFromNumber

