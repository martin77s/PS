#region Helper functions
function Set-Ownership {
    [CmdletBinding(SupportsShouldProcess = $false)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()] [ValidatePattern('(\w+)\\(\w+)')]
        [string]$Identity,

        [Parameter(Mandatory = $false)]
        [switch]$AddFullControl,

        [Parameter(Mandatory = $false)]
        [switch]$Recurse
    )

    begin {
        $tokenManipulate = @'
        using System;
        using System.Runtime.InteropServices;

        public class TokenManipulate {

            [DllImport("kernel32.dll", ExactSpelling = true)]
            internal static extern IntPtr GetCurrentProcess();

            [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
            internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);

            [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
            internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);

            [DllImport("advapi32.dll", SetLastError = true)]
            internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);

            [StructLayout(LayoutKind.Sequential, Pack = 1)]
            internal struct TokPriv1Luid {
                public int Count;
                public long Luid;
                public int Attr;
            }

            internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
            internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
            internal const int TOKEN_QUERY = 0x00000008;
            internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;

            public static bool AddPrivilege(string privilege) {
                bool retVal;
                TokPriv1Luid tp;
                IntPtr hproc = GetCurrentProcess();
                IntPtr htok = IntPtr.Zero;
                retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
                tp.Count = 1;
                tp.Luid = 0;
                tp.Attr = SE_PRIVILEGE_ENABLED;
                retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
                retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
                return retVal;
            }

            public static bool RemovePrivilege(string privilege) {
                bool retVal;
                TokPriv1Luid tp;
                IntPtr hproc = GetCurrentProcess();
                IntPtr htok = IntPtr.Zero;
                retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
                tp.Count = 1;
                tp.Luid = 0;
                tp.Attr = SE_PRIVILEGE_DISABLED;
                retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
                retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
                return retVal;
            }
        }
'@
    }

    Process {

        Add-Type -TypeDefinition $TokenManipulate
        [void][TokenManipulate]::AddPrivilege('SeTakeOwnershipPrivilege')
        [void][TokenManipulate]::AddPrivilege('SeRestorePrivilege')

        $item = Get-Item -Path $Path
        $owner = New-Object System.Security.Principal.NTAccount -ArgumentList ($Identity -split '\\')

        if ($item.PSIsContainer) {
            switch ($item.PSProvider.Name) {
                'FileSystem' {
                    $acl = New-Object -TypeName System.Security.AccessControl.DirectorySecurity
                }
                'Registry' {
                    $acl = New-Object -TypeName System.Security.AccessControl.RegistrySecurity
                    switch (($item.Name -split '\\')[0]) {
                        'HKEY_CLASSES_ROOT' { $rootKey = [Microsoft.Win32.Registry]::ClassesRoot; break }
                        'HKEY_LOCAL_MACHINE' { $rootKey = [Microsoft.Win32.Registry]::LocalMachine; break }
                        'HKEY_CURRENT_USER' { $rootKey = [Microsoft.Win32.Registry]::CurrentUser; break }
                        'HKEY_USERS' { $rootKey = [Microsoft.Win32.Registry]::Users; break }
                        'HKEY_CURRENT_CONFIG' { $rootKey = [Microsoft.Win32.Registry]::CurrentConfig; break }
                    }
                    $key = $item.Name -replace "$rootKey\\"
                    $item = $rootKey.OpenSubKey($Key, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
                        [System.Security.AccessControl.RegistryRights]::TakeOwnership)
                }
            }

            Write-Verbose "Setting ownership for $($owner.Value) on $Path"
            $acl.SetOwner($owner)
            $item.SetAccessControl($acl)

            if($AddFullControl) {
                $ace = New-Object -TypeName System.Security.AccessControl.RegistryAccessRule -ArgumentList @(
                    $owner, [System.Security.AccessControl.RegistryRights]::FullControl,
                    [System.Security.AccessControl.InheritanceFlags]::None,
                    [System.Security.AccessControl.PropagationFlags]::None,
                    [System.Security.AccessControl.AccessControlType]::Allow
                )
                Write-Verbose "Setting FullControl permissions for $($owner.Value) on $Path"
                $acl.AddAccessRule($ace)
                $item.SetAccessControl($acl)
            }

            if ($item.PSProvider.Name -eq 'Registry') { $item.Close() }

            if ($Recurse.IsPresent) {
                if ($item.PSProvider.Name -eq 'Registry') {
                    $items = @(Get-ChildItem -Path $Path -Recurse -Force | Where-Object { $_.PSIsContainer })
                }
                else {
                    $items = @(Get-ChildItem -Path $Path -Recurse -Force)
                }

                for ($i = 0; $i -lt $items.Count; $i++) {
                    switch ($item.PSProvider.Name) {

                        'FileSystem' {
                            $item = Get-Item $items[$i].FullName
                            if ($item.PSIsContainer) { $acl = New-Object -TypeName System.Security.AccessControl.DirectorySecurity }
                            else { $acl = New-Object -TypeName System.Security.AccessControl.FileSecurity }
                        }

                        'Registry' {
                            $item = Get-Item $items[$i].PSPath
                            $acl = New-Object -TypeName System.Security.AccessControl.RegistrySecurity
                            switch ($item.Name.Split('\')[0]) {
                                'HKEY_CLASSES_ROOT' { $rootKey = [Microsoft.Win32.Registry]::ClassesRoot; break }
                                'HKEY_LOCAL_MACHINE' { $rootKey = [Microsoft.Win32.Registry]::LocalMachine; break }
                                'HKEY_CURRENT_USER' { $rootKey = [Microsoft.Win32.Registry]::CurrentUser; break }
                                'HKEY_USERS' { $rootKey = [Microsoft.Win32.Registry]::Users; break }
                                'HKEY_CURRENT_CONFIG' { $rootKey = [Microsoft.Win32.Registry]::CurrentConfig; break }
                            }
                            $Key = $item.Name.Replace(($item.Name.Split('\')[0] + '\'), '')
                            $item = $rootKey.OpenSubKey($Key, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
                                [System.Security.AccessControl.RegistryRights]::TakeOwnership)
                        }
                    }
                    $acl.SetOwner($owner)
                    Write-Verbose "Setting ownership for $($owner.Value) on $($item.Name)"
                    $item.SetAccessControl($acl)
                    if ($item.PSProvider.Name -eq 'Registry') { $item.Close() }
                }
            }
        }
        else {
            if ($Recurse.IsPresent) { Write-Warning 'Object specified is neither a folder nor a registry key.  Recursion is not possible.' }
            switch ($item.PSProvider.Name) {
                'FileSystem' { $acl = New-Object -TypeName System.Security.AccessControl.FileSecurity }
                'Registry' { throw 'You cannot set ownership on a registry value'  }
                default { throw "Unknown provider:  $($item.PSProvider.Name)" }
            }
            $acl.SetOwner($owner)
            Write-Verbose "Setting ownership for $($owner.Value) on $Path"
            $item.SetAccessControl($acl)
        }
    }
}
#endregion

#region Test FileSystemObject ComObject (Should work)
(New-Object -ComObject Scripting.FileSystemObject).Drives
#endregion

#region Set ownership and add permissions to the relevant registry keys
$regPath = 'Registry::HKEY_CLASSES_ROOT\TypeLib\{420B2830-E718-11CF-893D-00A0C9054228}\1.0\0\win32'
Set-Ownership -Path $regPath -Identity 'BUILTIN\Administrators' -AddFullControl -Recurse -Verbose

$regPath = 'Registry::HKEY_CLASSES_ROOT\Scripting.FileSystemObject\CLSID'
Set-Ownership -Path $regPath -Identity 'BUILTIN\Administrators' -AddFullControl -Recurse -Verbose
#endregion

#region unregister the FileSystemObject scrrun dll
C:\Windows\System32\regsvr32.exe /u /s scrrun.dll
#endregion

#region Test FileSystemObject ComObject (Should fail)
(New-Object -ComObject Scripting.FileSystemObject).Drives
#endregion
