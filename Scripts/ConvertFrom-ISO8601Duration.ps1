
function ConvertFrom-ISO8601Duration {
    [CmdletBinding(SupportsShouldProcess = $false)]
    [OutputType([System.TimeSpan])]

    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true)]
        [Alias('ISO8601', 'String')]
        [string]$Duration
    )

    [System.Xml.XmlConvert]::ToTimeSpan($Duration.ToUpper())


    <#
.SYNOPSIS
    The ConvertFrom-ISO8601Duration can be used to convert a duration string in the ISO 8601 format to a timespan object.

.DESCRIPTION
    The ConvertFrom-ISO8601Duration uses the ToTimeSpan() static method in the System.Xml.XmlConvert to read the duration string the ISO 8601 format and convert it to a timespan object.
    More information on the ISO 8601 format can be found at http://www.iso.org/iso/home/standards/iso8601.htm
    More information on the duration format can be found at https://en.wikipedia.org/wiki/ISO_8601#Durations

.INPUTS
    [System.String]

.OUTPUTS
    [System.TimeSpan]


.NOTES
    Author : Martin Schvartzman, martin.schvartzman@microsoft.com
    Blog   : http://aka.ms/pstips

.PARAMETER Duration
    Specifies the duration in the ISO 8601 format you want to convert to a timespan object

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


function ConvertTo-ISO8601Duration {
    [CmdletBinding(SupportsShouldProcess = $false)]
    [OutputType([System.String])]

    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true)]
        [Alias('Duration')]
        [System.TimeSpan]$TimeSpan
    )

    [System.Xml.XmlConvert]::ToString($TimeSpan)


    <#
.SYNOPSIS
    The ConvertTo-ISO8601Duration can be used to convert a timespan object into a duration string in the ISO 8601 format.

.DESCRIPTION
    The ConvertTo-ISO8601Duration uses the ToString() static method in the System.Xml.XmlConvert to convert a timespan object into to a ISO 8601 string format.
    More information on the ISO 8601 format can be found at http://www.iso.org/iso/home/standards/iso8601.htm
    More information on the duration format can be found at https://en.wikipedia.org/wiki/ISO_8601#Durations

.INPUTS
    [System.TimeSpan]

.OUTPUTS
    [System.String]


.NOTES
    Author : Martin Schvartzman, martin.schvartzman@microsoft.com
    Blog   : http://aka.ms/pstips

.PARAMETER TimeSpan
    Specifies the duration timespan object you want to convert to the ISO 8601 string format

.EXAMPLE
    ConvertTo-ISO8601Duration -Duration (New-TimeSpan -Hours 6 -Minutes 30 -Seconds 10)

    PT6H30M10S


.EXAMPLE
    [timespan]::MaxValue | ConvertTo-ISO8601Duration

    P10675199DT2H48M5.4775807S

#>
}
