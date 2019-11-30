PARAM(

    [Parameter(Mandatory=$true)]
    [ValidatePattern('\.reg$')]
    [string]$RegFile,
	
    [switch]$CurrentUser,
    [switch]$AllUsers,
    [switch]$DefaultProfile = $true
)

function Get-TempRegFilePath {
    (Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ([guid]::NewGuid().Guid)) + '.reg'
}


function Write-Registry {
    param($RegFileContents, $UserSid)
    
    $TempRegFile = Get-TempRegFilePath
    $regFileContents = $regFileContents -replace 'HKEY_CURRENT_USER', "HKEY_USERS\$userSid"
    $regFileContents | Out-File -FilePath $TempRegFile
    
    $p = Start-Process -FilePath C:\Windows\regedit.exe -ArgumentList @('/s', $TempRegFile) -PassThru
    do { Start-Sleep -Seconds 1 } while (-not $p.HasExited)
    
    Remove-Item -Path $TempRegFile -Force
}


function IsFileLocked {
    param([string]$Path)

    [bool] $isFileLocked = $true
    $file = $null

    try {
        $file = [IO.File]::Open(
            $Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None
        )
        $isFileLocked = $false
    } catch [IO.IOException] {
        if ($_.Exception.Message -notmatch 'used by another process') {
            throw $_.Exception
        }
    } finally {
        if ($null -ne $file) {
            $file.Close()
        }
    }
    $isFileLocked
}


function Write-RegistryWithHiveLoad {
    param($RegFileContents, $DatFilePath)
    
    $hiveName = 'x_' +  ($user = (($datFilePath -split '\\')[-2]).ToUpper())

    try {
        
        if(-not (IsFileLocked -Path $DatFilePath)) {
            $null = C:\Windows\System32\reg.exe load "HKU\$hiveName" $DatFilePath
            if($LASTEXITCODE -ne 0) { throw 'Error loading the DAT file' }
    
            $TempRegFile = Get-TempRegFilePath
            $regFileContents = $regFileContents -replace 'HKEY_CURRENT_USER', "HKEY_USERS\$hiveName"
            $regFileContents | Out-File -FilePath $TempRegFile

            $p = Start-Process -FilePath C:\Windows\regedit.exe -ArgumentList @('/s', $TempRegFile) -PassThru
            do { Start-Sleep -Seconds 1 } while (-not $p.HasExited)

            $null = C:\Windows\System32\reg.exe unload "HKU\$hiveName"

            Remove-Item -Path $TempRegFile -Force
        } else {
            Write-Verbose ('Skipped user {0}. File {1} is locked by another process' -f $user, $DatFilePath) -Verbose
        }
    } catch {
        Write-Verbose $_.Exception.Message -Verbose
    }
}


if (-not (Test-Path -Path $RegFile)) {
    throw "RegFile $RegFile doesn't exist. Aborted operation."
}
else {

    # Read the .reg file contents:
    $regFileContents = Get-Content -Path $RegFile -ReadCount 0

    # For the current logged on user only:
    if ($CurrentUser) {
        $explorers = Get-WmiObject -Namespace root\cimv2 -Class Win32_Process -Filter "Name='Explorer.exe'"
        $explorers | ForEach-Object {
            $owner = $_.GetOwner()
            if ($owner.ReturnValue -eq 0) {
                $user = "{0}\{1}" -f $owner.Domain, $owner.User
                $oUser = New-Object -TypeName System.Security.Principal.NTAccount($user)
                $sid = $oUser.Translate([System.Security.Principal.SecurityIdentifier]).Value
                Write-Verbose ('Writing registry values for current user: {0}' -f $user) -Verbose
                Write-Registry -RegFileContents $regFileContents -UserSid $sid
            }
        }
    }

    # For the default profile (future users):
    if ($DefaultProfile) {
        Write-Verbose ('Writing registry values for profile: DEFAULT') -Verbose
        Write-RegistryWithHiveLoad -RegFileContents $regFileContents -DatFilePath C:\Users\Default\NTUSER.DAT
    }

    # For all users that have profiles on the machine:
    if ($AllUsers) {
        $exclude = 'Public', 'Default'
        $profilesDirectory = (Get-ItemProperty -Path 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' -Name ProfilesDirectory).ProfilesDirectory
        dir -Path $profilesDirectory -Exclude $exclude | ForEach-Object {
            Write-Verbose ('Writing registry values for profile: {0}' -f $_.Name.ToUpper()) -Verbose
            $datFilePath = Join-Path -Path $_.FullName -ChildPath NTUSER.DAT
            Write-RegistryWithHiveLoad -RegFileContents $regFileContents -DatFilePath $datFilePath
        }
    }
}
