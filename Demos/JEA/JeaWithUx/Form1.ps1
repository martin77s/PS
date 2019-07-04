
$cred = Get-Credential CONTOSO\DnsOperator
$RemoteServer = 'DC1'

$btnRemoteCmd_Click = {
	$txtResults.Text = 'Running: ' + $txtRemoteCmd.Text
	$res = Invoke-Command -ComputerName $txtComputerName.Text -ConfigurationName $txtJeaEP.Text -ScriptBlock ([scriptblock]::Create($txtRemoteCmd.Text)) -Credential $cred -ErrorVariable ev
    if($?) { $txtResults.Text = $res | Format-Table -AutoSize | Out-String -Width 100
    } else { $txtResults.Text = $ev | Format-Table -AutoSize | Out-String -Width 100 }
}

$btnWhoRemote_Click = {
	$txtWhoRemote.Text = (Invoke-Command -ComputerName $txtComputerName.Text -ConfigurationName $txtJeaEP.Text -ScriptBlock { Get-WhoAmI } -Credential $cred -ErrorVariable ev).RunningAs
    if(!$?) { $txtResults.Text = $ev | Format-Table -AutoSize | Out-String -Width 100 }
}

$btnWhoLocal_Click = {
	$txtWhoLocal.Text = whoami.exe
}

$btnExit_Click = {
	$MainForm.Close()
}


. (Join-Path $PSScriptRoot 'Form1.designer.ps1')
$MainForm.ShowDialog()