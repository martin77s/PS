Import-Module -Name "$PSScriptRoot\..\..\Helpers\AppDefaultsHelper.psm1"


function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [parameter(Mandatory = $true)]
        [ValidateSet("Machine")]
        [System.String]
        $ApplyTo
    )

    Write-Verbose 'Getting ApplicationPoolDefaults settings'


    $returnValue = @{
        QueueLength = (Get-Value -Name queueLength).Value
        MaxProcesses = (Get-Value -Name maxProcesses -Path processModel).Value
        LogEventOnRecycle = (Get-Value -Name logEventOnRecycle -Path recycling)
        IdleTimeout = ((Get-Value -Name idleTimeout -Path processModel).Value).TotalMinutes
        PeriodicRecycleTime = ((Get-Value -Name time -Path recycling/PeriodicRestart).Value).TotalMinutes
    }

    $returnValue
}


function Set-TargetResource {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [ValidateSet("Machine")]
        [System.String]
        $ApplyTo,

        [System.UInt16]
        $QueueLength,

        [System.UInt16]
        $MaxProcesses,

        [ValidateSet("Time","Requests","Schedule","Memory","IsapiUnhealthy","OnDemand","ConfigChange","PrivateMemory")]
        [System.String[]]
        $LogEventOnRecycle,

        [System.String]
        $IdleTimeout,
        
        [System.String]
        $PeriodicRecycleTime
    )

    Write-Verbose 'Setting ApplicationPoolDefaults settings'
    
    if($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('QueueLength')) {
        Set-ValueInt -Name queueLength -NewValue $QueueLength
    }

    if($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('MaxProcesses')) {
        Set-ValueInt -Name maxProcesses -Path processModel -NewValue $MaxProcesses
    }
    
    if($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('LogEventOnRecycle')) {
        Set-Value -Name logEventOnRecycle -Path recycling -NewValue ($LogEventOnRecycle -join ',')
    }

    if($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('IdleTimeout')) {
        Set-Value -Name idleTimeout -Path processModel -NewValue (Convert-TimeSpanToString -TimeSpan (New-TimeSpan -Minutes $IdleTimeout))
    }

    if($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('PeriodicRecycleTime')) {
        Set-Value -Name time -Path recycling/PeriodicRestart -NewValue (Convert-TimeSpanToString -TimeSpan (New-TimeSpan -Minutes $PeriodicRecycleTime))
    }
}


function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [parameter(Mandatory = $true)]
        [ValidateSet("Machine")]
        [System.String]
        $ApplyTo,

        [System.UInt16]
        $QueueLength,

        [System.UInt16]
        $MaxProcesses,

        [ValidateSet("Time","Requests","Schedule","Memory","IsapiUnhealthy","OnDemand","ConfigChange","PrivateMemory")]
        [System.String[]]
        $LogEventOnRecycle,

        [System.String]
        $IdleTimeout,
        
        [System.String]
        $PeriodicRecycleTime
    )

    Write-Verbose "Confirming ApplicationPoolDefaults"

    if($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('queueLength')) {
        if(-not (Confirm-Value -Name queueLength -NewValue $QueueLength -Verbose)) {
            return $false
        }
    }
    
    if($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('maxProcesses')) {
        if(-not(Confirm-Value -Name maxProcesses -Path processModel -NewValue $MaxProcesses)) {
            return $false
        }
    }

    if($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('idleTimeout')) {
        if(-not(Confirm-Value -Name idleTimeout -Path processModel -NewValue (New-TimeSpan -Minutes $IdleTimeout))) {
            return $false
        }
    }
    if($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('logEventOnRecycle')) {
        $currentLogEventOnRecycle = (Get-Value -Name logEventOnRecycle -Path recycling) -split ','
        if(-not(Compare-LogEventOnRecycle -CurrentValue $currentLogEventOnRecycle -ExpectedValue $LogEventOnRecycle)) {
            return $false
        }
    }

    if($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('PeriodicRecycleTime')) {
        if(-not(Confirm-Value -Name time -Path recycling/PeriodicRestart -NewValue (New-TimeSpan -Minutes $PeriodicRecycleTime))) {
            return $false
        }
    }

    return $true
}


Export-ModuleMember -Function *-TargetResource
