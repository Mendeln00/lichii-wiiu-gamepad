<#
.SYNOPSIS
    Measures what a process-loopback capture receives while the target process is muted in the Windows volume mixer.
.DESCRIPTION
    Captures the audio of one process tree with the Windows process-loopback API
    (AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK, Windows 10 build 20348 or later). A bridge such as
    Toffee would use the same API to take only Lichii's audio.

    While capturing, the script changes the audio sessions of the process in four phases: normal, muted,
    10 % volume, normal again. It uses ISimpleAudioVolume, the interface behind the per-app sliders and
    mute buttons of the Windows volume mixer. For every phase it reports packets, silent packets, peak
    and RMS level. At the end it restores the original volume and mute state.

    Research tool for issue #15, see research/audio-isolation.md. Needs no build and no installation.
    Loads LoopbackProbe.cs from the same folder.
.PARAMETER ProcessName
    Name of the process to capture, without .exe. Defaults to lichii.
.PARAMETER ProcessId
    ID of the process to capture, if several processes share the name.
.PARAMETER SelfTest
    Instead of Lichii, start a child process that plays a 440 Hz tone at -30 dBFS on ToneDevice and
    measure that. Checks the script and the Windows behaviour without Lichii.
.PARAMETER ToneDevice
    Playback device for the self-test tone, by its Core Audio name, e.g. "CABLE Input (VB-Audio Virtual Cable)".
    Defaults to the Windows default device: the tone is then audible, quietly.
.PARAMETER PhaseSeconds
    Length of each phase in seconds. Defaults to 5.
.PARAMETER Polling
    Read the capture buffer by polling every 10 ms instead of waiting on an event handle, the way Toffee reads.
.PARAMETER WavPath
    Also write everything captured (48 kHz, 16 bit, stereo) to this WAV file, for listening or for Audacity.
.PARAMETER PlayTone
    Internal: plays the self-test tone. Used by -SelfTest for its child process.
.EXAMPLE
    .\Measure-ProcessLoopback.ps1 -WavPath "$env:TEMP\lichii-loopback.wav"
.EXAMPLE
    .\Measure-ProcessLoopback.ps1 -SelfTest -ToneDevice 'CABLE Input (VB-Audio Virtual Cable)'
.EXAMPLE
    .\Measure-ProcessLoopback.ps1 -Polling
#>
[CmdletBinding(DefaultParameterSetName = 'ByName')]
param(
    [Parameter(ParameterSetName = 'ByName')][string]$ProcessName = 'lichii',
    [Parameter(ParameterSetName = 'ById', Mandatory)][int]$ProcessId,
    [Parameter(ParameterSetName = 'SelfTest', Mandatory)][switch]$SelfTest,
    [Parameter(ParameterSetName = 'SelfTest')][Parameter(ParameterSetName = 'Tone')][string]$ToneDevice,
    [ValidateRange(1, 60)][int]$PhaseSeconds = 5,
    [switch]$Polling,
    [string]$WavPath,
    [Parameter(ParameterSetName = 'Tone', Mandatory)][switch]$PlayTone
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Core Audio interop shared with Measure-DeviceLoopback.ps1.
if (-not ('LoopbackProbe.LoopbackCapture' -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'LoopbackProbe.cs')
}

if ($PlayTone) {
    [LoopbackProbe.Tone]::Play($ToneDevice, -30, 300)
    return
}

function Format-Level {
    param([double]$Value)
    if ([double]::IsNegativeInfinity($Value)) { return 'Stille' }
    return [Math]::Round($Value, 1)
}

$build = [int](Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
if ($build -lt 20348) {
    throw "Prozess-Loopback braucht Windows 10 Build 20348 oder neuer, dieser PC hat Build $build."
}

$toneProcess = $null
if ($SelfTest) {
    $shell = (Get-Process -Id $PID).Path
    $toneArguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -PlayTone' -f $PSCommandPath
    if ($ToneDevice) { $toneArguments += ' -ToneDevice "{0}"' -f $ToneDevice }
    $toneProcess = Start-Process -FilePath $shell -ArgumentList $toneArguments -WindowStyle Hidden -PassThru
    $targetId = $toneProcess.Id
    $targetLabel = "Testton (Prozess $targetId, Gerät: $(if ($ToneDevice) { $ToneDevice } else { 'Standardgerät' }))"
    Start-Sleep -Seconds 3
    if ($toneProcess.HasExited) { throw "Der Testton-Prozess hat sich gleich beendet. Stimmt der Gerätename '$ToneDevice'?" }
}
elseif ($PSCmdlet.ParameterSetName -eq 'ById') {
    $targetId = $ProcessId
    $targetLabel = "Prozess $targetId ($((Get-Process -Id $ProcessId).ProcessName))"
}
else {
    $candidates = @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
    if ($candidates.Count -eq 0) { throw "Kein Prozess '$ProcessName' gefunden. Lichii mit einem Spiel starten, das durchgehend Ton macht." }
    if ($candidates.Count -gt 1) { throw "Mehrere Prozesse '$ProcessName': $($candidates.Id -join ', '). Einen mit -ProcessId wählen." }
    $targetId = $candidates[0].Id
    $targetLabel = "$ProcessName (Prozess $targetId)"
}

$snapshot = $null
$capture = $null
$results = @()
try {
    $snapshot = [LoopbackProbe.SessionSnapshot]::Take([uint32]$targetId)
    if ($snapshot.Count -eq 0) {
        throw "Prozess $targetId hat keine Tonsitzung. Läuft das Spiel und macht es gerade Ton?"
    }
    $before = $snapshot.Describe()

    $capture = [LoopbackProbe.LoopbackCapture]::ForProcess([uint32]$targetId, [bool]$Polling, [bool]$WavPath)
    $capture.Start()

    $phases = @(
        @{ Name = 'normal'; Mute = $false; Level = -1 },
        @{ Name = 'stumm'; Mute = $true; Level = -1 },
        @{ Name = 'leise (10 %)'; Mute = $false; Level = 0.1 },
        @{ Name = 'normal (zurück)'; Mute = $false; Level = -1 }
    )
    foreach ($phase in $phases) {
        $snapshot.Apply($phase.Mute, $phase.Level)
        # Let the change settle; this half second is not counted.
        Start-Sleep -Milliseconds 500
        $stats = New-Object LoopbackProbe.PhaseStats
        $stats.Name = $phase.Name
        $capture.BeginPhase($stats)
        Start-Sleep -Seconds $PhaseSeconds
        $capture.EndPhase()
        $results += $stats
        if ($capture.Error) { throw "Die Aufnahme brach ab: $($capture.Error.Message)" }
    }
}
finally {
    $after = 'unbekannt'
    if ($snapshot) {
        $snapshot.Restore()
        try { $after = [LoopbackProbe.SessionSnapshot]::Take([uint32]$targetId).Describe() } catch { $after = "nicht lesbar: $($_.Exception.Message)" }
    }
    if ($capture) { $capture.Stop() }
    if ($toneProcess -and -not $toneProcess.HasExited) { Stop-Process -Id $toneProcess.Id -Force }
}

if ($WavPath) {
    $capture.SaveWav($WavPath)
}

$windows = Get-CimInstance -ClassName Win32_OperatingSystem
Write-Output ''
Write-Output "Ziel:      $targetLabel"
Write-Output "Windows:   $($windows.Caption) Build $($windows.BuildNumber)"
Write-Output "Lesen:     $(if ($Polling) { 'Abfragen alle 10 ms (wie Toffee)' } else { 'Ereignis-Handle (wie das Microsoft-Beispiel)' })"
Write-Output "Sitzungen: $($snapshot.Count). Vorher: $before. Nachher: $after"
if ($WavPath) { Write-Output "WAV:       $WavPath" }

$results | ForEach-Object {
    [pscustomobject]@{
        Phase           = $_.Name
        Pakete          = $_.Packets
        'Stille Pakete' = $_.SilentPackets
        'Spitze dBFS'   = Format-Level $_.PeakDbfs
        'RMS dBFS'      = Format-Level $_.RmsDbfs
    }
} | Format-Table -AutoSize | Out-String

$normal, $muted, $quiet = $results[0], $results[1], $results[2]
if ($normal.Packets -eq 0) {
    Write-Output 'Ergebnis: Der Prozess-Loopback lieferte keine Pakete. Die Messung taugt nicht.'
}
elseif ($normal.RmsDbfs -lt -70) {
    Write-Output 'Ergebnis: In Phase normal kam fast kein Ton an. Mit einer Stelle im Spiel wiederholen, die durchgehend Ton macht.'
}
else {
    # Below -80 dBFS counts as silence: muted streams still carry rounding noise of about 1 LSB (-90 dBFS peak).
    if ($muted.RmsDbfs -lt -80) {
        Write-Output 'Ergebnis: Stummschalten wirkt auch auf den Prozess-Loopback. Die Brücke bekäme Stille. Lichii braucht weiter ein eigenes stilles Gerät.'
    }
    elseif ([Math]::Abs($normal.RmsDbfs - $muted.RmsDbfs) -lt 6) {
        Write-Output 'Ergebnis: Stummschalten wirkt NICHT auf den Prozess-Loopback. Die Brücke bekäme den Spielton trotzdem.'
    }
    else {
        Write-Output ('Ergebnis: unklar. Stumm liegt {0} dB unter normal. Messung wiederholen.' -f [Math]::Round($normal.RmsDbfs - $muted.RmsDbfs, 1))
    }
    if ($quiet.RmsDbfs -gt -90) {
        Write-Output ('Lautstärke 10 %: Pegel {0} dB unter normal. Erwartet sind etwa 20 dB, wenn der Mixer auf den Loopback wirkt, und etwa 0 dB, wenn nicht.' -f [Math]::Round($normal.RmsDbfs - $quiet.RmsDbfs, 1))
    }
}
