break


# Add "GetHelp" for objects
Update-TypeData -MemberType ScriptMethod -MemberName GetHelp -TypeName System.Object -Value {
    Start-Process ('http://msdn.microsoft.com/en-US/library/{0}' -f $this.GetType().FullName)
}


# Add encoded command to a scriptblock object
$splat = @{
    TypeName   = 'System.Management.Automation.ScriptBlock'
    MemberName = 'EncodedCommand'
    MemberType = 'ScriptProperty'
    Value      = { [convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($this.ToString())) }
    Force      = $true
}
Update-TypeData @splat


$a = { Get-Date }
$a.EncodedCommand