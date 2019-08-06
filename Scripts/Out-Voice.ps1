function Out-Voice {
    [cmdletbinding()]
    PARAM(
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string] $Message = 'Hello Martin!',
        [ValidateSet('DAVID', 'HAZEL', 'ZIRA')] [string] $Voice = 'DAVID',
        [string] $OutputToWaveFile,
        [switch] $Drunk
    )
    Add-Type -AssemblyName System.speech
    $speak = New-Object System.Speech.Synthesis.SpeechSynthesizer

    $VoiceId = $speak.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Id -like "*$Voice*" }
    if ($VoiceId) { $speak.SelectVoice($VoiceId.VoiceInfo.Name) }
    if ($Drunk) { $speak.Rate = -10 }
    if ($OutputToWaveFile) { $speak.SetOutputToWaveFile($OutputToWaveFile) }
    $speak.Speak($Message)
    $speak.Dispose()
}; New-Alias -Name ov -Value Out-Voice

Out-Voice -Message 'Backup completed' -Voice DAVID
Out-Voice -Message 'Installation failed' -Voice HAZEL
Out-Voice -Message 'Critical alert' -Voice ZIRA -OutputToWaveFile 'C:\Temp\CriticalAlert.wav'
'Too much beer causes bad scripting' | Out-Voice -Drunk