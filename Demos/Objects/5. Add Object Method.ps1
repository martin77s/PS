break

$myTypeData = @{
    TypeName   = 'System.Array'
    MemberType = 'ScriptMethod'
    MemberName = 'Sum'
    Value      = {
        $total = $null
        foreach ($i in $this) {
            $total += $i
        }
        $total
    }
}
Update-TypeData @myTypeData -Force

$a = 1..10
$a.Sum()
