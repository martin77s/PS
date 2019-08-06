
function Get-WSManSession {

    [CmdletBinding()] 

    param(
        [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position=0)] 
        [Alias('CN','PSComputerName','__SERVER')]  
        [String[]]$ComputerName =  $env:COMPUTERNAME, 
 
        [PSCredential]$Credential
    )

    function ConvertFrom-ISO8601Duration {
    
        [CmdletBinding(SupportsShouldProcess=$false)]
        [OutputType([System.TimeSpan])]

        param(
            [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true)] 
            [Alias('ISO8601', 'String')] 
            [string]$Duration
        )

        $pattern = '^P?T?((?<Years>\d+)Y)?((?<Months>\d+)M)?((?<Weeks>\d+)W)?((?<Days>\d+)D)?(T((?<Hours>\d+)H)?((?<Minutes>\d+)M)?((?<Seconds>\d*(\.)?\d*)S)?)$'

        Write-Verbose -Message 'Matching the provided duration to the regular expression pattern'
        if($Duration -match $pattern) {

            $dt = [datetime]::MinValue
            if ($Matches.Seconds) { $dt = $dt.AddSeconds($Matches.Seconds) }
            if ($Matches.Minutes) { $dt = $dt.AddMinutes($Matches.Minutes) }
            if ($Matches.Hours)   { $dt = $dt.AddHours($Matches.Hours) }
            if ($Matches.Days)    { $dt = $dt.AddDays($Matches.Days) }
            if ($Matches.Weeks)   { $dt = $dt.AddDays(7*$Matches.Weeks) }
            if ($Matches.Months)  { $dt = $dt.AddMonths($Matches.Months) }
            if ($Matches.Years)   { $dt = $dt.AddYears($Matches.Years) }
            $dt - [datetime]::MinValue
    
        } else {
            Write-Warning 'The provided string does not match the ISO 8601 duration format'
        }

    <#
    .SYNOPSIS
        The ConvertFrom-ISO8601Duration can be used to convert a duration string in the ISO 8601 format to a Timespan object.

    .DESCRIPTION
        The ConvertFrom-ISO8601Duration uses a regular expression pattern to extract the date and time parts from the duration stirng the ISO 8601 format, 
        and uses those extracted parts to create an quivalent Timespan object that represents the same period of time duration.
        More information on the ISO 8601 format can be found at http://www.iso.org/iso/home/standards/iso8601.htm
        More information on the duration format can be found at https://en.wikipedia.org/wiki/ISO_8601#Durations

    .INPUTS
        [string]

    .OUTPUTS
        [System.TimeSpan]


    .NOTES
        Author : Martin Schvartzman, martin.schvartzman@microsoft.com 
        Blog   : http://aka.ms/pstips

    .PARAMETER Duration  
        Specifies the duration in the ISO 8601 format you want to convert to a Timespan object

    .EXAMPLE
        ConvertFrom-ISO8601Duration -Duration PT7200.000S

        Days              : 0
        Hours             : 2
        Minutes           : 0
        Seconds           : 0
        Milliseconds      : 0
        Ticks             : 72000000000
        TotalDays         : 0.0833333333333333
        TotalHours        : 2
        TotalMinutes      : 120
        TotalSeconds      : 7200
        TotalMilliseconds : 7200000


    .EXAMPLE
        'P3Y6M4DT12H30M5S' | ConvertFrom-ISO8601Duration

        Days              : 1281
        Hours             : 12
        Minutes           : 30
        Seconds           : 5
        Milliseconds      : 0
        Ticks             : 1107234050000000
        TotalDays         : 1281.5208912037
        TotalHours        : 30756.5013888889
        TotalMinutes      : 1845390.08333333
        TotalSeconds      : 110723405
        TotalMilliseconds : 110723405000

    .EXAMPLE
        (ConvertFrom-ISO8601Duration -ISO8601 P0DT12H30M45S).ToString()

        12:30:45

    #>
    }


    $ComputerName | ForEach-Object { 
        $params = @{ 
            ResourceURI   = 'shell' 
            Enumerate     =  $true 
            ConnectionURI = ("http://{0}:5985/wsman" -f $_) 
            ComputerName  = ($_)  
        }
        if ($PSBoundParameters.ContainsKey("Credential")) { $params['Credential'] = $Credential } 
        Get-WSManInstance @params |
            Select-Object Name, Owner, ClientIP, ProcessID, State, MemoryUsed, ChildProcesses, 
                @{N='ShellRunTime'; E={ConvertFrom-ISO8601Duration -Duration $_.ShellRunTime}},
                @{N='ShellInactivity'; E={ConvertFrom-ISO8601Duration -Duration $_.ShellInactivity}}, 
                @{N='IdleTimeOut'; E={ConvertFrom-ISO8601Duration -Duration $_.IdleTimeOut}}
    }
}

#$cred = Get-Credential CONTOSO\Administrator
$servers = '10.10.10.201','10.10.10.101'
Get-WSManSession -ComputerName $servers -Credential $cred