PARAM(
    $RemoteComputer = $env:COMPUTERNAME,
    $Sender,
    $Message = (Get-Date),
    $ImageFile
)

function New-ToastNotification {

    param($Sender, $Message, $ImageBase64)

    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

    $audioSource = "ms-winsoundevent:Notification.Default"
    $app  = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    
    $RegPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\{0}' -f $app
    if (!(Test-Path -Path $RegPath)) {
        $null = New-Item -Path $RegPath -Force
        $null = New-ItemProperty -Path $RegPath -Name ShowInActionCenter -Value 1 -PropertyType DWORD
    }

    if($imageBase64) {
        $imageFile = '{0}{1}.png' -f [System.IO.Path]::GetTempPath(), [guid]::NewGuid().GUID
        [byte[]]$bytes = [convert]::FromBase64String($ImageBase64)
        [System.IO.File]::WriteAllBytes($imageFile, $bytes)
    }
    
    [xml]$toast = @"
<toast duration="long">
    <visual>
    <binding template="ToastGeneric">
        <text>$Sender</text> 
        <image placement="appLogoOverride" hint-crop="circle" src="$imageFile"/>    
        <group>
            <subgroup>
                <text hint-style="title" hint-wrap="true" >$Message</text>
            </subgroup>
        </group>
    </binding>
    </visual>
    <audio src="$audioSource"/>
</toast>
"@

    $xml = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($toast.OuterXml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app).Show($xml)
}


$argumentList = @($Sender, $Message)
if($ImageFile) {
    $bytes = [System.IO.File]::ReadAllBytes($ImageFile)
    $imageBase64 = [System.Convert]::ToBase64String($bytes)
    $argumentList += $imageBase64
}

Invoke-Command -ComputerName $RemoteComputer -ScriptBlock ${function:New-ToastNotification} -ArgumentList $argumentList