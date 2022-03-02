param([int]$MaximunMinutes = 10)

function ConvertFrom-TsIdleTime {
    param([string]$TsIdleTime)

    $dt = [datetime]::MinValue
    $pattern = '^(?<Days>\d*)\+?(?<Hours>\d*):?(?<Minutes>\d*)$'
    $match = [regex]::Match($TsIdleTime, $pattern, [System.Text.RegularExpressions.RegexOptions]::RightToLeft)

    if($match.Success) {
        if($match.Captures.Groups[1].Success) {
                $dt = $dt.AddDays($match.Captures.Groups[1].Value)
        }

        if($match.Captures.Groups[2].Success) {
                $dt = $dt.AddHours($match.Captures.Groups[2].Value)
        }

        if($match.Captures.Groups[3].Success) {
                $dt = $dt.AddMinutes($match.Captures.Groups[3].Value)
        }
    }
    ($dt - [datetime]::MinValue).TotalMinutes
}

$EventLogSource = 'LogoffIdleUsers'
New-EventLog -LogName Application -Source $EventLogSource -ErrorAction SilentlyContinue

$sessions = (query.exe user | Select-Object -Skip 1) -replace '\s{2,}', ',' | 
    ConvertFrom-Csv -Header UserName,SessionName,ID,State,IdleTime,LogonTime |
        Select-Object UserName, SessionName, ID, State, LogonTime, IdleTime,
            @{N='IdleTimeInMinutes';E={(ConvertFrom-TsIdleTime -TsIdleTime $_.IdleTime)}}

$sessions | Where-Object { $MaximunMinutes -le $_.IdleTimeInMinutes } | ForEach-Object {
    $result = logoff.exe $_.ID /v
    $params = @{
        LogName = 'Application'
        Source = $EventLogSource
        EntryType = 'Information'
        EventId = 0
        Message = "{0} (User '{1}' was idle for {2} minutes [{3}])" -f `
            $result, $_.UserName, $_.IdleTimeInMinutes, $_.IdleTime
    }
    Write-EventLog @params
    $params.Message
}

