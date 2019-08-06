Write-Verbose 'Load PowerShell base modules' -Verbose
Import-Module Microsoft.Powershell.Management
Import-Module Microsoft.Powershell.Utility

Write-Verbose 'Load assemblies' -Verbose
[void] [Reflection.Assembly]::Load('System.DirectoryServices, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
[void] [Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')


function Select-ADContainer {

    param($DomainController, [PSCredential]$Credential, $TopContainer = $null, [switch]$Export, [switch]$Import, $Path = "$($env:USERDNSDOMAIN).xml")


    function Export-TreeToXml {
        param($Path)

        function SaveNodes {
            param($nodesCollection)
            for ($i = 0; $i -lt $nodesCollection.Count; $i++) { 
                $node = $nodesCollection[$i]
                $global:textWriter.WriteStartElement('node')
                $global:textWriter.WriteAttributeString('text',$node.text)
                $global:textWriter.WriteAttributeString('name', $node.name)
                if ($node.Nodes.Count -gt 0) {
                    SaveNodes -nodesCollection $node.Nodes
                }     
                $global:textWriter.WriteEndElement();
            }
        }

        $global:textWriter = New-Object -TypeName System.Xml.XmlTextWriter -ArgumentList @($Path, ([System.Text.Encoding]::UTF8))
        $global:textWriter.WriteStartDocument()
        $global:textWriter.WriteRaw("`r`n")
        $global:textWriter.WriteStartElement('TreeView')
        SaveNodes -nodesCollection $treeView.Nodes
        $global:textWriter.WriteEndElement()
        $global:textWriter.Close()
    }


    function Import-TreeFromXml {
        param($Path)
        Write-Verbose -Message 'Reading XML' -Verbose
        $reader = New-Object -TypeName System.Xml.XmlTextReader -ArgumentList $Path
        $treeView.BeginUpdate()    
        $parentNode = New-Object -TypeName System.Windows.Forms.TreeNode
        while ($reader.Read()) {
            if ($reader.NodeType -eq [System.Xml.XmlNodeType]::Element) {      
                if ($reader.Name -eq 'node') {
                    $newNode = New-Object -TypeName System.Windows.Forms.TreeNode
                    $isEmptyElement = $reader.IsEmptyElement
                    for ($i = 0; $i -lt $reader.AttributeCount; $i++) {
                        $reader.MoveToAttribute($i)
                        if($reader.Name -eq 'Name') { $newNode.Name = $reader.Value } 
                        else { $newNode.Text = $reader.Value }
                    }        
                    if($parentNode.Text) {
                        $parentNode.Nodes.Add($newNode) | Out-Null
                    } else {
                        $treeView.Nodes.Add($newNode) | Out-Null
                    }
                    
                    if (-not $isEmptyElement) { $parentNode = $newNode }

                }
            } elseif ($reader.NodeType -eq [System.Xml.XmlNodeType]::EndElement) {
                if ($reader.Name -eq 'node') { $parentNode = $parentNode.Parent }
            } elseif($reader.NodeType -eq [System.Xml.XmlNodeType]::None) {
                return
            } elseif($reader.NodeType -eq 'text') {
                $parentNode.Nodes.Add($reader.Value);
            }
        }
        $treeView.EndUpdate()    
        $reader.Close()
    }


    function Add-Node {
        param($TreeNode, $Node, $DomainController, [PSCredential]$Credential)

        $subNode = $TreeNode.Nodes.Add($Node.DN, $Node.Name)
        $searcher = [adsisearcher]'(|(ObjectClass=organizationalUnit)(ObjectClass=container))'

        $path = ('{0}/{1}' -f $DomainController, $Node.DN) -replace '/$'
        Write-Verbose ('Binding to: {0}' -f $path) -Verbose

        $searchRoot = New-Object -TypeName System.DirectoryServices.DirectoryEntry -ArgumentList (
            $path, $Credential.UserName, $Credential.GetNetworkCredential().Password)

        Write-Verbose ('Adding node: {0}' -f $searchRoot.Path) -Verbose
        $searcher.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
        $searcher.SearchRoot = $searchRoot
        $containers = $searcher.FindAll()

        $containers | ForEach-Object {
            $childNode = (
                New-Object -TypeName PSObject -Property @{
                    DN  = $_.Properties['distinguishedName'][0]
                    Name = $_.Properties['Name'][0]
                }
            )
            if((-not $TopContainer) -or $TopContainer -and $childNode.DN -match [regex]::Escape($TopContainer)) {
                if(!$hLeafs.ContainsKey($childNode.DN)) {
                    $hLeafs.Add($childNode.DN, $childNode.Name)
                    Add-Node -TreeNode $subNode -Node $childNode -DomainController $DomainController -Credential $Credential
                }
            }
        }
    }


    $form = New-Object -TypeName System.Windows.Forms.Form
    $form.Size = New-Object -TypeName System.Drawing.Size -ArgumentList 700, 450
    $form.text = 'Active Directory'
    $form.MaximizeBox = $false
    $treeView = New-Object -TypeName System.Windows.Forms.TreeView
    $treeView.Size = New-Object -TypeName System.Drawing.Size -ArgumentList ($form.Size.Width -18), ($form.Size.Height - 70)

    $label = New-Object -TypeName System.Windows.Forms.Label
    $label.Location = New-Object -TypeName System.Drawing.Size -ArgumentList 15, 390
    $label.Size = New-Object -TypeName System.Drawing.Size -ArgumentList ($form.Size.Width -18), 20
    $label.Text = 'ROOT'
    $treeView.Add_AfterSelect({ $label.Text = $this.SelectedNode.Name }) 
    $treeView.Add_MouseDoubleClick({
        $script:SelectedContainer = New-Object -TypeName PSObject -Property @{
            Name              = $this.SelectedNode.Text
            Path              = $this.SelectedNode.FullPath
            DistinguishedName = 'LDAP://{0}' -f $this.SelectedNode.Name
        }
        $form.Close()
    })

    $form.Controls.Add($label)

    if($Import) { 
        Import-TreeFromXml -Path $Path

    } else {

        $hLeafs = @{}

        if($DomainController -notmatch '^LDAP://') {
            $DomainController = 'LDAP://' + $DomainController
        }

        if($TopContainer) {
            $TopContainer = $TopContainer -replace '^LDAP://'
        }

        Write-Verbose 'Connecting to AD...' -Verbose
        $rootDSE = New-Object -TypeName System.DirectoryServices.DirectoryEntry -ArgumentList (
            $DomainController, $Credential.UserName, $Credential.GetNetworkCredential().Password)

        Write-Verbose 'Reading AD...' -Verbose
        Add-Node -TreeNode $treeView -Node ([pscustomobject]@{DN=$rootDSE.distinguishedName.Value;Name=$rootDSE.Name.Value}) `
            -DomainController $DomainController -Credential $Credential
    }

    if($Export) { 
        Write-Verbose "Exporting AD tree to $Path" -Verbose
        Export-TreeToXml -Path $Path

    } else {
        [void]$form.Controls.Add($treeView)
        [void]$form.ShowDialog()
        $script:SelectedContainer
    }
}



<# Plain, 'connected' usage:
$DomainController = 'DC1'
$Credential = Get-Credential CONTOSO\Administrator
Select-ADContainer -DomainController $DomainController -Credential $Credential
#>


<# Export tree to xml file:
$DomainController = 'DC1'
$Credential = Get-Credential CONTOSO\Administrator
Select-ADContainer -DomainController $DomainController -Credential $Credential -Export -Path C:\Temp\CONTOSO.COM.xml
#>

<# Import from xml file
Select-ADContainer -Import -Path C:\Temp\CONTOSO.COM.xml
#>