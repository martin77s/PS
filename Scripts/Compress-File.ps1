function Compress-File {
    param (
        [string[]] $Path,
        [string] $Destination = $pwd.Path,
        [switch] $Force,
        [switch] $PassThru

    )

    function IsFileLocked {
        param([string]$Path)
        [bool] $isFileLocked = $true
        $file = $null
        try {
            $file = [IO.File]::Open(
                $Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None
            )
            $isFileLocked = $false
        }
        catch [IO.IOException] {
            if ($_.Exception.Message -notmatch 'used by another process') {
                throw $_.Exception
            }
        }
        finally {
            if ($file -ne $null) {
                $file.Close()
            }
        }
        $isFileLocked
    }

    if (-not $Destination.EndsWith('.zip')) {
        $Destination = Join-Path -Path $Destination -ChildPath 'archive.zip'
    }

    if(-not $Force -and (Test-Path -Path $Destination -PathType Leaf)) {
        throw 'Target zip already exists!'
    }
    else {
        Set-Content -Path $Destination -Value ('PK' + [char]5 + [char]6 + ("$([char]0)" * 18)) -Force
        $zipfile = Get-Item -Path $Destination
        $zipfile.IsReadOnly = $false

        $shellApp = New-Object -ComObject Shell.Application
        $zipPackage = $shellApp.NameSpace($zipfile.FullName)

        Get-Item -Path $Path | Select-Object -Unique | ForEach-Object {
            $zipPackage.CopyHere($_.FullName)
            do { Start-Sleep -Milliseconds 200 }
            while(IsFileLocked -Path $zipPackage.Self.Path)
        }

        If ($PassThru) {
            Get-Item -Path $zipPackage.Self.Path
        }
    }
}


# Example 1:
# Compress-File -Path C:\Temp\test.json -Destination C:\Temp\test.zip -Force -PassThru

# Example 2:
# $files = dir -Path C:\Temp\Logs | Select-Object -ExpandProperty FullName
# Compress-File -Path $files -Destination C:\Temp -Force -PassThru
