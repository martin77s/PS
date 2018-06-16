function Get-Noun {
    [cmdletbinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        [string]$Name
    )
    Begin {
        Write-Verbose "[$((Get-Date).TimeofDay) BEGIN  ] Starting $($myinvocation.mycommand)"

    } #begin

    Process {
        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] $Name "

    } #process

    End {
        Write-Verbose "[$((Get-Date).TimeofDay) END    ] Ending $($myinvocation.mycommand)"

    } #end

} #close


Get-Noun -Name martin -Verbose
