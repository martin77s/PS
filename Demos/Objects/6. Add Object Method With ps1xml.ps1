break

$str = "Hello World"
$str | Get-Member
$str | Get-Member -View Extended

@'
<Types>
	<Type>
		<Name>System.String</Name>
		<Members>
			<ScriptMethod>
				<Name>Marco</Name>
					<Script>
						Write-Host "Polo"
					</Script>
			</ScriptMethod>
			<ScriptMethod>
				<Name>ToASCII</Name>
				<Script>
					for ($i=0;$i -le $this.length;$i++) {
						Write-Host "$([int]$($this[$i])) " -NoNewLine
					}
					Write-Host ""
				</Script>
			</ScriptMethod>
			<ScriptMethod>
				<Name>ToASCII2</Name>
				<Script>
					0..$this.length | % {
						Write-Host "$(('{0:x}' -f [int]$($this[$_])).ToUpper()) " -NoNewLine
					}
					Write-Host ""
				</Script>
			</ScriptMethod>
			<ScriptMethod>
				<Name>ToCrazyCase</Name>
				<Script>
				    0..$($this.Length-1) | % {
				        if ($_ % 2 -eq 0) {
				            Write-Host "$($this[$_].ToString().ToLower())" -NoNewLine}
				        else { Write-Host "$($this[$_].ToString().ToUpper())" -NoNewLine } }
					Write-Host "`n"
				</Script>
			</ScriptMethod>
		</Members>
	</Type>
</Types>
'@ | Out-File .\myTypes.ps1xml
Update-TypeData -AppendPath .\myTypes.ps1xml


$str | Get-Member -View Extended

$str.Marco()
$str.ToASCII()
$str.ToASCII2()
$str.ToCrazyCase()