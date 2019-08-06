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
