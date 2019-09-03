#requires -version 3
function Remove-Profile {
    param(
        [string[]]$ComputerName = $env:ComputerName,
        [pscredential]$Credential = $null,
        [string[]]$Name,
        [ValidateRange(0,365)][int]$DaysOld = 0,
        [string[]]$Exclude,
        [switch]$IgnoreLastUseTime,
        [switch]$Remove
    )

    $ComputerName | ForEach-Object {
    
        if(Test-Connection -ComputerName $_ -BufferSize 16 -Count 2 -Quiet) {
        
            $params = @{
                ComputerName = $_ 
                Namespace    = 'root\cimv2'
                Class        = 'Win32_UserProfile'
            }

            if($Credential -and (@($env:ComputerName,'localhost','127.0.0.1','::1','.') -notcontains $_)) { 
                $params.Add('Credential', $Credential) 
            }

            if($null -ne $Name) {
                if($Name.Count -gt 1) {
                    $params.Add('Filter', ($Name | % { "LocalPath = '{0}'" -f $_ }) -join ' OR ')
                } else {
                    $params.Add('Filter', "LocalPath LIKE '%{0}'" -f ($Name -replace '\*', '%'))
                }
            }

            Get-WmiObject @params | ForEach-Object {

                $WouldBeRemoved = $false
                if(($_.SID -notin @('S-1-5-18', 'S-1-5-19', 'S-1-5-20')) -and 
                    ((Split-Path -Path $_.LocalPath -Leaf) -notin $Exclude) -and (-not $_.Loaded) -and ($IgnoreLastUseTime -or (
                        ($_.LastUseTime) -and (([WMI]'').ConvertToDateTime($_.LastUseTime)) -lt (Get-Date).AddDays(-1*$DaysOld)))) {
                    $WouldBeRemoved = $true
                }

                $prf = [pscustomobject]@{
                    PSComputerName = $_.PSComputerName
                    Account = (New-Object System.Security.Principal.SecurityIdentifier($_.Sid)).Translate([System.Security.Principal.NTAccount]).Value
                    LocalPath = $_.LocalPath
                    LastUseTime = if($_.LastUseTime) { ([WMI]'').ConvertToDateTime($_.LastUseTime) } else { $null }
                    Loaded = $_.Loaded
                }

                if(-not $Remove) {
                    $prf | Select-Object -Property *, @{N='WouldBeRemoved'; E={$WouldBeRemoved}}
                }

                if($Remove -and $WouldBeRemoved) { 
                    try {
                        $_.Delete()
                        $Removed = $true
                    } catch {
                        $Removed = $false
                        Write-Error -Exception $_
                    }
                    finally {
                        $prf | Select-Object -Property *, @{N='Removed'; E={$Removed}}
                    }
                }
            }

        } else {
            Write-Warning -Message "Computer $_ is unavailable"
        }
    }
}
