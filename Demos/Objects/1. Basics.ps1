break

# Basics
$a = 1
$b = "string"
$c = Get-Date
$d = Get-Process
$e = Get-WmiObject -Class Win32_BIOS

$a
$b
$c
$d
$e.



# Daily usage
Get-Service wi* | Select-Object Status, DisplayName
Get-Service wi* | Where-Object { $_.Status -eq 'Stopped' }


# Types
(1).GetType()
("Martin").GetType()


# Sorting with types
1, 5, 2, 31, 6, 3, 12, 46 | Sort-Object

'1a', '25', '3a', '12', '6' | Sort-Object -Property { "0x$_" -as [int] }

'1.2.3.4', '10.1.2.3', '100.4.2.1', '2.3.4.5' , '9.10.11.12' |
    Sort-Object -Property { [version] $_ }


# Properties vs. methods
$s = Get-Service BITS
$s | Format-List
$s | Get-Member


# Container vs. item
$p = Get-Process
$p | Get-Member
Get-Member -InputObject $p


# Sometime you gotta use methods
$dueDate = Get-Date
$dueDate.AddDays(7)



# Overloads
$p = Start-Process -FilePath notepad.exe -PassThru
$p.WaitForExit


# Getting members view
$p | Get-Member -View Base
$p | Get-Member -View Extended



# Serializing and Deserializing
$bits1 = Get-Service BITS
$bits1 | Export-Clixml -Path C:\Temp\bits.xml
notepad C:\Temp\bits.xml

$bits2 = Import-Clixml -Path C:\Temp\bits.xml
$bits2

$bits1.GetType()
$bits2.GetType()

$bits1 | Get-Member -MemberType Method
$bits2 | Get-Member -MemberType Method