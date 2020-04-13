function Test-Internet {
    [Activator]::CreateInstance([Type]::GetTypeFromCLSID(
        [Guid]'{DCB00C01-570F-4A9B-8D69-199FDBA5723B}')).IsConnectedToInternet
}


function Get-UserVariable  {
    param($Name = '*')
    $special = 'ps','psise','psunsupportedconsoleapplications', 'foreach', 'profile'
    $ps = [PowerShell]::Create()
    $null = $ps.AddScript('$null=$host;Get-Variable')
    $reserved = $ps.Invoke() |  Select-Object -ExpandProperty Name
    $ps.Runspace.Close()
    $ps.Dispose()

    Get-Variable -Scope Global | Where-Object { $_.Name -like $Name } |
        Where-Object { $reserved -notcontains $_.Name } |
            Where-Object { $special -notcontains $_.Name } |
                Where-Object { $_.Name }
}


function Join-Object {
    <#
    .SYNOPSIS
        Join data from two sets of objects based on a common value

    .DESCRIPTION
        Join data from two sets of objects based on a common value

        For more details, see the accompanying blog post:
            http://ramblingcookiemonster.github.io/Join-Object/

        For even more details,  see the original code and discussions that this borrows from:
            Dave Wyatt's Join-Object - http://powershell.org/wp/forums/topic/merging-very-large-collections
            Lucio Silveira's Join-Object - http://blogs.msdn.com/b/powershell/archive/2012/07/13/join-object.aspx

    .PARAMETER Left
        'Left' collection of objects to join.  You can use the pipeline for Left.

        The objects in this collection should be consistent.
        We look at the properties on the first object for a baseline.

    .PARAMETER Right
        'Right' collection of objects to join.

        The objects in this collection should be consistent.
        We look at the properties on the first object for a baseline.

    .PARAMETER LeftJoinProperty
        Property on Left collection objects that we match up with RightJoinProperty on the Right collection

    .PARAMETER RightJoinProperty
        Property on Right collection objects that we match up with LeftJoinProperty on the Left collection

    .PARAMETER LeftProperties
        One or more properties to keep from Left.  Default is to keep all Left properties (*).

        Each property can:
            - Be a plain property name like "Name"
            - Contain wildcards like "*"
            - Be a hashtable like @{Name="Product Name";Expression={$_.Name}}.
                 Name is the output property name
                 Expression is the property value ($_ as the current object)

                 Alternatively, use the Suffix or Prefix parameter to avoid collisions
                 Each property using this hashtable syntax will be excluded from suffixes and prefixes

    .PARAMETER RightProperties
        One or more properties to keep from Right.  Default is to keep all Right properties (*).

        Each property can:
            - Be a plain property name like "Name"
            - Contain wildcards like "*"
            - Be a hashtable like @{Name="Product Name";Expression={$_.Name}}.
                 Name is the output property name
                 Expression is the property value ($_ as the current object)

                 Alternatively, use the Suffix or Prefix parameter to avoid collisions
                 Each property using this hashtable syntax will be excluded from suffixes and prefixes

    .PARAMETER Prefix
        If specified, prepend Right object property names with this prefix to avoid collisions

        Example:
            Property Name                   = 'Name'
            Suffix                          = 'j_'
            Resulting Joined Property Name  = 'j_Name'

    .PARAMETER Suffix
        If specified, append Right object property names with this suffix to avoid collisions

        Example:
            Property Name                   = 'Name'
            Suffix                          = '_j'
            Resulting Joined Property Name  = 'Name_j'

    .PARAMETER Type
        Type of join.  Default is AllInLeft.

        AllInLeft will have all elements from Left at least once in the output, and might appear more than once
          if the where clause is true for more than one element in right, Left elements with matches in Right are
          preceded by elements with no matches.
          SQL equivalent: outer left join (or simply left join)

        AllInRight is similar to AllInLeft.

        OnlyIfInBoth will cause all elements from Left to be placed in the output, only if there is at least one
          match in Right.
          SQL equivalent: inner join (or simply join)

        AllInBoth will have all entries in right and left in the output. Specifically, it will have all entries
          in right with at least one match in left, followed by all entries in Right with no matches in left,
          followed by all entries in Left with no matches in Right.
          SQL equivalent: full join

    .EXAMPLE
        #
        #Define some input data.

        $l = 1..5 | Foreach-Object {
            [pscustomobject]@{
                Name = "jsmith$_"
                Birthday = (Get-Date).adddays(-1)
            }
        }

        $r = 4..7 | Foreach-Object{
            [pscustomobject]@{
                Department = "Department $_"
                Name = "Department $_"
                Manager = "jsmith$_"
            }
        }

        #We have a name and Birthday for each manager, how do we find their department, using an inner join?
        Join-Object -Left $l -Right $r -LeftJoinProperty Name -RightJoinProperty Manager -Type OnlyIfInBoth -RightProperties Department


            # Name    Birthday             Department
            # ----    --------             ----------
            # jsmith4 4/14/2015 3:27:22 PM Department 4
            # jsmith5 4/14/2015 3:27:22 PM Department 5

    .EXAMPLE
        #
        #Define some input data.

        $l = 1..5 | Foreach-Object {
            [pscustomobject]@{
                Name = "jsmith$_"
                Birthday = (Get-Date).adddays(-1)
            }
        }

        $r = 4..7 | Foreach-Object{
            [pscustomobject]@{
                Department = "Department $_"
                Name = "Department $_"
                Manager = "jsmith$_"
            }
        }

        #We have a name and Birthday for each manager, how do we find all related department data, even if there are conflicting properties?
        $l | Join-Object -Right $r -LeftJoinProperty Name -RightJoinProperty Manager -Type AllInLeft -Prefix j_

            # Name    Birthday             j_Department j_Name       j_Manager
            # ----    --------             ------------ ------       ---------
            # jsmith1 4/14/2015 3:27:22 PM
            # jsmith2 4/14/2015 3:27:22 PM
            # jsmith3 4/14/2015 3:27:22 PM
            # jsmith4 4/14/2015 3:27:22 PM Department 4 Department 4 jsmith4
            # jsmith5 4/14/2015 3:27:22 PM Department 5 Department 5 jsmith5

    .EXAMPLE
        #
        #Hey!  You know how to script right?  Can you merge these two CSVs, where Path1's IP is equal to Path2's IP_ADDRESS?

        #Get CSV data
        $s1 = Import-CSV $Path1
        $s2 = Import-CSV $Path2

        #Merge the data, using a full outer join to avoid omitting anything, and export it
        Join-Object -Left $s1 -Right $s2 -LeftJoinProperty IP_ADDRESS -RightJoinProperty IP -Prefix 'j_' -Type AllInBoth |
            Export-CSV $MergePath -NoTypeInformation

    .EXAMPLE
        #
        # "Hey Warren, we need to match up SSNs to Active Directory users, and check if they are enabled or not.
        #  I'll e-mail you an unencrypted CSV with all the SSNs from gmail, what could go wrong?"

        # Import some SSNs.
        $SSNs = Import-CSV -Path D:\SSNs.csv

        #Get AD users, and match up by a common value, samaccountname in this case:
        Get-ADUser -Filter "samaccountname -like 'wframe*'" |
            Join-Object -LeftJoinProperty samaccountname -Right $SSNs `
                        -RightJoinProperty samaccountname -RightProperties ssn `
                        -LeftProperties samaccountname, enabled, objectclass

    .NOTES
        This borrows from:
            Dave Wyatt's Join-Object - http://powershell.org/wp/forums/topic/merging-very-large-collections/
            Lucio Silveira's Join-Object - http://blogs.msdn.com/b/powershell/archive/2012/07/13/join-object.aspx

        Changes:
            Always display full set of properties
            Display properties in order (left first, right second)
            If specified, add suffix or prefix to right object property names to avoid collisions
            Use a hashtable rather than ordereddictionary (avoid case sensitivity)

    .LINK
        http://ramblingcookiemonster.github.io/Join-Object/

    .FUNCTIONALITY
        PowerShell Language

    #>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipeLine = $true)]
        [object[]] $Left,

        # List to join with $Left
        [Parameter(Mandatory=$true)]
        [object[]] $Right,

        [Parameter(Mandatory = $true)]
        [string] $LeftJoinProperty,

        [Parameter(Mandatory = $true)]
        [string] $RightJoinProperty,

        [object[]]$LeftProperties = '*',

        # Properties from $Right we want in the output.
        # Like LeftProperties, each can be a plain name, wildcard or hashtable. See the LeftProperties comments.
        [object[]]$RightProperties = '*',

        [validateset( 'AllInLeft', 'OnlyIfInBoth', 'AllInBoth', 'AllInRight')]
        [Parameter(Mandatory=$false)]
        [string]$Type = 'AllInLeft',

        [string]$Prefix,
        [string]$Suffix
    )
    Begin
    {
        function AddItemProperties($item, $properties, $hash)
        {
            if ($null -eq $item)
            {
                return
            }

            foreach($property in $properties)
            {
                $propertyHash = $property -as [hashtable]
                if($null -ne $propertyHash)
                {
                    $hashName = $propertyHash["name"] -as [string]
                    $expression = $propertyHash["expression"] -as [scriptblock]

                    $expressionValue = $expression.Invoke($item)[0]

                    $hash[$hashName] = $expressionValue
                }
                else
                {
                    foreach($itemProperty in $item.psobject.Properties)
                    {
                        if ($itemProperty.Name -like $property)
                        {
                            $hash[$itemProperty.Name] = $itemProperty.Value
                        }
                    }
                }
            }
        }

        function TranslateProperties
        {
            [cmdletbinding()]
            param(
                [object[]]$Properties,
                [psobject]$RealObject,
                [string]$Side)

            foreach($Prop in $Properties)
            {
                $propertyHash = $Prop -as [hashtable]
                if($null -ne $propertyHash)
                {
                    $hashName = $propertyHash["name"] -as [string]
                    $expression = $propertyHash["expression"] -as [scriptblock]

                    $ScriptString = $expression.tostring()
                    if($ScriptString -notmatch 'param\(')
                    {
                        Write-Verbose "Property '$HashName'`: Adding param(`$_) to scriptblock '$ScriptString'"
                        $Expression = [ScriptBlock]::Create("param(`$_)`n $ScriptString")
                    }

                    $Output = @{Name =$HashName; Expression = $Expression }
                    Write-Verbose "Found $Side property hash with name $($Output.Name), expression:`n$($Output.Expression | out-string)"
                    $Output
                }
                else
                {
                    foreach($ThisProp in $RealObject.psobject.Properties)
                    {
                        if ($ThisProp.Name -like $Prop)
                        {
                            Write-Verbose "Found $Side property '$($ThisProp.Name)'"
                            $ThisProp.Name
                        }
                    }
                }
            }
        }

        function WriteJoinObjectOutput($leftItem, $rightItem, $leftProperties, $rightProperties)
        {
            $properties = @{}

            AddItemProperties $leftItem $leftProperties $properties
            AddItemProperties $rightItem $rightProperties $properties

            New-Object psobject -Property $properties
        }

        #Translate variations on calculated properties.  Doing this once shouldn't affect perf too much.
        foreach($Prop in @($LeftProperties + $RightProperties))
        {
            if($Prop -as [hashtable])
            {
                foreach($variation in ('n','label','l'))
                {
                    if(-not $Prop.ContainsKey('Name') )
                    {
                        if($Prop.ContainsKey($variation) )
                        {
                            $Prop.Add('Name',$Prop[$Variation])
                        }
                    }
                }
                if(-not $Prop.ContainsKey('Name') -or $Prop['Name'] -like $null )
                {
                    Throw "Property is missing a name`n. This should be in calculated property format, with a Name and an Expression:`n@{Name='Something';Expression={`$_.Something}}`nAffected property:`n$($Prop | out-string)"
                }


                if(-not $Prop.ContainsKey('Expression') )
                {
                    if($Prop.ContainsKey('E') )
                    {
                        $Prop.Add('Expression',$Prop['E'])
                    }
                }

                if(-not $Prop.ContainsKey('Expression') -or $Prop['Expression'] -like $null )
                {
                    Throw "Property is missing an expression`n. This should be in calculated property format, with a Name and an Expression:`n@{Name='Something';Expression={`$_.Something}}`nAffected property:`n$($Prop | out-string)"
                }
            }
        }

        $leftHash = @{}
        $rightHash = @{}

        # Hashtable keys can't be null; we'll use any old object reference as a placeholder if needed.
        $nullKey = New-Object psobject

        $bound = $PSBoundParameters.keys -contains "InputObject"
        if(-not $bound)
        {
            [System.Collections.ArrayList]$LeftData = @()
        }
    }
    Process
    {
        #We pull all the data for comparison later, no streaming
        if($bound)
        {
            $LeftData = $Left
        }
        Else
        {
            foreach($Object in $Left)
            {
                [void]$LeftData.add($Object)
            }
        }
    }
    End
    {
        foreach ($item in $Right)
        {
            $key = $item.$RightJoinProperty

            if ($null -eq $key)
            {
                $key = $nullKey
            }

            $bucket = $rightHash[$key]

            if ($null -eq $bucket)
            {
                $bucket = New-Object System.Collections.ArrayList
                $rightHash.Add($key, $bucket)
            }

            $null = $bucket.Add($item)
        }

        foreach ($item in $LeftData)
        {
            $key = $item.$LeftJoinProperty

            if ($null -eq $key)
            {
                $key = $nullKey
            }

            $bucket = $leftHash[$key]

            if ($null -eq $bucket)
            {
                $bucket = New-Object System.Collections.ArrayList
                $leftHash.Add($key, $bucket)
            }

            $null = $bucket.Add($item)
        }

        $LeftProperties = TranslateProperties -Properties $LeftProperties -Side 'Left' -RealObject $LeftData[0]
        $RightProperties = TranslateProperties -Properties $RightProperties -Side 'Right' -RealObject $Right[0]

        #I prefer ordered output. Left properties first.
        [string[]]$AllProps = $LeftProperties

        #Handle prefixes, suffixes, and building AllProps with Name only
        $RightProperties = foreach($RightProp in $RightProperties)
        {
            if(-not ($RightProp -as [Hashtable]))
            {
                Write-Verbose "Transforming property $RightProp to $Prefix$RightProp$Suffix"
                @{
                    Name="$Prefix$RightProp$Suffix"
                    Expression=[scriptblock]::create("param(`$_) `$_.'$RightProp'")
                }
                $AllProps += "$Prefix$RightProp$Suffix"
            }
            else
            {
                Write-Verbose "Skipping transformation of calculated property with name $($RightProp.Name), expression:`n$($RightProp.Expression | out-string)"
                $AllProps += [string]$RightProp["Name"]
                $RightProp
            }
        }

        $AllProps = $AllProps | Select-Object -Unique

        Write-Verbose "Combined set of properties: $($AllProps -join ', ')"

        foreach ( $entry in $leftHash.GetEnumerator() )
        {
            $key = $entry.Key
            $leftBucket = $entry.Value

            $rightBucket = $rightHash[$key]

            if ($null -eq $rightBucket)
            {
                if ($Type -eq 'AllInLeft' -or $Type -eq 'AllInBoth')
                {
                    foreach ($leftItem in $leftBucket)
                    {
                        WriteJoinObjectOutput $leftItem $null $LeftProperties $RightProperties | Select-Object $AllProps
                    }
                }
            }
            else
            {
                foreach ($leftItem in $leftBucket)
                {
                    foreach ($rightItem in $rightBucket)
                    {
                        WriteJoinObjectOutput $leftItem $rightItem $LeftProperties $RightProperties | Select-Object $AllProps
                    }
                }
            }
        }

        if ($Type -eq 'AllInRight' -or $Type -eq 'AllInBoth')
        {
            foreach ($entry in $rightHash.GetEnumerator())
            {
                $key = $entry.Key
                $rightBucket = $entry.Value

                $leftBucket = $leftHash[$key]

                if ($null -eq $leftBucket)
                {
                    foreach ($rightItem in $rightBucket)
                    {
                        WriteJoinObjectOutput $null $rightItem $LeftProperties $RightProperties | Select-Object $AllProps
                    }
                }
            }
        }
    }
}


function Get-Proxy {

    $regKeyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'

    $ProxyServer = (Get-ItemProperty $regKeyPath -Name ProxyServer -ErrorAction SilentlyContinue).ProxyServer
    $proxyValues = if($ProxyServer -match '^http=(?<ProxyServer>.*):(?<Port>\d+);(https=(?<ProxyServerSecured>.*):(?<PortSecured>\d+))|(?<ProxyServer>.*):(?<Port>\d+)') {
        $matches
    } else {
        @{}
    }

    $proxyValues['Enabled'] = [bool](Get-ItemProperty $regKeyPath -Name ProxyEnable -ErrorAction SilentlyContinue).ProxyEnable
    $proxyValues['BypassAdresses'] = (Get-ItemProperty $regKeyPath -Name ProxyOverride -ErrorAction SilentlyContinue).ProxyOverride
    $proxyValues['AutoConfigURL'] = (Get-ItemProperty $regKeyPath -Name AutoConfigURL -ErrorAction SilentlyContinue).AutoConfigURL

    New-Object -TypeName PSObject -Property $proxyValues |
        Select-Object -Property Enabled, ProxyServer, Port, ProxyServerSecured, PortSecured, BypassAdresses, AutoConfigURL
}


function Set-Proxy {

    [cmdletbinding(DefaultParameterSetName='Enable', SupportsShouldProcess=$true)]

    param(
        [Parameter(Mandatory=$true, ParameterSetName='Enable')]
        [switch]$Enable,

        [Parameter(Mandatory=$false, ParameterSetName='Enable')]
        [string]$AutoConfigURL = $null,

        [Parameter(Mandatory=$true, ParameterSetName='Enable')]
        [string]$ProxyServer,

        [Parameter(Mandatory=$false, ParameterSetName='Enable')]
        [int]$Port = 8080,

        [Parameter(Mandatory=$false, ParameterSetName='Enable')]
        [string]$ProxyServerSecured = $null,

        [Parameter(Mandatory=$false, ParameterSetName='Enable')]
        [int]$PortSecured = 8080,

        [Parameter(Mandatory=$false, ParameterSetName='Enable')]
        [string[]]$BypassAdresses = '',

        [Parameter(Mandatory=$true, ParameterSetName='Disable')]
        [switch]$Disable,

        [Parameter(Mandatory=$false)]
        [switch]$PassThru

    )

    if ($pscmdlet.ShouldProcess('Browser Settings', $MyInvocation.MyCommand)) {

        $regKeyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'


        if ($PSCmdlet.ParameterSetName -eq 'Disable') {
            Set-ItemProperty $regKeyPath -Name ProxyEnable -Value 0

        } else {
            Set-ItemProperty $regKeyPath -Name ProxyEnable -Value 1
            Set-ItemProperty $regKeyPath -Name ProxyOverride -Value $BypassAdresses

            if($ProxyServerSecured -and $PortSecured) {
                Set-ItemProperty $regKeyPath -Name ProxyServer -Value ('http={0}:{1};https={2}:{3}' -f $ProxyServer, $Port, $ProxyServerSecured, $PortSecured)

            } else {
                Set-ItemProperty $regKeyPath -Name ProxyServer -Value ('{0}:{1}' -f $ProxyServer, $Port)
            }

            if($AutoConfigURL) {
                Set-ItemProperty $regKeyPath -Name AutoConfigURL -Value $AutoConfigURL
            }

        }

        if($PassThru) { Get-Proxy }
    }

}


function New-CompiledScript {

    [Alias('ps12exe')]

    param([string]$ScriptFilePath, [switch]$PassThru)

    $ExeFilePath = $ScriptFilePath -replace '\.ps1$', '.exe'
    $encodedCommand =  [System.Convert]::ToBase64String(
        [System.Text.Encoding]::Unicode.GetBytes((Get-Content -Path $ScriptFilePath -Raw)))

    Add-Type -OutputType ConsoleApplication -OutputAssembly $ExeFilePath -TypeDefinition @"
        using System;
        using System.Text;
        using System.Collections.ObjectModel;
        using System.Management.Automation;
        using System.Management.Automation.Runspaces;

        namespace $((Split-Path -Path $ExeFilePath -Leaf)-replace '\.exe') {
          internal class Program {
            private static void Main(string[] args) {
              string s = @"$($encodedCommand)";
              using (Runspace runspace = RunspaceFactory.CreateRunspace()) {
                runspace.Open();
                using (Pipeline pipeline = runspace.CreatePipeline()) {
                  string @string = Encoding.Unicode.GetString(Convert.FromBase64String(s));
                  pipeline.Commands.AddScript(@string);
                  pipeline.Commands.Add("Out-String");
                  Collection<PSObject> collection = pipeline.Invoke();
                  if (collection.Count <= 0) return;
                  StringBuilder stringBuilder = new StringBuilder();
                  foreach (PSObject psObject in collection)
                    stringBuilder.Append(psObject.BaseObject.ToString() + "\r\n");
                  Console.WriteLine(stringBuilder.ToString());
                }
              }
            }
          }
        }
"@
    if($PassThru) { Get-Item -Path $ExeFilePath }
}


function Clear-MRUList {
    $key = Get-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU
    $regValues = $key.GetValueNames() | ForEach-Object {
        New-Object -TypeName psobject -Property @{
            Name    = $_
            Path    = $key.PSPath
            Type    = $key.GetValueKind($_)
            Data    = $key.GetValue($_)
            RegPath = $key.Name
        }
    }
    $regValues | Where-Object { $_.Name -ne 'MRUList' } | Remove-ItemProperty
    Clear-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU -Name MRUList
}


function Start-PSCountdown {

    [cmdletbinding()]
    [OutputType("None")]
    Param(
        [Parameter(Position = 0, HelpMessage = "Enter the number of minutes to countdown (1-60). The default is 5.")]
        [ValidateRange(1, 60)]
        [int32]$Minutes = 5,
        [Parameter(HelpMessage = "Enter the text for the progress bar title.")]
        [ValidateNotNullorEmpty()]
        [string]$Title = "Counting Down ",
        [Parameter(Position = 1, HelpMessage = "Enter a primary message to display in the parent window.")]
        [ValidateNotNullorEmpty()]
        [string]$Message = "Starting soon.",
        [Parameter(HelpMessage = "Use this parameter to clear the screen prior to starting the countdown.")]
        [switch]$ClearHost
    )
    DynamicParam {
        #this doesn't appear to work in PowerShell core on Linux
        if ($host.PrivateData.ProgressBackgroundColor -And ( $PSVersionTable.Platform -eq 'Win32NT' -OR $PSEdition -eq 'Desktop')) {

            #define a parameter attribute object
            $attributes = New-Object System.Management.Automation.ParameterAttribute
            $attributes.ValueFromPipelineByPropertyName = $False
            $attributes.Mandatory = $false
            $attributes.HelpMessage = @"
Select a progress bar style. This only applies when using the PowerShell console or ISE.

Default - use the current value of `$host.PrivateData.ProgressBarBackgroundColor
Transparent - set the progress bar background color to the same as the console
Random - randomly cycle through a list of console colors
"@

            #define a collection for attributes
            $attributeCollection = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($attributes)
            #define the validate set attribute
            $validate = [System.Management.Automation.ValidateSetAttribute]::new("Default", "Random", "Transparent")
            $attributeCollection.Add($validate)

            #add an alias
            $alias = [System.Management.Automation.AliasAttribute]::new("style")
            $attributeCollection.Add($alias)

            #define the dynamic param
            $dynParam1 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("ProgressStyle", [string], $attributeCollection)
            $dynParam1.Value = "Default"

            #create array of dynamic parameters
            $paramDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
            $paramDictionary.Add("ProgressStyle", $dynParam1)
            #use the array
            return $paramDictionary

        } #if
    } #dynamic parameter
    Begin {
        $loading = @(
            'Waiting for someone to hit enter',
            'Warming up processors',
            'Downloading the Internet',
            'Trying common passwords',
            'Commencing infinite loop',
            'Injecting double negatives',
            'Breeding bits',
            'Capturing escaped bits',
            'Dreaming of electric sheep',
            'Calculating gravitational constant',
            'Adding Hidden Agendas',
            'Adjusting Bell Curves',
            'Aligning Covariance Matrices',
            'Attempting to Lock Back-Buffer',
            'Building Data Trees',
            'Calculating Inverse Probability Matrices',
            'Calculating Llama Expectoration Trajectory',
            'Compounding Inert Tessellations',
            'Concatenating Sub-Contractors',
            'Containing Existential Buffer',
            'Deciding What Message to Display Next',
            'Increasing Accuracy of RCI Simulators',
            'Perturbing Matrices',
            'Initializing flux capacitors',
            'Brushing up on my Dothraki',
            'Preparing second breakfast',
            'Preparing the jump to lightspeed',
            'Initiating self-destruct sequence',
            'Mining cryptocurrency',
            'Aligning Heisenberg compensators',
            'Setting phasers to stun',
            'Deciding...blue pill or Yellow?',
            'Bringing Skynet online',
            'Learning PowerShell',
            'On hold with Comcast customer service',
            'Waiting for Godot',
            'Folding proteins',
            'Searching for infinity stones',
            'Restarting the ARC reactor',
            'Learning regular expressions',
            'Trying to quit vi',
            'Waiting for the last Game_of_Thrones book',
            'Watching paint dry',
            'Aligning warp coils'
        )
        if ($ClearHost) {
            Clear-Host
        }
        $PSBoundParameters | out-string | Write-Verbose
        if ($psboundparameters.ContainsKey('progressStyle')) {

            if ($PSBoundParameters.Item('ProgressStyle') -ne 'default') {
                $saved = $host.PrivateData.ProgressBackgroundColor
            }
            if ($PSBoundParameters.Item('ProgressStyle') -eq 'transparent') {
                $host.PrivateData.progressBackgroundColor = $host.ui.RawUI.BackgroundColor
            }
        }
        $startTime = Get-Date
        $endTime = $startTime.AddMinutes($Minutes)
        $totalSeconds = (New-TimeSpan -Start $startTime -End $endTime).TotalSeconds

        $totalSecondsChild = Get-Random -Minimum 4 -Maximum 30
        $startTimeChild = $startTime
        $endTimeChild = $startTimeChild.AddSeconds($totalSecondsChild)
        $loadingMessage = $loading[(Get-Random -Minimum 0 -Maximum ($loading.Length - 1))]

        #used when progress style is random
        $progcolors = "black", "darkgreen", "magenta", "blue", "darkGray"

    } #begin
    Process {
        #this does not work in VS Code
        if ($host.name -match 'Visual Studio Code') {
            Write-Warning "This command will not work in VS Code."
            #bail out
            Return
        }
        Do {
            $now = Get-Date
            $secondsElapsed = (New-TimeSpan -Start $startTime -End $now).TotalSeconds
            $secondsRemaining = $totalSeconds - $secondsElapsed
            $percentDone = ($secondsElapsed / $totalSeconds) * 100

            Write-Progress -id 0 -Activity $Title -Status $Message -PercentComplete $percentDone -SecondsRemaining $secondsRemaining

            $secondsElapsedChild = (New-TimeSpan -Start $startTimeChild -End $now).TotalSeconds
            $secondsRemainingChild = $totalSecondsChild - $secondsElapsedChild
            $percentDoneChild = ($secondsElapsedChild / $totalSecondsChild) * 100

            if ($percentDoneChild -le 100) {
                Write-Progress -id 1 -ParentId 0 -Activity $loadingMessage -PercentComplete $percentDoneChild -SecondsRemaining $secondsRemainingChild
            }

            if ($percentDoneChild -ge 100 -and $percentDone -le 98) {
                if ($PSBoundParameters.ContainsKey('ProgressStyle') -AND $PSBoundParameters.Item('ProgressStyle') -eq 'random') {
                    $host.PrivateData.progressBackgroundColor = ($progcolors | Get-Random)
                }
                $totalSecondsChild = Get-Random -Minimum 4 -Maximum 30
                $startTimeChild = $now
                $endTimeChild = $startTimeChild.AddSeconds($totalSecondsChild)
                if ($endTimeChild -gt $endTime) {
                    $endTimeChild = $endTime
                }
                $loadingMessage = $loading[(Get-Random -Minimum 0 -Maximum ($loading.Length - 1))]
            }

            Start-Sleep 0.2
        } Until ($now -ge $endTime)
    } #progress

    End {
        if ($saved) {
            #restore value if it has been changed
            $host.PrivateData.ProgressBackgroundColor = $saved
        }
    } #end

}


function Start-Break {
    [Alias('Afsaka')]
    [CmdletBinding()]
    param($Minutes = 15)
    Start-PSCountdown -Minutes $Minutes -Title '*** PowerShell Workshop ***' -Message "* Taking a $Minutes min. break *" -ClearHost
}


function Flip-Object {
    param (
        [Object]
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $InputObject
    )
    process {
        $InputObject |  ForEach-Object {
            $instance = $_
            $instance |  Get-Member -MemberType *Property |
            Select-Object -ExpandProperty Name | ForEach-Object {
                [PSCustomObject]@{
                    Name = $_
                    Value = $instance.$_
                }
            }
        }
    }
}


function Connect-Sql {
    [CmdletBinding()]
    param (
        [string] $SQLServer = $env:ComputerName,

        [string] $SQLInstanceName = 'MSSQLSERVER',

        [string] $Database = 'master',

        [string] $ApplicationName = 'PowerShell'
    )

    if ($SQLInstanceName -ne 'MSSQLSERVER') {
        $SQLServer += "\$SQLInstanceName"
    }

    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder['Data Source']        = $SQLServer
    $builder['Initial Catalog']    = $Database
    $builder['Application Name']   = $ApplicationName
    $builder['Connect Timeout']    = 120
    $builder['Trusted_Connection'] = $true

    $conn = New-Object System.Data.SqlClient.SqlConnection $builder.ConnectionString

    try  {
        $conn.Open()
        return $conn
    }

    catch {
        throw $_.Exception.Message
    }
}


function Invoke-SqlStoredProcedure {
    [CmdletBinding()]
    [OutputType([Hashtable], ParameterSetName = 'WithResults')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Data.Common.DbConnection] $Connection,

        [string] $DatabaseName,

        [string] $ProcedureName,

        [Alias("Parameters")]
        [Hashtable]  $QueryParameters,

        [Int] $CommandTimeout = 300,

        [Parameter(ParameterSetName = 'WithResults')]
        [switch] $WithResults
    )

    $command = $Connection.CreateCommand()
    $command.CommandType = "StoredProcedure"
    $command.CommandTimeout = $CommandTimeout
    $command.CommandText = $ProcedureName
    if ($QueryParameters.Keys.Count -gt 0) {
        foreach($key in $QueryParameters.Keys) {
            $command.Parameters.AddWithValue($key, $QueryParameters[$key]) | Out-Null
        }
    }

    try {
        $executeParams = @{
            Connection = $Connection
            Command = $command
            DatabaseName = $DatabaseName
            WithResults = $WithResults
        }
        return ExecuteDbCommand @executeParams
    }

    catch {
        throw $_.Exception.Message
    }

    finally {
        $command.Dispose()
    }
}


function Invoke-SqlQuery {
    [CmdletBinding()]
    [OutputType('Hashtable', ParameterSetName = 'WithResults')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Data.Common.DbConnection] $Connection,

        [Parameter(Mandatory = $true)]
        [string] $DatabaseName,

        [Parameter(Mandatory = $true)]
        [string] $QueryString,

        [Alias("Parameters")]
        [Hashtable] $QueryParameters,

        [Int] $CommandTimeout = 300,

        [Parameter(ParameterSetName = 'WithResults')]
        [Switch] $WithResults
    )

    $command = $Connection.CreateCommand()
    $command.CommandType = "Text"
    $command.CommandTimeout = $CommandTimeout
    $command.CommandText = $QueryString
    if ($QueryParameters.Keys.Count -gt 0) {
        foreach($key in $QueryParameters.Keys) {
            $command.Parameters.AddWithValue($key, $QueryParameters[$key]) | Out-Null
        }
    }

    try {
        $executeParams = @{
            Connection = $Connection
            Command = $Command
            DatabaseName = $DatabaseName
            WithResults = $WithResults
        }
        return ExecuteDbCommand @executeParams
    }

    catch {
        throw $_.Exception.Message
    }

    finally {
        $command.Dispose()
    }
}


function ConvertFrom-ErrorRecord {
  [CmdletBinding(DefaultParameterSetName="ErrorRecord")]
  param
  (
    [Management.Automation.ErrorRecord]
    [Parameter(Mandatory,ValueFromPipeline,ParameterSetName="ErrorRecord", Position=0)]
    $Record,

    [Object]
    [Parameter(Mandatory,ValueFromPipeline,ParameterSetName="Unknown", Position=0)]
    $Alien
  )

  process
  {
    if ($PSCmdlet.ParameterSetName -eq 'ErrorRecord')
    {
      [PSCustomObject]@{
        Exception = $Record.Exception.Message
        Reason    = $Record.CategoryInfo.Reason
        Target    = $Record.CategoryInfo.TargetName
        Script    = $Record.InvocationInfo.ScriptName
        Line      = $Record.InvocationInfo.ScriptLineNumber
        Column    = $Record.InvocationInfo.OffsetInLine
      }
    }
    else
    {
      Write-Warning "$Alien"
    }
  }
}


function ConvertTo-Base64 {
    param($String)
    [Convert]::ToBase64String(
        [System.Text.Encoding]::UTF8.GetBytes($String)
    )
}


function ConvertFrom-Base64 {
    param($EncodedString)
    [System.Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($EncodedString))
}


function Convert-StringToHex {
    param($String)
    return ([System.BitConverter]::ToString(
        [System.Text.Encoding]::UTF8.GetBytes($String)).split('-') -join '')
}


function Convert-BytesToHex {
    param($Bytes)
    return ([System.BitConverter]::ToString($Bytes) -replace '-')
}


function Convert-HexToBytes {
    param($Hex)
    # Converts a hex string to a byte array of 16 bit elements
    # Input String must have an even length
    [byte[]]$Bytes = @()
    while ($Hex.Length -gt 0) {
        $Bytes += [Convert]::ToInt16(($Hex[0..1] -join ''),16)
        $Hex = $Hex.Substring(2)
    }
    return $Bytes
}


function Convert-HexToString ($Hex) {
    $StringData = ''
    while ($Hex.Length -gt 0) {
        $StringData += [string][char][Convert]::ToInt16(($Hex[0..1] -join ''),16)
        $Hex = $Hex.Substring(2)
    }
    return $StringData
}


function Convert-Temperature {
    param (
        [Parameter(ParameterSetName='Celsius')]
        [double]$Celsius,

        [Parameter(ParameterSetName='Fahrenheit')]
        [double]$Fahrenheit,

        [Parameter(ParameterSetName='Kelvin')]
        [double]$Kelvin
    )

    switch ($psCmdlet.ParameterSetName) {

        'Celsius' {
            New-Object -TypeName psobject -Property @{
                Celsius    = $Celsius
                Fahrenheit = [math]::Round((32 + ($Celsius * 1.8)), 2)
                Kelvin     = $Celsius + 273.15
            }
        }

        'Fahrenheit' {
            New-Object -TypeName psobject -Property @{
                Celsius    = [math]::Round((($Fahrenheit - 32) / 1.8), 2)
                Fahrenheit = $Fahrenheit
                Kelvin     = ([math]::Round((($Fahrenheit - 32) / 1.8), 2)) + 273.15
            }
        }

        'Kelvin' {
            New-Object -TypeName psobject -Property @{
                Celsius    = $Kelvin - 273.15
                Fahrenheit = [math]::Round((32 + (($Kelvin - 273.15) * 1.8)), 2)
                Kelvin     = $Kelvin
            }
        }
    }
}


function Get-Weather {
<#
.SYNOPSIS
  Shows current weather conditions in PowerShell console.

.DESCRIPTION
  This scirpt will show the current weather conditions for your area in your PowerShell console.
While you could use the script on its own, it is highly recommended to add it to your profile.
See https://technet.microsoft.com/en-us/library/ff461033.aspx for more info.

  You will need to get an OpenWeather API key from http://openweathermap.org/api - it's free.
Once you have your key, replace "YOUR_API_KEY" with your key.

  Note that weather results are displayed in metric (�C) units.
To switch to imperial (�F) change all instances of '&units=metric' to '&units=imperial'
as well as all instances of '�C' to '�F'.

.EXAMPLE
  Get-Weather -City Toronto -Country CA

  In this example, we will get the weather for Toronto, CA.
If you do not live in a major city, select the closest one to you. Note that the
country code is the two-digit code for your country. For a list of country
codes, see https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2

.NOTES
  Written by Nick Tamm, nicktamm.com
I take no responsibility for any issues caused by this script.

.LINK
  https://github.com/obs0lete/Get-Weather
#>
  param (
    [string]$City = 'Tel Aviv',

    [string]$Country = 'Israel')

  $API = 'f22a7a683b49ac7123b96ff0ed892539'
  $units = 'metric' # imperial | metric
  $unitChar = if($units -eq 'metric') { [char]0176 } else { ' F' }

  $Url = "api.openweathermap.org/data/2.5/weather?q=$City,$Country&units=$units&appid=$API&type=accurate&mode=json"
  $JSONResults = Invoke-WebRequest $Url
  Write-Verbose "Attempting URL $Url"
  $JSON = $JSONResults.Content
  $JSONData = ConvertFrom-Json $JSON
  $JSONSunrise = $JSONData.sys.sunrise
  $JSONSunset = $JSONData.sys.sunset
  $JSONLastUpdate = $JSONData.dt

  <# Convert UNIX UTC time to (human) readable format #>
  $Sunrise = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($JSONSunrise))
  $Sunset = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($JSONSunset))
  $LastUpdate = [TimeZone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($JSONLastUpdate))
  $Sunrise = "{0:HH:mm:ss}" -f (Get-Date $Sunrise)
  $Sunset = "{0:HH:mm:ss}" -f (Get-Date $Sunset)
  $LastUpdate = "{0:HH:mm:ss}" -f (Get-Date $LastUpdate)

  <# XML request for everything else #>
  $Url = "api.openweathermap.org/data/2.5/weather?q=$City,$Country&units=$units&appid=$API&type=accurate&mode=xml"
  [xml]$XMLResults = Invoke-WebRequest $Url
  $XMLData = $XMLResults.current

  <# Get current weather value. Needed to convert case of characters. #>
  $CurrentValue = $XMLData.weather.value

  <# Get precipitation mode (type of precipitation). Needed to convert case of characters. #>
  $PrecipitationValue = $XMLData.precipitation.mode

  <# Get precipitation amount (in mm). Needed to convert case of characters. #>
  $PrecipitationMM = $XMLData.precipitation.value

  <# Get precipitation unit (mm in last x hours). Needed to convert case of characters. #>
  $PrecipitationHRS = $XMLData.precipitation.unit

  <# Get wind speed value. Needed to convert case of characters. #>
  $WindValue = $XMLData.wind.speed.name

  <# Get the current time. This is for clear conditions at night time. #>
  $Time = Get-Date -DisplayHint Time

  <# Define the numbers for various weather conditions #>
  $Thunder = "200", "201", "202", "210", "211", "212", "221", "230", "231", "232"
  $Drizzle = "300", "301", "302", "310", "311", "312", "313", "314", "321", "500", "501", "502"
  $Rain = "503", "504", "520", "521", "522", "531"
  $LightSnow = "600", "601"
  $HeavySnow = "602", "622"
  $SnowAndRain = "611", "612", "615", "616", "620", "621"
  $Atmosphere = "701", "711", "721", "731", "741", "751", "761", "762", "771", "781"
  $Clear = "800"
  $PartlyCloudy = "801", "802", "803"
  $Cloudy = "804"
  $Windy = "900", "901", "902", "903", "904", "905", "906", "951", "952", "953", "954", "955", "956", "957", "958", "959", "960", "961", "962"

  <# Create the variables we will use to display weather information #>
  $Weather = (Get-Culture).textinfo.totitlecase($CurrentValue.tolower())
  $CurrentTemp = "Current Temp : " + [Math]::Round($XMLData.temperature.value, 0) + $unitChar
  $High = "Today's High : " + [Math]::Round($XMLData.temperature.max, 0) + $unitChar
  $Low = "Today's Low  : " + [Math]::Round($XMLData.temperature.min, 0) + $unitChar
  $Humidity = "Humidity       : " + $XMLData.humidity.value + $XMLData.humidity.unit
  $Precipitation = "Precipitation  : " + (Get-Culture).textinfo.totitlecase($PrecipitationValue.tolower())

  <# Checking if there is precipitation and if so, display the values in $precipitationMM and $precipitationHRS #>
  if ($Precipitation -eq "Precipitation  : No") {
    $PrecipitationData = "Precip. Data   : No Precipitation"
  } else {
    $PrecipitationData = "Precip. Data   : " + $PrecipitationMM + "mm in the last " + $PrecipitationHRS
  }

  $script:WindSpeed = "Wind Speed     : " + ([math]::Round(([decimal]$XMLData.wind.speed.value * 1.609344), 1)) + " km/h" + " - Direction: " + $XMLData.wind.direction.code
  $WindCondition = "Wind Condition : " + (Get-Culture).TextInfo.ToTitleCase($WindValue.tolower())
  $Sunrise = "Sunrise      : " + $Sunrise
  $Sunset = "Sunset       : " + $Sunset

  <# END VARIABLES #>

  Write-Host ""
  Write-Host ("Current weather conditions for {0}: " -f $XMLData.city.name) -nonewline; Write-Host $Weather -ForegroundColor Yellow;
  Write-Host "Last Updated:" -nonewline; Write-Host "" $LastUpdate -ForegroundColor Yellow;
  Write-Host ""

  Show-WeatherImage
}


function Show-WeatherImage {

  if ($Thunder.Contains($XMLData.weather.number)) {
    Write-Host "	    .--.   		" -ForegroundColor Gray -nonewline; Write-Host "$CurrentTemp		$Humidity" -ForegroundColor white;
    Write-Host "	 .-(    ). 		" -ForegroundColor Gray -nonewline; Write-Host "$High		$Precipitation" -ForegroundColor white;
    Write-Host "	(___.__)__)		" -ForegroundColor Gray -nonewline; Write-Host "$Low		$PrecipitationData" -ForegroundColor white;
    Write-Host "	  /_   /_  		" -ForegroundColor Yellow -nonewline; Write-Host "$Sunrise		$WindSpeed" -ForegroundColor white;
    Write-Host "	   /    /  		" -ForegroundColor Yellow -nonewline; Write-Host "$Sunset		$WindCondition" -ForegroundColor white;
    Write-Host ""

  } elseif ($Drizzle.Contains($XMLData.weather.number)) {
    Write-Host "	  .-.   		" -ForegroundColor Gray -nonewline; Write-Host "$CurrentTemp		$Humidity" -ForegroundColor white;
    Write-Host "	 (   ). 		" -ForegroundColor Gray -nonewline; Write-Host "$High		$Precipitation" -ForegroundColor white;
    Write-Host "	(___(__)		" -ForegroundColor Gray -nonewline; Write-Host "$Low		$PrecipitationData" -ForegroundColor white;
    Write-Host "	 / / / 			" -ForegroundColor Cyan -nonewline; Write-Host "$Sunrise		$WindSpeed" -ForegroundColor white;
    Write-Host "	  /  			" -ForegroundColor Cyan -nonewline; Write-Host "$Sunset		$WindCondition" -ForegroundColor white;
    Write-Host ""

  } elseif ($Rain.Contains($XMLData.weather.number)) {
    Write-Host "	    .-.   		" -ForegroundColor Gray -nonewline; Write-Host "$CurrentTemp		$Humidity" -ForegroundColor white;
    Write-Host "	   (   ). 		" -ForegroundColor Gray -nonewline; Write-Host "$High		$Precipitation" -ForegroundColor white;
    Write-Host "	  (___(__)		" -ForegroundColor Gray -nonewline; Write-Host "$Low		$PrecipitationData" -ForegroundColor white;
    Write-Host "	 //////// 		" -ForegroundColor Cyan -nonewline; Write-Host "$Sunrise		$WindSpeed" -ForegroundColor white;
    Write-Host "	 /////// 		" -ForegroundColor Cyan -nonewline; Write-Host "$Sunset		$WindCondition" -ForegroundColor white;
    Write-Host ""

  } elseif ($LightSnow.Contains($XMLData.weather.number)) {
    Write-Host "	  .-.   		" -ForegroundColor Gray -nonewline; Write-Host "$CurrentTemp		$Humidity" -ForegroundColor white;
    Write-Host "	 (   ). 		" -ForegroundColor Gray -nonewline; Write-Host "$High		$Precipitation" -ForegroundColor white;
    Write-Host "	(___(__)		" -ForegroundColor Gray -nonewline; Write-Host "$Low		$PrecipitationData" -ForegroundColor white;
    Write-Host "	 *  *  *		$Sunrise		$WindSpeed"
    Write-Host "	*  *  * 		$Sunset		$WindCondition"
    Write-Host ""

  } elseif ($HeavySnow.Contains($XMLData.weather.number)) {
    Write-Host "	    .-.   		" -ForegroundColor Gray -nonewline; Write-Host "$CurrentTemp		$Humidity" -ForegroundColor white;
    Write-Host "	   (   ). 		" -ForegroundColor Gray -nonewline; Write-Host "$High		$Precipitation" -ForegroundColor white;
    Write-Host "	  (___(__)		" -ForegroundColor Gray -nonewline; Write-Host "$Low		$PrecipitationData" -ForegroundColor white;
    Write-Host "	  * * * * 		$Sunrise		$WindSpeed"
    Write-Host "	 * * * *  		$Sunset		$WindCondition"
    Write-Host "	  * * * * "
    Write-Host ""

  } elseif ($SnowAndRain.Contains($XMLData.weather.number)) {
    Write-Host "	  .-.   		" -ForegroundColor Gray -nonewline; Write-Host "$CurrentTemp		$Humidity" -ForegroundColor white;
    Write-Host "	 (   ). 		" -ForegroundColor Gray -nonewline; Write-Host "$High		$Precipitation" -ForegroundColor white;
    Write-Host "	(___(__)		" -ForegroundColor Gray -nonewline; Write-Host "$Low		$PrecipitationData" -ForegroundColor white;
    Write-Host "	 */ */* 		$Sunrise		$WindSpeed"
    Write-Host "	* /* /* 		$Sunset		$WindCondition"
    Write-Host ""

  } elseif ($Atmosphere.Contains($XMLData.weather.number)) {
    Write-Host "	_ - _ - _ -		" -ForegroundColor Gray -nonewline; Write-Host "$CurrentTemp		$Humidity" -ForegroundColor white;
    Write-Host "	 _ - _ - _ 		" -ForegroundColor Gray -nonewline; Write-Host "$High		$Precipitation" -ForegroundColor white;
    Write-Host "	_ - _ - _ -		" -ForegroundColor Gray -nonewline; Write-Host "$Low		$PrecipitationData" -ForegroundColor white;
    Write-Host "	 _ - _ - _ 		" -ForegroundColor Gray -nonewline; Write-Host "$Sunrise		$WindSpeed" -ForegroundColor white;
    Write-Host "				$Sunset		$WindCondition"
    Write-Host ""

  }
    <#
      The following will be displayed on clear evening conditions
      It is set to 18:00:00 (6:00PM). Change this to any value you want.
    #> elseif ($Clear.Contains($XMLData.weather.number) -and $Time -gt "18:00:00") {
    Write-Host "	    *  --.			$CurrentTemp		$Humidity"
    Write-Host "	        \  \   *		$High		$Precipitation"
    Write-Host "	         )  |    *		$Low		$PrecipitationData"
    Write-Host "	*       <   |			$Sunrise		$WindSpeed"
    Write-Host "	   *    ./ /	  		$Sunset		$WindCondition"
    Write-Host "	       ---'   *   "
    Write-Host ""

  } elseif ($Clear.Contains($XMLData.weather.number)) {
    Write-Host "	   \ | /  		" -ForegroundColor Yellow -nonewline; Write-Host "$CurrentTemp		$Humidity" -ForegroundColor white;
    Write-Host "	    .-.   		" -ForegroundColor Yellow -nonewline; Write-Host "$High		$Precipitation" -ForegroundColor white;
    Write-Host "	-- (   ) --		" -ForegroundColor Yellow -nonewline; Write-Host "$Low		$PrecipitationData" -ForegroundColor white;
    Write-Host "	    ``'``   		" -ForegroundColor Yellow -nonewline; Write-Host "$Sunrise		$WindSpeed" -ForegroundColor white;
    Write-Host "	   / | \  		" -ForegroundColor Yellow -nonewline; Write-Host "$Sunset		$WindCondition" -ForegroundColor white;
    Write-Host ""

  } elseif ($PartlyCloudy.Contains($XMLData.weather.number)) {
    Write-Host "	   \ | /   		" -ForegroundColor Yellow -nonewline; Write-Host "$CurrentTemp		$Humidity" -ForegroundColor white;
    Write-Host "	    .-.    		" -ForegroundColor Yellow -nonewline; Write-Host "$High		$Precipitation" -ForegroundColor white;
    Write-Host "	-- (  .--. 		$Low		$PrecipitationData"
    Write-Host "	   .-(    ). 		$Sunrise		$WindSpeed"
    Write-Host "	  (___.__)__)		$Sunset		$WindCondition"
    Write-Host ""

  } elseif ($Cloudy.Contains($XMLData.weather.number)) {
    Write-Host "	    .--.   		$CurrentTemp		$Humidity"
    Write-Host "	 .-(    ). 		$High		$Precipitation"
    Write-Host "	(___.__)__)		$Low		$PrecipitationData"
    Write-Host "	            		$Sunrise		$WindSpeed"
    Write-Host "				$Sunset		$WindCondition"
    Write-Host ""

  } elseif ($Windy.Contains($XMLData.weather.number)) {
    Write-Host "	~~~~      .--.   		$CurrentTemp		$Humidity"
    Write-Host "	 ~~~~~ .-(    ). 		$High		$Precipitation"
    Write-Host "	~~~~~ (___.__)__)		$Low		$PrecipitationData"
    Write-Host "	                 		$Sunrise		$WindSpeed"
    Write-Host "					$Sunset		$WindCondition"
  }
  Write-Host ""
}


function Uninstall-OldModule {

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]

    param([string]$Name = '*', [switch]$ListOnly)

    $manyVersions = & {
        $VerbosePreference = 'SilentlyContinue'
        Get-Module -ListAvailable -Name $Name | Select-Object -Property Name, Version, @{N = 'BasePath'; E = { Split-Path -Path $_.ModuleBase -Parent } } |
            Group-Object -Property Name, BasePath | Where-Object { $_.Count -gt 1 } | Sort-Object -Property Count -Descending
    }

    $oldVersions = $manyVersions | ForEach-Object {
        $group = $_.Name -split ', '
        $versions = @($_.Group.Version | Select-Object -Skip 1)
        [pscustomobject]@{
            Count    = $_.Count - 1
            Name     = $group[0]
            BasePath = $group[1]
            Versions = $versions
        }
    }

    if ($ListOnly) {
        $oldVersions
    } else {
        $oldVersions | ForEach-Object {
            foreach ($version in $_.Versions) {
                $Path = Join-Path $_.BasePath -ChildPath $version
                if ($PSCmdlet.ShouldProcess(('{0} {1} under {2}' -f $_.Name, $version, $_.BasePath), 'Uninstall Module')) {
                    Remove-Item -Path $Path -Recurse -Force
                }
            }
        }
    }
}