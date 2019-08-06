
#region Helper Functions

function Confirm-Value {
    [CmdletBinding()]
    param (  
        [String] $Path,
        [String] $Name,
        $NewValue
    )
    
    $existingValue = Get-Value -Path $Path -Name $Name
    if ($existingValue -ne $NewValue) {
        return $false
    }
    else {
        $relPath = $Path + '' + $Name
        Write-Verbose($LocalizedData.ValueOk -f $relPath,$NewValue);
        return $true
    }
}


function Set-Value {
    [CmdletBinding()]
    param (  
        [String] $Path,
        [String] $Name,
        [String] $NewValue
    )

    if ($Path -ne '') { $Path = '' + $Path }

    $params = @{
        PSPath = 'MACHINEWEBROOTAPPHOST'
        Filter = system.applicationHostapplicationPoolsapplicationPoolDefaults$Path
        Name   = $Name
        Value  = $NewValue
    }
                
    Set-WebConfigurationProperty @params

    $relPath = $Path + '' + $Name
    Write-Verbose($LocalizedData.SettingValue -f $relPath,$NewValue);
}


function Set-ValueInt {
    [CmdletBinding()]
    param (  
        [String] $Path,
        [String] $Name,
        [int] $NewValue
    )

    if ($Path -ne '') { $Path = '' + $Path }

    $params = @{
        PSPath = 'MACHINEWEBROOTAPPHOST'
        Filter = system.applicationHostapplicationPoolsapplicationPoolDefaults$Path
        Name   = $Name
        Value  = $NewValue
    }
                
    Set-WebConfigurationProperty @params

    $relPath = $Path + '' + $Name
    Write-Verbose($LocalizedData.SettingValue -f $relPath,$NewValue);
}


function Get-Value {

    [CmdletBinding()]
    param(  
        [String] $Path,
        [String] $Name
    )

    if ($Path -ne '') { $Path = '' + $Path }
    
    $params = @{
        PSPath = 'MACHINEWEBROOTAPPHOST' 
        Filter = system.applicationHostapplicationPoolsapplicationPoolDefaults$Path 
        Name   = $Name
    }
    return Get-WebConfigurationProperty @params
    
}


function Convert-TimeSpanToString ($TimeSpan) {
    $TimeSpan.ToString('d.hhmmss')
}


function Compare-LogEventOnRecycle {
    param($CurrentValue, $ExpectedValue)

    $CurrentValue = $CurrentValue | Sort-Object
    $ExpectedValue = $ExpectedValue | Sort-Object
    if(Compare-Object -ReferenceObject $CurrentValue -DifferenceObject $ExpectedValue) {
        return $false
    } else {
        return $true
    }
}

#endregion