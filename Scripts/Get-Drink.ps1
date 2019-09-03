function Get-Drink {

    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [double]$Age
    )

    DynamicParam {

        if($Age) {
            # Set the dynamic parameters' name
            $ParameterName = 'Drink'
                
            # Create the dictionary 
            $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
    
            # Create the collection of attributes
            $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                
            # Create and set the parameters' attributes
            $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
            $ParameterAttribute.Mandatory = $true
    
            # Add the attributes to the attributes collection
            $AttributeCollection.Add($ParameterAttribute)

            # Generate and set the ValidateSet 
            $arrSet = @('Water', 'Milk')
            if($Age -gt 8) { $arrSet += 'Juice', 'Coke', 'FuzeTee' }
            if($Age -ge 18) { $arrSet += 'Beer', 'Vodka', 'Tequila' }

            $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
    
            # Add the ValidateSet to the attributes collection
            $AttributeCollection.Add($ValidateSetAttribute)
    
            # Create and return the dynamic parameter
            $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
            $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
            return $RuntimeParameterDictionary
        }
    }
    
    begin {
        # Bind the parameter to a friendly variable
        $Drink = $PsBoundParameters[$ParameterName]
    }
    
    process {
        'You are {0} years old, and selected to drink {1}' -f $Age, $Drink
    }
}

Get-Drink -Age 1 -Drink Water
Get-Drink -Age 15 -Drink Coke
Get-Drink -Age 25 -Drink Vodka

Get-Drink -Age 5 -Drink Vodka # Error!