break

Get-Date

Get-Date | fl

Update-TypeData -TypeName System.DateTime -DefaultDisplayPropertySet DateTime, DayfWeek, DayOfYear -Force
Get-Date | fl


function New-Person {
    param($FirstName = 'Moshe', $LastName = 'Cohen', $Company = 'Contoso', $Telephone = '09-8765-4321', $Id = ([guid]::NewGuid().guid))
    [PSCustomObject]@{
        Id         = $Id
        FirstName  = $FirstName
        LastName   = $LastName
        Company    = $Company
        Telephone  = $Telephone
        PSTypeName = 'myPerson'
    }
}
New-Person
New-Person -FirstName Yacov -LastName Levi -Company Fabrikam -Telephone 050-7654321
New-Person -FirstName Marco -LastName Polo -Company NWTraders -Telephone 04-65637281

Update-TypeData -TypeName myPerson -DefaultDisplayPropertySet Company, FirstName, LastName -Force
Remove-TypeData -TypeName myPerson
