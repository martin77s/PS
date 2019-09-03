
function Purge-Logs {
    [CmdletBinding(
        DefaultParameterSetName='LogsAmount',
        SupportsShouldProcess=$true, ConfirmImpact='High'
    )]
    param(

       [Parameter(ParameterSetName='DaysOld', Position=0)] [int]$DaysOld,

       [Parameter(ParameterSetName='LogsAmount', Position=0)] [int]$LogsAmount,

       [Parameter(ParameterSetName='LogsAmount')]
       [Parameter(ParameterSetName='DaysOld')]
       [string]$Path = 'C:\Temp\Logs'
       
    )

    switch ($PsCmdlet.ParameterSetName) { 
        'DaysOld'     { 
            $files = dir -Path $Path -Filter *.log | 
                Where-Object { ((Get-Date)-($_.LastWriteTime)).Days -gt $DaysOld }
            break
        } 
        'LogsAmount'  { 
            $files = dir -Path $Path -Filter *.log | 
                Sort-Object LastWriteTime -Descending | Select-Object -Skip $LogsAmount
            break
        } 
    } 

    if($PsCmdlet.ShouldProcess($Path)) {
        $files | Remove-Item -WhatIf
    }
}

Get-Help Purge-Logs -ShowWindow
Purge-Logs -Path C:\Temp\Logs -DaysOld 100
Purge-Logs -Path C:\Temp\Logs -LogsAmount 1
Purge-Logs 1