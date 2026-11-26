<#
.SYNOPSIS
    Measures what a device-loopback capture of one playback device receives.
.DESCRIPTION
    Captures one playback device in WASAPI loopback mode, the way Toffee and Apollo take the audio of a
    device. The device is chosen by its Core Audio name, the same name Lichii's output_device uses.

    Without -SelfTest the script records whatever plays on the device, for example Lichii.

    With -SelfTest it plays a 440 Hz tone at -30 dBFS itself, in three phases: tone on the device, no tone,
    and the tone on the Windows default device as a cross-check. The cross-check is quietly audible.
    For every phase it reports packets, silent packets, peak and RMS level.

    The script never changes the default device. It reports it before and after the measurement, so a switch
    by a driver installation or another program shows up.

    Research tool for issue #44, see research/audio-isolation.md. Needs no build, no installation and no
    admin rights. Loads LoopbackProbe.cs from the same folder.
.PARAMETER Device
    Playback device to capture, by its Core Audio name, e.g. "CABLE Input (VB-Audio Virtual Cable)".
.PARAMETER SelfTest
    Play a test tone instead of measuring what already plays on the device.
.PARAMETER PhaseSeconds
    Length of each phase in seconds. Defaults to 5.
.PARAMETER Polling
    Read the capture buffer by polling every 10 ms instead of waiting on an event handle, the way Toffee reads.
.PARAMETER WavPath
    Also write everything captured (48 kHz, 16 bit, stereo) to this WAV file, for listening or for Audacity.
.EXAMPLE
    .\Measure-DeviceLoopback.ps1 -Device 'CABLE Input (VB-Audio Virtual Cable)' -SelfTest
.EXAMPLE
    .\Measure-DeviceLoopback.ps1 -Device 'CABLE Input (VB-Audio Virtual Cable)' -WavPath "$env:TEMP\device-loopback.wav"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Device,
    [switch]$SelfTest,
    [ValidateRange(1, 60)][int]$PhaseSeconds = 5,
    [switch]$Polling,
    [string]$WavPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Core Audio interop shared with Measure-ProcessLoopback.ps1.
if (-not ('LoopbackProbe.LoopbackCapture' -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'LoopbackProbe.cs')
}

function Format-Level {
    param([double]$Value)
    if ([double]::IsNegativeInfinity($Value)) { return 'Stille' }
    return [Math]::Round($Value, 1)
}

function Format-Process {
    param([uint32[]]$ProcessIds)
    if (-not $ProcessIds) { return 'keine' }
    $names = foreach ($id in $ProcessIds) {
        $process = Get-Process -Id $id -ErrorAction SilentlyContinue
        if ($process) { "$($process.ProcessName) ($id)" } else { "Prozess $id" }
    }
    return $names -join ', '
}

function Measure-Phase {
    param($Capture, [string]$Name, [int]$Seconds)
    # Let the change settle; this half second is not counted.
    Start-Sleep -Milliseconds 500
    $stats = New-Object LoopbackProbe.PhaseStats
    $stats.Name = $Name
    $Capture.BeginPhase($stats)
    Start-Sleep -Seconds $Seconds
    $Capture.EndPhase()
    if ($Capture.Error) { throw "Die Aufnahme brach ab: $($Capture.Error.Message)" }
    return $stats
}

# cubeb and SDL3 in Lichii compare the name exactly, so this does too.
$active = @([LoopbackProbe.Devices]::Active())
$matching = @($active | Where-Object { $_.Name -ceq $Device })
if ($matching.Count -eq 0) {
    throw "Kein aktives Wiedergabegerät heißt '$Device'. Aktive Wiedergabegeräte: $(($active | ForEach-Object { "'$($_.Name)'" }) -join ', ')"
}
$target = $matching[0]
$defaultBefore = [LoopbackProbe.Devices]::Default()
$isDefault = $target.Id -eq $defaultBefore.Id
$others = @([LoopbackProbe.Sessions]::ActiveProcessIds($Device) | Where-Object { $_ -ne $PID })

$capture = [LoopbackProbe.LoopbackCapture]::ForDevice($Device, [bool]$Polling, [bool]$WavPath)
$tone = $null
$results = @()
try {
    $capture.Start()
    if ($SelfTest) {
        $tone = [LoopbackProbe.Tone]::Start($Device, -30)
        $results += Measure-Phase $capture 'Testton auf dem Gerät' $PhaseSeconds
        $tone.Stop()
        $tone = $null
        $results += Measure-Phase $capture 'ohne Ton' $PhaseSeconds
        if (-not $isDefault) {
            $tone = [LoopbackProbe.Tone]::Start('', -30)
            $results += Measure-Phase $capture 'Testton auf dem Standardgerät' $PhaseSeconds
            $tone.Stop()
            $tone = $null
        }
    }
    else {
        $results += Measure-Phase $capture 'Aufnahme' $PhaseSeconds
    }
}
finally {
    if ($tone) { $tone.Stop() }
    $capture.Stop()
}
$defaultAfter = [LoopbackProbe.Devices]::Default()

if ($WavPath) {
    $capture.SaveWav($WavPath)
}

$windows = Get-CimInstance -ClassName Win32_OperatingSystem
Write-Output ''
Write-Output "Gerät:          $($target.Name)$(if ($isDefault) { ' (ist das Standardgerät)' })"
Write-Output "Geräte-ID:      $($target.Id)"
if ($matching.Count -gt 1) { Write-Output "Achtung:        $($matching.Count) aktive Geräte heißen so. Gemessen wurde das erste." }
Write-Output "Windows:        $($windows.Caption) Build $($windows.BuildNumber)"
Write-Output "Lesen:          $(if ($Polling) { 'Abfragen alle 10 ms (wie Toffee)' } else { 'Ereignis-Handle' })"
Write-Output "Spielt vorher:  $(Format-Process $others)"
Write-Output "Standardgerät:  vorher $($defaultBefore.Name), nachher $($defaultAfter.Name)"
if ($WavPath) { Write-Output "WAV:            $WavPath" }

$results | ForEach-Object {
    [pscustomobject]@{
        Phase           = $_.Name
        Pakete          = $_.Packets
        'Stille Pakete' = $_.SilentPackets
        'Spitze dBFS'   = Format-Level $_.PeakDbfs
        'RMS dBFS'      = Format-Level $_.RmsDbfs
    }
} | Format-Table -AutoSize | Out-String

# Below -80 dBFS counts as silence: converted streams carry rounding noise of about 1 LSB (-90 dBFS peak).
if ($SelfTest) {
    $toneOn, $silent = $results[0], $results[1]
    if ($toneOn.Packets -eq 0) {
        Write-Output 'Ergebnis: Der Geräte-Loopback lieferte keine Pakete. Die Messung taugt nicht.'
    }
    elseif ($toneOn.RmsDbfs -lt -80) {
        Write-Output 'Ergebnis: Der Testton kam nicht an. Der Geräte-Loopback liefert keinen Ton dieses Geräts.'
    }
    else {
        Write-Output ('Ergebnis: Der Geräte-Loopback liefert den Ton dieses Geräts, {0} dBFS RMS. Gespielt wurden etwa -33 dBFS RMS.' -f (Format-Level $toneOn.RmsDbfs))
    }

    if ($silent.Packets -eq 0) {
        Write-Output 'Ohne Ton:  Der Loopback liefert keine Pakete, solange nichts spielt. Die Brücke muss die Lücke selbst füllen.'
    }
    elseif ($silent.SilentPackets -eq $silent.Packets) {
        Write-Output ('Ohne Ton:  Der Loopback liefert weiter Pakete, als still markiert ({0} in {1} s).' -f $silent.Packets, $PhaseSeconds)
    }
    elseif ($silent.RmsDbfs -lt -80) {
        Write-Output ('Ohne Ton:  Der Loopback liefert weiter Pakete mit Stille ({0} in {1} s, {2} als still markiert).' -f $silent.Packets, $PhaseSeconds, $silent.SilentPackets)
    }
    else {
        Write-Output ('Ohne Ton:  Es kam trotzdem Ton an, {0} dBFS RMS. Spielt noch etwas anderes auf dem Gerät?' -f (Format-Level $silent.RmsDbfs))
    }

    if ($isDefault) {
        Write-Output 'Gegenprobe: entfällt, das Gerät ist das Standardgerät.'
    }
    else {
        $cross = $results[2]
        if ($cross.Packets -eq 0 -or $cross.RmsDbfs -lt -80) {
            Write-Output 'Gegenprobe: Der Testton auf dem Standardgerät fehlt in der Aufnahme. Der Loopback nimmt nur dieses Gerät auf.'
        }
        else {
            Write-Output ('Gegenprobe: Die Aufnahme enthält Ton, während der Testton auf dem Standardgerät spielt, {0} dBFS RMS. Prüfen, ob noch etwas auf dem Gerät spielt.' -f (Format-Level $cross.RmsDbfs))
        }
    }
}
else {
    $recording = $results[0]
    if ($recording.Packets -eq 0) {
        Write-Output 'Ergebnis: keine Pakete. Auf dem Gerät spielt gerade nichts.'
    }
    elseif ($recording.RmsDbfs -lt -80) {
        Write-Output 'Ergebnis: nur Stille. Auf dem Gerät spielt gerade nichts Hörbares.'
    }
    else {
        Write-Output ('Ergebnis: Auf dem Gerät kommt Ton an, {0} dBFS RMS.' -f (Format-Level $recording.RmsDbfs))
    }
}

if ($defaultBefore.Id -eq $defaultAfter.Id) {
    Write-Output "Standardgerät: unverändert, $($defaultAfter.Name)."
}
else {
    Write-Output "Standardgerät: ACHTUNG, während der Messung gewechselt, von $($defaultBefore.Name) zu $($defaultAfter.Name)."
}
