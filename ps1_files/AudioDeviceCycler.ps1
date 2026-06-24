$device1 = "DEVICE NAME HERE"
$device2 = "DEVICE NAME HERE"

$Audio = Get-AudioDevice -playback

if ($Audio.Name.StartsWith($device1))
{
   (Get-AudioDevice -list | Where-Object Name -like ("$device2*") | Set-AudioDevice).Name
}
Else
{
   (Get-AudioDevice -list | Where-Object Name -like ("$device1*") | Set-AudioDevice).Name
}

# Play a sound to confirm the change
$PlayWav = New-Object System.Media.SoundPlayer

$PlayWav.SoundLocation = "C:\Windows\Media\Windows User Account Control.wav"

$PlayWav.playsync()