[void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
[void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
$MainForm = New-Object -TypeName System.Windows.Forms.Form
[System.Windows.Forms.Label]$label1 = $null
[System.Windows.Forms.Label]$label2 = $null
[System.Windows.Forms.Label]$label3 = $null
[System.Windows.Forms.TextBox]$txtWhoLocal = $null
[System.Windows.Forms.TextBox]$txtWhoRemote = $null
[System.Windows.Forms.TextBox]$txtRemoteCmd = $null
[System.Windows.Forms.Button]$btnWhoLocal = $null
[System.Windows.Forms.Button]$btnWhoRemote = $null
[System.Windows.Forms.Button]$btnRemoteCmd = $null
[System.Windows.Forms.TextBox]$txtResults = $null
[System.Windows.Forms.Button]$btnExit = $null
[System.Windows.Forms.GroupBox]$groupBox1 = $null
[System.Windows.Forms.TextBox]$txtJeaEp = $null
[System.Windows.Forms.Label]$label5 = $null
[System.Windows.Forms.TextBox]$txtComputerName = $null
[System.Windows.Forms.Label]$label4 = $null
[System.Windows.Forms.Button]$button1 = $null
function InitializeComponent
{
$label1 = New-Object -TypeName System.Windows.Forms.Label
$txtWhoLocal = New-Object -TypeName System.Windows.Forms.TextBox
$label2 = New-Object -TypeName System.Windows.Forms.Label
$txtWhoRemote = New-Object -TypeName System.Windows.Forms.TextBox
$label3 = New-Object -TypeName System.Windows.Forms.Label
$txtRemoteCmd = New-Object -TypeName System.Windows.Forms.TextBox
$btnWhoLocal = New-Object -TypeName System.Windows.Forms.Button
$btnWhoRemote = New-Object -TypeName System.Windows.Forms.Button
$btnRemoteCmd = New-Object -TypeName System.Windows.Forms.Button
$txtResults = New-Object -TypeName System.Windows.Forms.TextBox
$btnExit = New-Object -TypeName System.Windows.Forms.Button
$groupBox1 = New-Object -TypeName System.Windows.Forms.GroupBox
$txtJeaEp = New-Object -TypeName System.Windows.Forms.TextBox
$label5 = New-Object -TypeName System.Windows.Forms.Label
$txtComputerName = New-Object -TypeName System.Windows.Forms.TextBox
$label4 = New-Object -TypeName System.Windows.Forms.Label
$groupBox1.SuspendLayout()
$MainForm.SuspendLayout()
#
#label1
#
$label1.AutoSize = $true
$label1.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(220,15)
$label1.Name = 'label1'
$label1.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(71,13)
$label1.TabIndex = 0
$label1.Text = 'whoami local:'
#
#txtWhoLocal
#
$txtWhoLocal.Enabled = $false
$txtWhoLocal.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(223,31)
$txtWhoLocal.Name = 'txtWhoLocal'
$txtWhoLocal.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(347,20)
$txtWhoLocal.TabIndex = 1
#
#label2
#
$label2.AutoSize = $true
$label2.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(223,77)
$label2.Name = 'label2'
$label2.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(81,13)
$label2.TabIndex = 2
$label2.Text = 'whoami remote:'
#
#txtWhoRemote
#
$txtWhoRemote.Enabled = $false
$txtWhoRemote.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(223,94)
$txtWhoRemote.Name = 'txtWhoRemote'
$txtWhoRemote.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(347,20)
$txtWhoRemote.TabIndex = 1
#
#label3
#
$label3.AutoSize = $true
$label3.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(220,141)
$label3.Name = 'label3'
$label3.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(96,13)
$label3.TabIndex = 2
$label3.Text = 'Remote command:'
#
#txtRemoteCmd
#
$txtRemoteCmd.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(223,159)
$txtRemoteCmd.Name = 'txtRemoteCmd'
$txtRemoteCmd.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(347,20)
$txtRemoteCmd.TabIndex = 1
#
#btnWhoLocal
#
$btnWhoLocal.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(576,31)
$btnWhoLocal.Name = 'btnWhoLocal'
$btnWhoLocal.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,20)
$btnWhoLocal.TabIndex = 3
$btnWhoLocal.Text = 'Invoke'
$btnWhoLocal.UseVisualStyleBackColor = $true
$btnWhoLocal.add_Click($btnWhoLocal_Click)
#
#btnWhoRemote
#
$btnWhoRemote.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(576,94)
$btnWhoRemote.Name = 'btnWhoRemote'
$btnWhoRemote.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,20)
$btnWhoRemote.TabIndex = 3
$btnWhoRemote.Text = 'Invoke'
$btnWhoRemote.UseVisualStyleBackColor = $true
$btnWhoRemote.add_Click($btnWhoRemote_Click)
#
#btnRemoteCmd
#
$btnRemoteCmd.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(576,159)
$btnRemoteCmd.Name = 'btnRemoteCmd'
$btnRemoteCmd.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,20)
$btnRemoteCmd.TabIndex = 3
$btnRemoteCmd.Text = 'Invoke'
$btnRemoteCmd.UseVisualStyleBackColor = $true
$btnRemoteCmd.add_Click($btnRemoteCmd_Click)
#
#txtResults
#
$txtResults.Anchor = 15
$txtResults.Font = New-Object -TypeName System.Drawing.Font -ArgumentList @('Consolas',8.25,[System.Drawing.FontStyle]::Regular)
$txtResults.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(12,200)
$txtResults.Multiline = $true
$txtResults.Name = 'txtResults'
$txtResults.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
$txtResults.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(661,206)
$txtResults.TabIndex = 4
$txtResults.Text = "Loaded credentials for: $($cred.UserName)"
#
#btnExit
#
$btnExit.Anchor = 6
$btnExit.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(12,423)
$btnExit.Name = 'btnExit'
$btnExit.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(75,23)
$btnExit.TabIndex = 5
$btnExit.Text = 'Exit'
$btnExit.UseVisualStyleBackColor = $true
$btnExit.add_Click($btnExit_Click)
#
#groupBox1
#
$groupBox1.Controls.Add($txtJeaEp)
$groupBox1.Controls.Add($label5)
$groupBox1.Controls.Add($txtComputerName)
$groupBox1.Controls.Add($label4)
$groupBox1.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(12,12)
$groupBox1.Name = 'groupBox1'
$groupBox1.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(194,164)
$groupBox1.TabIndex = 6
$groupBox1.TabStop = $false
$groupBox1.Text = ' Settings '
#
#txtJeaEp
#
$txtJeaEp.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(25,115)
$txtJeaEp.Name = 'txtJeaEp'
$txtJeaEp.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(141,20)
$txtJeaEp.TabIndex = 1
$txtJeaEp.Text = 'JEA_DNS' # microsoft.powershell'
#
#label5
#
$label5.AutoSize = $true
$label5.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(22,99)
$label5.Name = 'label5'
$label5.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(105,13)
$label5.TabIndex = 0
$label5.Text = 'JEA Endpoint Name:'
#
#txtComputerName
#
$txtComputerName.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(25,44)
$txtComputerName.Name = 'txtComputerName'
$txtComputerName.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(141,20)
$txtComputerName.TabIndex = 1
$txtComputerName.Text = $RemoteServer
#
#label4
#
$label4.AutoSize = $true
$label4.Location = New-Object -TypeName System.Drawing.Point -ArgumentList @(22,28)
$label4.Name = 'label4'
$label4.Size = New-Object -TypeName System.Drawing.Size -ArgumentList @(126,13)
$label4.TabIndex = 0
$label4.Text = 'Remote Computer Name:'
#
#MainForm
#
$MainForm.ClientSize = New-Object -TypeName System.Drawing.Size -ArgumentList @(685,458)
$MainForm.Controls.Add($groupBox1)
$MainForm.Controls.Add($btnExit)
$MainForm.Controls.Add($txtResults)
$MainForm.Controls.Add($btnRemoteCmd)
$MainForm.Controls.Add($btnWhoRemote)
$MainForm.Controls.Add($btnWhoLocal)
$MainForm.Controls.Add($label3)
$MainForm.Controls.Add($label2)
$MainForm.Controls.Add($txtRemoteCmd)
$MainForm.Controls.Add($txtWhoRemote)
$MainForm.Controls.Add($txtWhoLocal)
$MainForm.Controls.Add($label1)
$MainForm.MaximizeBox = $false
$MainForm.Name = 'MainForm'
$MainForm.Text = 'JEA UI Demo'
$groupBox1.ResumeLayout($false)
$groupBox1.PerformLayout()
$MainForm.ResumeLayout($false)
$MainForm.PerformLayout()
}
. InitializeComponent
