<#
.SYNOPSIS
    Plays the DSU server of the bridge on this PC: answers Lichii's DSU requests and sends scripted
    buttons, sticks, motion and touch for one pad.
.DESCRIPTION
    Listens on UDP 127.0.0.1:26760, where Toffee listens too, and speaks the Cemuhook protocol,
    version 1001. It answers version, pad info and pad data requests. Slot 0 is a connected pad with
    full gyro, slots 1 to 3 are not connected. Pad data for slot 0 goes to every client that asked
    for it within the last 5 seconds, Rate times per second, with a packet number per client.

    The pad state comes from a scenario, one step per line: a duration, then what is held during it.
    Everything not named is at rest. "#" starts a comment.

        2s                       nothing held, e.g. time to connect
        1s    Circle             a button (several: "Circle Cross")
        1s    LeftStick=right    right, left, up, down or x,y from -1 to 1, +y up
        2s    Gyro=0,90,0        pitch, yaw, roll in deg/s
        1s    Accel=1,0,0        x, y, z in g, at rest 0,-1,0
        0.3s  Touch=960,470      first finger at x,y. Second finger: Touch2=x,y
        500ms Home

    Buttons: Circle, Cross, Triangle, Square, Up, Down, Left, Right, L1, R1, L2, R2, L3, R3,
    Options, Share, Home, TouchButton. Without -ScenarioPath or -Steps the script plays DsuTour.txt
    from this folder, a tour through all inputs. With -Keyboard the keys of this console drive the pad.

    Research tool for issue #60: checks the input profile of #52 and eden-cli (ADR 0007) without
    bridge and GamePad. Needs no build and no installation. Loads DsuProbe.cs from the same folder.
.PARAMETER ScenarioPath
    Scenario file to play. Defaults to DsuTour.txt in this folder.
.PARAMETER Steps
    Scenario steps given inline, one string per step, e.g. '30s', '0.2s Circle'.
.PARAMETER Loop
    Repeat the scenario until Esc or Ctrl+C.
.PARAMETER Keyboard
    Drive the pad with the keys of this console until Esc. A key press holds its input for 0.5 s,
    holding the key down keeps it as long as Windows repeats the key.
    Face buttons I J K L (Triangle, Square, Cross, Circle), D-pad arrow keys, left stick W A S D,
    right stick T F G H, L1 Q, R1 E, L2 Z, R2 C, L3 X, R3 V, Options Enter, Share Backspace,
    Home Pos1, TouchButton B, gyro yaw N and M, touch P (centre).
.PARAMETER SelfTest
    Start the server on a free port, query it with a built-in DSU client the way Lichii does and check
    every answer: magic, version, length, CRC32, packet numbers, the scripted values and the timeout.
.PARAMETER Address
    Address to listen on. Defaults to 127.0.0.1, so only this PC reaches the server.
.PARAMETER Port
    UDP port to listen on. Defaults to 26760, Lichii's default for udp_input_servers.
.PARAMETER Rate
    Pad data messages per second and client. Defaults to 100.
.EXAMPLE
    .\Start-DsuTestServer.ps1
.EXAMPLE
    .\Start-DsuTestServer.ps1 -Steps '30s', '0.2s Circle', '2s', '0.2s Circle' -Loop
.EXAMPLE
    .\Start-DsuTestServer.ps1 -Keyboard
.EXAMPLE
    .\Start-DsuTestServer.ps1 -SelfTest
#>
[CmdletBinding(DefaultParameterSetName = 'Scenario')]
param(
    [Parameter(ParameterSetName = 'Scenario')][string]$ScenarioPath,
    [Parameter(ParameterSetName = 'Steps', Mandatory)][string[]]$Steps,
    [Parameter(ParameterSetName = 'Scenario')][Parameter(ParameterSetName = 'Steps')][switch]$Loop,
    [Parameter(ParameterSetName = 'Keyboard', Mandatory)][switch]$Keyboard,
    [Parameter(ParameterSetName = 'SelfTest', Mandatory)][switch]$SelfTest,
    [string]$Address = '127.0.0.1',
    [ValidateRange(0, 65535)][int]$Port = 26760,
    [ValidateRange(1, 1000)][int]$Rate = 100
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not ('DsuProbe.Server' -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'DsuProbe.cs')
}

# Lichii turns the DSU accelerometer y into the Switch z axis, and a Switch pad lying flat reads
# z = -1 g (udp_client.cpp L263-265 and sdl_driver.cpp L319-321, Lichii fdc7cdaf). Hence 0,-1,0.
$script:RestAccel = @(0.0, -1.0, 0.0)
$script:ButtonNames = @([enum]::GetNames([DsuProbe.DsuButtons]) | Where-Object { $_ -ne 'None' })
$script:StickWords = @{ right = @(1.0, 0.0); left = @(-1.0, 0.0); up = @(0.0, 1.0); down = @(0.0, -1.0); center = @(0.0, 0.0) }
$script:SeenEvents = @{}

function ConvertTo-DsuNumber {
    param([string]$Text, [double]$Min, [double]$Max, [string]$Where)
    $value = 0.0
    $ok = [double]::TryParse($Text, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value)
    if (-not $ok -or $value -lt $Min -or $value -gt $Max) {
        throw "$Where`: '$Text' ist keine Zahl von $Min bis $Max (Dezimalpunkt, nicht Komma)."
    }
    return $value
}

function ConvertTo-DsuVector {
    param([string]$Text, [int]$Count, [double]$Min, [double]$Max, [string]$Where)
    $parts = @($Text -split ',')
    if ($parts.Count -ne $Count) {
        throw "$Where`: '$Text' braucht $Count durch Komma getrennte Werte."
    }
    return @($parts | ForEach-Object { ConvertTo-DsuNumber -Text $_.Trim() -Min $Min -Max $Max -Where $Where })
}

function ConvertTo-DsuStickByte {
    # -1..1 to 0..255 with 128 at rest, as the protocol description asks. +1 gives 255, -1 gives 1.
    param([double]$Value)
    return [byte][Math]::Round(128 + 127 * $Value)
}

function ConvertFrom-DsuScenario {
    <#
    .SYNOPSIS
        Parses scenario lines into steps with duration, pad state and a short summary. Pure function.
    #>
    param([AllowEmptyString()][AllowEmptyCollection()][string[]]$Line)

    $result = @()
    $touchId = @(0, 0)
    $touchBefore = @($false, $false)
    for ($i = 0; $i -lt $Line.Count; $i++) {
        $text = ($Line[$i] -replace '#.*$', '').Trim()
        if (-not $text) { continue }
        $where = "Zeile $($i + 1) ('$text')"
        $tokens = @($text -split '\s+')

        if ($tokens[0] -notmatch '^(?<n>\d+(\.\d+)?)(?<unit>ms|s)$') {
            throw "$where`: Ein Schritt beginnt mit der Dauer, etwa '1s', '0.5s' oder '200ms'."
        }
        $durationMs = [double]::Parse($Matches.n, [Globalization.CultureInfo]::InvariantCulture)
        if ($Matches.unit -eq 's') { $durationMs *= 1000 }

        $state = New-Object DsuProbe.PadState
        $state.AccelX, $state.AccelY, $state.AccelZ = $script:RestAccel
        $buttons = 0
        $touch = @($null, $null)

        foreach ($token in @($tokens | Select-Object -Skip 1)) {
            if ($token -match '^(?<name>[A-Za-z0-9]+)=(?<value>.+)$') {
                $name, $value = $Matches.name, $Matches.value
                switch ($name) {
                    { $_ -in 'LeftStick', 'RightStick' } {
                        $xy = if ($script:StickWords.ContainsKey($value)) { $script:StickWords[$value] } else { ConvertTo-DsuVector -Text $value -Count 2 -Min -1 -Max 1 -Where $where }
                        if ($name -eq 'LeftStick') {
                            $state.LeftX = ConvertTo-DsuStickByte $xy[0]
                            $state.LeftY = ConvertTo-DsuStickByte $xy[1]
                        }
                        else {
                            $state.RightX = ConvertTo-DsuStickByte $xy[0]
                            $state.RightY = ConvertTo-DsuStickByte $xy[1]
                        }
                    }
                    'Gyro' {
                        $state.GyroPitch, $state.GyroYaw, $state.GyroRoll = ConvertTo-DsuVector -Text $value -Count 3 -Min -2000 -Max 2000 -Where $where
                    }
                    'Accel' {
                        $state.AccelX, $state.AccelY, $state.AccelZ = ConvertTo-DsuVector -Text $value -Count 3 -Min -8 -Max 8 -Where $where
                    }
                    { $_ -in 'Touch', 'Touch1', 'Touch2' } {
                        $finger = if ($name -eq 'Touch2') { 1 } else { 0 }
                        $touch[$finger] = ConvertTo-DsuVector -Text $value -Count 2 -Min 0 -Max 65535 -Where $where
                    }
                    default {
                        throw "$where`: unbekannte Eingabe '$name='. Erlaubt: LeftStick=, RightStick=, Gyro=, Accel=, Touch=, Touch2=."
                    }
                }
            }
            elseif ($token -eq 'Home') { $state.Home = $true }
            elseif ($token -eq 'TouchButton') { $state.TouchButton = $true }
            elseif ($script:ButtonNames -contains $token) {
                $canonical = $script:ButtonNames | Where-Object { $_ -eq $token } | Select-Object -First 1
                $buttons = $buttons -bor [int][DsuProbe.DsuButtons]$canonical
            }
            else {
                throw "$where`: unbekannte Taste '$token'. Erlaubt: $($script:ButtonNames -join ', '), Home, TouchButton."
            }
        }
        $state.Buttons = [DsuProbe.DsuButtons]$buttons

        # A finger keeps its touch ID while it stays down and gets a new one when it lands again.
        for ($f = 0; $f -lt 2; $f++) {
            $active = $null -ne $touch[$f]
            if ($active -and -not $touchBefore[$f]) { $touchId[$f] = ($touchId[$f] + 1) % 256 }
            $touchBefore[$f] = $active
            if (-not $active) { continue }
            if ($f -eq 0) {
                $state.Touch1Active = $true
                $state.Touch1Id = $touchId[0]
                $state.Touch1X, $state.Touch1Y = [uint16]$touch[0][0], [uint16]$touch[0][1]
            }
            else {
                $state.Touch2Active = $true
                $state.Touch2Id = $touchId[1]
                $state.Touch2X, $state.Touch2Y = [uint16]$touch[1][0], [uint16]$touch[1][1]
            }
        }

        $result += [pscustomobject]@{
            Line       = $i + 1
            Text       = $text
            DurationMs = $durationMs
            State      = $state
            Summary    = Format-DsuPadState -State $state
        }
    }
    return , $result
}

function Get-DsuRestState {
    return (ConvertFrom-DsuScenario -Line '0s')[0].State
}

function Format-DsuPadState {
    <#
    .SYNOPSIS
        Short summary of what a pad state sends, e.g. "Circle | LeftStick 255/128". Pure function.
    #>
    param([object]$State)

    $parts = @()
    if ($State.Buttons -ne [DsuProbe.DsuButtons]::None) { $parts += ($State.Buttons.ToString() -replace ', ', '+') }
    if ($State.Home) { $parts += 'Home' }
    if ($State.TouchButton) { $parts += 'TouchButton' }
    if ($State.LeftX -ne 128 -or $State.LeftY -ne 128) { $parts += 'LeftStick {0}/{1}' -f $State.LeftX, $State.LeftY }
    if ($State.RightX -ne 128 -or $State.RightY -ne 128) { $parts += 'RightStick {0}/{1}' -f $State.RightX, $State.RightY }
    $invariant = [Globalization.CultureInfo]::InvariantCulture
    if ($State.GyroPitch -ne 0 -or $State.GyroYaw -ne 0 -or $State.GyroRoll -ne 0) {
        $parts += [string]::Format($invariant, 'Gyro {0}/{1}/{2} Grad/s', $State.GyroPitch, $State.GyroYaw, $State.GyroRoll)
    }
    if ($State.AccelX -ne $script:RestAccel[0] -or $State.AccelY -ne $script:RestAccel[1] -or $State.AccelZ -ne $script:RestAccel[2]) {
        $parts += [string]::Format($invariant, 'Accel {0}/{1}/{2} g', $State.AccelX, $State.AccelY, $State.AccelZ)
    }
    if ($State.Touch1Active) { $parts += 'Touch {0},{1} (ID {2})' -f $State.Touch1X, $State.Touch1Y, $State.Touch1Id }
    if ($State.Touch2Active) { $parts += 'Touch2 {0},{1} (ID {2})' -f $State.Touch2X, $State.Touch2Y, $State.Touch2Id }
    if ($parts.Count -eq 0) { return 'Ruhe' }
    return $parts -join ' | '
}

function Format-DsuEvent {
    <#
    .SYNOPSIS
        German text for one server event. Pure function.
    #>
    param([object]$ServerEvent, [int]$TimeoutSeconds)

    $reasons = @{
        short   = 'zu kurz'
        magic   = 'falsches Magic, nicht DSUC'
        version = 'andere Protokollversion als 1001'
        length  = 'falsche Länge für den Nachrichtentyp'
        crc     = 'CRC32 stimmt nicht'
        type    = 'Nachrichtentyp nicht unterstützt'
    }
    $client = $ServerEvent.Client
    switch ($ServerEvent.Kind.ToString()) {
        'ClientAdded' { "Neuer Client $client" }
        'ClientExpired' { "Client $client hat $TimeoutSeconds s keine Pad-Daten angefragt, Senden beendet" }
        'VersionRequest' { "$client fragt die Version an, Antwort 1001" }
        'PortInfoRequest' { "$client fragt Pad-Info an, Slots $($ServerEvent.Detail)" }
        'PadDataRequest' {
            $which = switch -Regex ($ServerEvent.Detail) { '^all$' { 'alle Pads' } '^slot (\d+)' { "Slot $($Matches[1])" } default { $ServerEvent.Detail -replace '^mac ', 'MAC ' } }
            if ($ServerEvent.Accepted) { "$client fragt Pad-Daten an ($which), Slot 0 sendet" }
            else { "$client fragt Pad-Daten an ($which), dort ist kein Pad verbunden" }
        }
        'Invalid' {
            $code, $type, $length = $ServerEvent.Detail -split ' '
            $reason = if ($reasons.ContainsKey($code)) { $reasons[$code] } else { $code }
            $typeText = if ($type -ne '0') { "Typ 0x$type, " } else { '' }
            "Ungültiges Paket von $client verworfen: $reason ($typeText$length Bytes)"
        }
        default { "Socket-Fehler ($client): $($ServerEvent.Detail)" }
    }
}

function Show-DsuEvent {
    # Prints new server events. Requests repeat every few seconds, so each kind shows once per client.
    param([object]$Server)
    foreach ($e in $Server.DrainEvents()) {
        $kind = $e.Kind.ToString()
        if ($kind -like '*Request') {
            $key = '{0}|{1}|{2}|{3}' -f $e.Client, $kind, $e.Detail, $e.Accepted
            if ($script:SeenEvents.ContainsKey($key)) { continue }
            $script:SeenEvents[$key] = $true
        }
        elseif ($kind -eq 'ClientExpired') {
            # The client may come back later, then its requests show again.
            @($script:SeenEvents.Keys) | Where-Object { $_ -like "$($e.Client)|*" } | ForEach-Object { $script:SeenEvents.Remove($_) }
        }
        '{0,8:N1} s  {1}' -f $e.Time.TotalSeconds, (Format-DsuEvent -ServerEvent $e -TimeoutSeconds ($Server.ClientTimeoutMs / 1000))
    }
}

function Test-DsuEscape {
    # True when Esc was pressed in this console. False without an interactive console.
    try {
        while ([Console]::KeyAvailable) {
            if ([Console]::ReadKey($true).Key -eq [ConsoleKey]::Escape) { return $true }
        }
    }
    catch [System.InvalidOperationException] {
        return $false
    }
    return $false
}

function Invoke-DsuScenario {
    param([object]$Server, [object[]]$Step, [switch]$Loop)

    $round = 0
    do {
        $round++
        $start = $Server.Elapsed.TotalMilliseconds
        $offset = 0.0
        for ($i = 0; $i -lt $Step.Count; $i++) {
            $s = $Step[$i]
            $Server.SetState($s.State)
            $label = if ($Loop) { "Runde $round, Schritt $($i + 1)/$($Step.Count)" } else { "Schritt $($i + 1)/$($Step.Count)" }
            '{0,8:N1} s  {1}, {2:N1} s: {3}' -f $Server.Elapsed.TotalSeconds, $label, ($s.DurationMs / 1000), $s.Summary
            $offset += $s.DurationMs
            while (($left = $start + $offset - $Server.Elapsed.TotalMilliseconds) -gt 0) {
                Show-DsuEvent -Server $Server
                if (Test-DsuEscape) { $Server.SetState((Get-DsuRestState)); return }
                Start-Sleep -Milliseconds ([int][Math]::Min(50, [Math]::Ceiling($left)))
            }
        }
    } while ($Loop)
    $Server.SetState((Get-DsuRestState))
    Show-DsuEvent -Server $Server
}

function Invoke-DsuKeyboard {
    param([object]$Server)

    $map = @{
        L = 'Circle'; K = 'Cross'; I = 'Triangle'; J = 'Square'
        UpArrow = 'Up'; DownArrow = 'Down'; LeftArrow = 'Left'; RightArrow = 'Right'
        Q = 'L1'; E = 'R1'; Z = 'L2'; C = 'R2'; X = 'L3'; V = 'R3'
        Enter = 'Options'; Backspace = 'Share'; Home = 'Home'; B = 'TouchButton'
        W = 'LS+y'; S = 'LS-y'; A = 'LS-x'; D = 'LS+x'
        T = 'RS+y'; G = 'RS-y'; F = 'RS-x'; H = 'RS+x'
        N = 'Yaw-'; M = 'Yaw+'; P = 'Touch'
    }
    try { $null = [Console]::KeyAvailable }
    catch [System.InvalidOperationException] { throw 'Für -Keyboard braucht es eine Konsole mit Tastatur, keine umgeleitete Eingabe.' }

    'Tastatur: I J K L Tasten, Pfeile Steuerkreuz, W A S D linker Stick, T F G H rechter Stick, Q E Z C X V Schultern und Klicks,'
    '          Enter Options, Rücktaste Share, Pos1 Home, B TouchButton, N M Gyro, P Touch. Esc beendet.'
    $held = @{}
    $last = $null
    while ($true) {
        $now = $Server.Elapsed.TotalMilliseconds
        while ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true).Key.ToString()
            if ($key -eq 'Escape') { $Server.SetState((Get-DsuRestState)); return }
            if (-not $map.ContainsKey($key)) { continue }
            $action = $map[$key]
            # The first press covers the key repeat delay of Windows, repeats only extend a little.
            $held[$action] = if ($held.ContainsKey($action)) { [Math]::Max($held[$action], $now + 120) } else { $now + 550 }
        }
        foreach ($k in @($held.Keys)) { if ($held[$k] -lt $now) { $held.Remove($k) } }

        $tokens = @('0s')
        $tokens += @($held.Keys | Where-Object { $_ -notmatch '^(LS[+-]|RS[+-]|Yaw[+-]|Touch$)' } | Sort-Object)
        foreach ($stick in 'LS', 'RS') {
            $x = [int]$held.ContainsKey("$stick+x") - [int]$held.ContainsKey("$stick-x")
            $y = [int]$held.ContainsKey("$stick+y") - [int]$held.ContainsKey("$stick-y")
            if ($x -or $y) { $tokens += '{0}={1},{2}' -f @{ LS = 'LeftStick'; RS = 'RightStick' }[$stick], $x, $y }
        }
        $yaw = 90 * ([int]$held.ContainsKey('Yaw+') - [int]$held.ContainsKey('Yaw-'))
        if ($yaw) { $tokens += "Gyro=0,$yaw,0" }
        if ($held.ContainsKey('Touch')) { $tokens += 'Touch=960,470' }

        $line = $tokens -join ' '
        if ($line -ne $last) {
            $step = (ConvertFrom-DsuScenario -Line $line)[0]
            $Server.SetState($step.State)
            '{0,8:N1} s  Tastatur: {1}' -f $Server.Elapsed.TotalSeconds, $step.Summary
            $last = $line
        }
        Show-DsuEvent -Server $Server
        Start-Sleep -Milliseconds 15
    }
}

function Format-DsuClientStat {
    param([object]$Server)
    $stats = @($Server.GetClientStats())
    if ($stats.Count -eq 0) { return 'Kein Client hat angefragt.' }
    $stats | ForEach-Object {
        [pscustomobject]@{
            Client             = $_.Client
            'Version'          = $_.VersionRequests
            'Pad-Info'         = $_.PortInfoRequests
            'Pad-Daten'        = $_.PadDataRequests
            'Pakete gesendet'  = $_.PadPacketsSent
            'Sendet noch'      = if ($_.Streaming) { 'ja' } else { 'nein' }
        }
    } | Format-Table -AutoSize | Out-String
}

function Test-DsuPacketLayout {
    <#
    .SYNOPSIS
        Checks built packets byte by byte against the offsets of the protocol description, without the
        parser of DsuProbe.cs. Pure function, returns one check object.
    #>
    $problems = @()
    $ascii = [Text.Encoding]::ASCII
    $crcCheck = [DsuProbe.Crc32]::Compute($ascii.GetBytes('123456789'), 0, 9)
    if ($crcCheck -ne [Convert]::ToUInt32('CBF43926', 16)) { $problems += 'CRC32 von "123456789" ist nicht CBF43926' }

    $slot = New-Object DsuProbe.SlotInfo
    $slot.State = 2
    $version = [DsuProbe.Protocol]::BuildVersionResponse(7)
    $portInfo = [DsuProbe.Protocol]::BuildPortInfoResponse(7, $slot)
    if ($version.Length -ne 22 -or $version[6] -ne 6 -or $version[20] -ne 0xE9 -or $version[21] -ne 0x03) { $problems += 'Versionsantwort' }
    if ($portInfo.Length -ne 32 -or $portInfo[6] -ne 16 -or $portInfo[21] -ne 2) { $problems += 'Antwort Pad-Info' }

    # Byte offset in the packet (20 bytes of header and type, then the data) and bit of each button.
    $bits = @{
        Share = 36, 0x01; L3 = 36, 0x02; R3 = 36, 0x04; Options = 36, 0x08
        Up = 36, 0x10; Right = 36, 0x20; Down = 36, 0x40; Left = 36, 0x80
        L2 = 37, 0x01; R2 = 37, 0x02; L1 = 37, 0x04; R1 = 37, 0x08
        Triangle = 37, 0x10; Circle = 37, 0x20; Cross = 37, 0x40; Square = 37, 0x80
    }
    $analog = @{ Left = 44; Down = 45; Right = 46; Up = 47; Square = 48; Cross = 49; Circle = 50; Triangle = 51; R1 = 52; L1 = 53; R2 = 54; L2 = 55 }
    foreach ($name in $bits.Keys) {
        $s = New-Object DsuProbe.PadState
        $s.Buttons = [DsuProbe.DsuButtons]$name
        $p = [DsuProbe.Protocol]::BuildPadDataResponse(7, $slot, 1, 0, $s)
        $offset, $mask = $bits[$name]
        $other = if ($offset -eq 36) { 37 } else { 36 }
        if ($p[$offset] -ne $mask -or $p[$other] -ne 0) { $problems += "Bit von $name" }
        $analogBytes = @($p[44..55] | Where-Object { $_ -ne 0 })
        $expected = if ($analog.ContainsKey($name)) { 1 } else { 0 }
        if ($analogBytes.Count -ne $expected -or ($expected -and $p[$analog[$name]] -ne 255)) { $problems += "Analogwert von $name" }
    }

    $s = New-Object DsuProbe.PadState
    $s.Home = $true
    $s.LeftX, $s.LeftY, $s.RightX, $s.RightY = 255, 1, 64, 200
    $s.AccelX, $s.AccelY, $s.AccelZ = 0.25, -1.0, 0.5
    $s.GyroPitch, $s.GyroYaw, $s.GyroRoll = 10.0, -90.0, 45.5
    $s.Touch1Active, $s.Touch1Id, $s.Touch1X, $s.Touch1Y = $true, 3, 1919, 941
    $p = [DsuProbe.Protocol]::BuildPadDataResponse(0x01020304, $slot, 0x0A0B0C0D, 0x1122334455667788, $s)
    $expect = @(
        @(0, $ascii.GetBytes('DSUS'), 'Magic DSUS'),
        @(4, @(0xE9, 0x03), 'Version 1001'),
        @(6, @(84, 0), 'Länge 84'),
        @(12, @(4, 3, 2, 1), 'Server-ID'),
        @(16, @(2, 0, 0x10, 0), 'Typ 0x100002'),
        @(31, @(1), 'verbunden'),
        @(32, @(0x0D, 0x0C, 0x0B, 0x0A), 'Paketnummer'),
        @(38, @(1, 0), 'Home, TouchButton'),
        @(40, @(255, 1, 64, 200), 'Sticks'),
        @(56, @(1, 3, 0x7F, 0x07, 0xAD, 0x03), 'Touch 1'),
        @(62, @(0, 0, 0, 0, 0, 0), 'Touch 2'),
        @(68, @(0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11), 'Zeitstempel'),
        @(76, [BitConverter]::GetBytes([single]0.25), 'Accel x'),
        @(84, [BitConverter]::GetBytes([single]0.5), 'Accel z'),
        @(88, [BitConverter]::GetBytes([single]10.0), 'Gyro Nicken'),
        @(92, [BitConverter]::GetBytes([single]-90.0), 'Gyro Gieren'),
        @(96, [BitConverter]::GetBytes([single]45.5), 'Gyro Rollen')
    )
    if ($p.Length -ne 100) { $problems += "Pad-Daten sind $($p.Length) statt 100 Bytes lang" }
    foreach ($e in $expect) {
        $offset, $bytes, $name = $e
        for ($k = 0; $k -lt $bytes.Count; $k++) {
            if ($p[$offset + $k] -ne $bytes[$k]) { $problems += $name; break }
        }
    }
    $crc = [BitConverter]::ToUInt32($p, 8)
    $p[8], $p[9], $p[10], $p[11] = 0, 0, 0, 0
    if ([DsuProbe.Crc32]::Compute($p, 0, 100) -ne $crc) { $problems += 'CRC32 der Pad-Daten' }

    [pscustomobject]@{
        Name   = 'Aufbau der Pakete'
        Ok     = $problems.Count -eq 0
        Detail = if ($problems) { "Abweichend: $($problems -join ', ')" } else { '16 Tasten, Analogwerte, Sticks, Touch, Zeitstempel, Gyro, Beschleunigung und CRC32 an den Stellen der Protokollbeschreibung' }
    }
}

function Invoke-DsuSelfTest {
    param([int]$Rate)

    $checks = @(Test-DsuPacketLayout)
    $scenario = ConvertFrom-DsuScenario -Line @(
        '0.3s Circle',
        '0.3s Cross Square Triangle',
        '0.3s Share Options L3 R3 Home TouchButton',
        '0.3s Up Right Down Left L1 R1 L2 R2',
        '0.3s LeftStick=right RightStick=-0.5,0.5',
        '0.3s Gyro=10,-90,45.5 Accel=0.25,-1,0.5',
        '0.3s Touch=1919,941 Touch2=0,0'
    )
    $rest = Get-DsuRestState

    $server = New-Object DsuProbe.Server('127.0.0.1', 0, $Rate)
    $client = $null
    $other = $null
    try {
        $server.SetState($rest)
        $server.Start()
        $client = New-Object DsuProbe.ProbeClient('127.0.0.1', $server.Port)
        $client.RequestIntervalMs = 200
        $client.Start()
        Start-Sleep -Milliseconds 300
        $null = Invoke-DsuScenario -Server $server -Step $scenario
        $server.SetState($rest)

        # Broken requests: wrong CRC, wrong magic, wrong version, too short, unsupported type.
        $before = $server.InvalidPackets
        $bad = @()
        $p = [DsuProbe.Protocol]::BuildPadDataRequest($client.ClientId, 0, 0, $null); $p[8] = $p[8] -bxor 0xFF; $bad += , $p
        $p = [DsuProbe.Protocol]::BuildPadDataRequest($client.ClientId, 0, 0, $null); $p[3] = [byte][char]'S'; $bad += , ([DsuProbe.Protocol]::Seal($p))
        $p = [DsuProbe.Protocol]::BuildPadDataRequest($client.ClientId, 0, 0, $null); $p[4] = 0xE8; $bad += , ([DsuProbe.Protocol]::Seal($p))
        $bad += , ([byte[]](0x44, 0x53, 0x55, 0x43, 0xE9, 0x03, 0, 0, 0, 0))
        $p = [DsuProbe.Protocol]::CreateMessage([DsuProbe.Protocol]::ClientMagic, $client.ClientId, [Enum]::ToObject([DsuProbe.MessageType], 0x110001), 8); $bad += , ([DsuProbe.Protocol]::Seal($p))
        foreach ($b in $bad) { $client.Send($b) }

        # A second client asks only for slot 1, then for another MAC, then for the pad's MAC.
        $other = New-Object DsuProbe.ProbeClient('127.0.0.1', $server.Port)
        $other.KeepRequesting = $false
        $other.Start()
        $other.Send([DsuProbe.Protocol]::BuildPadDataRequest($other.ClientId, 1, 1, $null))
        $other.Send([DsuProbe.Protocol]::BuildPadDataRequest($other.ClientId, 2, 0, [byte[]](2, 0, 0, 0, 0, 9)))
        Start-Sleep -Milliseconds 300
        $padBeforeMac = @($other.GetSamples() | Where-Object { $_.Message.Type -eq 'PadData' }).Count
        $other.Send([DsuProbe.Protocol]::BuildPadDataRequest($other.ClientId, 2, 0, $server.Pad.Mac))
        Start-Sleep -Milliseconds 300
        $padAfterMac = @($other.GetSamples() | Where-Object { $_.Message.Type -eq 'PadData' }).Count

        # Timeout: the first client stops asking, the server must stop sending.
        $server.ClientTimeoutMs = 1000
        $client.KeepRequesting = $false
        $stoppedAt = $client.Elapsed.TotalMilliseconds
        Start-Sleep -Milliseconds 1700
        $samples = @($client.GetSamples())
        $invalidAnswers = @($client.GetInvalid()) + @($other.GetInvalid())
        $events = @($server.DrainEvents())
        $invalidCount = $server.InvalidPackets - $before
    }
    finally {
        if ($other) { $other.Stop() }
        if ($client) { $client.Stop() }
        $server.Stop()
    }

    $versions = @($samples | Where-Object { $_.Message.Type -eq 'Version' })
    $portInfo = @($samples | Where-Object { $_.Message.Type -eq 'PortInfo' })
    $pad = @($samples | Where-Object { $_.Message.Type -eq 'PadData' })

    $checks += [pscustomobject]@{
        Name   = 'Antworten gültig'
        Ok     = $invalidAnswers.Count -eq 0 -and $samples.Count -gt 0
        Detail = if ($invalidAnswers) { "Verworfen: $($invalidAnswers -join '; ')" } else { "$($samples.Count) Antworten, alle mit Magic DSUS, Version 1001, passender Länge und CRC32" }
    }
    $checks += [pscustomobject]@{
        Name   = 'Version'
        Ok     = $versions.Count -eq 1 -and $versions[0].Message.ServerVersion -eq 1001
        Detail = "$($versions.Count) Antwort(en), Version $(@($versions | ForEach-Object { $_.Message.ServerVersion }) -join ', ')"
    }
    $slot0 = @($portInfo | Where-Object { $_.Message.Slot.Slot -eq 0 })
    $slot0Ok = @($slot0 | Where-Object { $_.Message.Slot.State -eq 2 -and $_.Message.Slot.Model -eq 2 -and $_.Message.Slot.Battery -eq 5 -and ([BitConverter]::ToString($_.Message.Slot.Mac) -eq [BitConverter]::ToString($server.Pad.Mac)) }).Count
    $others = @($portInfo | Where-Object { $_.Message.Slot.Slot -ne 0 })
    $othersOk = @($others | Where-Object { $_.Message.Slot.State -eq 0 }).Count
    $checks += [pscustomobject]@{
        Name   = 'Pad-Info'
        Ok     = $slot0.Count -gt 0 -and $slot0Ok -eq $slot0.Count -and $others.Count -eq 3 * $slot0.Count -and $othersOk -eq $others.Count
        Detail = "$($slot0.Count) Anfragen: Slot 0 verbunden mit vollem Gyro in $slot0Ok, Slots 1 bis 3 nicht verbunden in $othersOk von $($others.Count)"
    }
    $gaps = 0
    for ($k = 1; $k -lt $pad.Count; $k++) {
        if ($pad[$k].Message.PacketNumber -ne $pad[$k - 1].Message.PacketNumber + 1) { $gaps++ }
    }
    $streamMs = if ($pad.Count -gt 1) { ($pad[-1].Received - $pad[0].Received).TotalMilliseconds } else { 0 }
    $measured = if ($streamMs -gt 0) { [Math]::Round(($pad.Count - 1) * 1000 / $streamMs) } else { 0 }
    $checks += [pscustomobject]@{
        Name   = 'Pad-Daten'
        Ok     = $pad.Count -gt 20 -and $gaps -eq 0 -and @($pad | Where-Object { $_.Message.Slot.Slot -ne 0 -or -not $_.Message.Connected }).Count -eq 0
        Detail = "$($pad.Count) Pakete für Slot 0, Paketnummern $(if ($pad) { "$($pad[0].Message.PacketNumber) bis $($pad[-1].Message.PacketNumber)" }), $gaps Sprünge"
    }
    $checks += [pscustomobject]@{
        Name   = 'Rate'
        Ok     = $measured -ge 0.5 * $Rate -and $measured -le 1.5 * $Rate
        Detail = "gemessen $measured pro Sekunde, eingestellt $Rate"
    }
    $missing = @($scenario | Where-Object { $expected = $_.State; -not ($pad | Where-Object { $_.Message.Pad.SameAs($expected) } | Select-Object -First 1) })
    $allowed = @($scenario | ForEach-Object { $_.State }) + $rest
    $foreign = @($pad | Where-Object { $got = $_.Message.Pad; -not ($allowed | Where-Object { $_.SameAs($got) } | Select-Object -First 1) })
    $checks += [pscustomobject]@{
        Name   = 'Werte aus dem Ablauf'
        Ok     = $missing.Count -eq 0 -and $foreign.Count -eq 0
        Detail = if ($missing -or $foreign) { "fehlend: $(@($missing | ForEach-Object { $_.Text }) -join '; '), $($foreign.Count) Pakete mit fremden Werten" } else { "alle $($scenario.Count) Schritte kamen genau so an, keine fremden Werte" }
    }
    $checks += [pscustomobject]@{
        Name   = 'Kaputte Anfragen'
        Ok     = $invalidCount -eq $bad.Count
        Detail = "$invalidCount von $($bad.Count) verworfen: falsche CRC, falsches Magic, Version 1000, zu kurz, Typ 0x110001"
    }
    $checks += [pscustomobject]@{
        Name   = 'Slot und MAC'
        Ok     = $padBeforeMac -eq 0 -and $padAfterMac -gt 0
        Detail = "Anfrage für Slot 1 und fremde MAC: $padBeforeMac Pakete, danach mit der MAC des Pads: $($padAfterMac - $padBeforeMac) Pakete"
    }
    $late = @($pad | Where-Object { $_.Received.TotalMilliseconds -gt $stoppedAt + 1000 + 250 })
    $expired = @($events | Where-Object { $_.Kind.ToString() -eq 'ClientExpired' }).Count
    $checks += [pscustomobject]@{
        Name   = 'Zeitlimit'
        Ok     = $late.Count -eq 0 -and $expired -ge 1
        Detail = "nach der letzten Anfrage und 1 s Zeitlimit noch $($late.Count) Pakete, Client $expired-mal abgemeldet"
    }

    $checks | ForEach-Object {
        [pscustomobject]@{ 'Prüfung' = $_.Name; Ergebnis = if ($_.Ok) { 'ok' } else { 'FEHLER' }; Detail = $_.Detail }
    } | Format-Table -AutoSize -Wrap | Out-String -Width 220
    $failed = @($checks | Where-Object { -not $_.Ok }).Count
    if ($failed) {
        "Selbsttest: $failed von $($checks.Count) Prüfungen fehlgeschlagen."
        exit 1
    }
    "Selbsttest: alle $($checks.Count) Prüfungen bestanden."
}

if ($SelfTest) {
    Invoke-DsuSelfTest -Rate $Rate
    return
}

$scenarioSteps = $null
if ($PSCmdlet.ParameterSetName -eq 'Scenario') {
    # $PSScriptRoot is still empty in parameter defaults under Windows PowerShell 5.1.
    if (-not $ScenarioPath) { $ScenarioPath = Join-Path $PSScriptRoot 'DsuTour.txt' }
    if (-not (Test-Path -LiteralPath $ScenarioPath)) { throw "Ablaufskript nicht gefunden: $ScenarioPath" }
    $scenarioSteps = ConvertFrom-DsuScenario -Line @(Get-Content -LiteralPath $ScenarioPath -Encoding UTF8)
}
elseif ($PSCmdlet.ParameterSetName -eq 'Steps') {
    $scenarioSteps = ConvertFrom-DsuScenario -Line $Steps
}
if ($null -ne $scenarioSteps -and $scenarioSteps.Count -eq 0) { throw 'Das Ablaufskript enthält keinen Schritt.' }

$server = New-Object DsuProbe.Server($Address, $Port, $Rate)
$server.SetState((Get-DsuRestState))
try {
    $server.Start()
}
catch [System.Net.Sockets.SocketException] {
    throw "UDP $Address`:$Port lässt sich nicht öffnen: $($_.Exception.Message.TrimEnd('.')). Läuft schon ein DSU-Server, etwa Toffee oder ein zweites Fenster dieses Skripts?"
}

try {
    'DSU-Testserver auf UDP {0}:{1}, Protokoll 1001, Server-ID {2:X8}, {3} Pad-Daten pro Sekunde.' -f $Address, $server.Port, $server.ServerId, $Rate
    "Slot 0: verbunden, voller Gyro, MAC $([BitConverter]::ToString($server.Pad.Mac)). Lichii: udp_input_servers=$Address`:$($server.Port)"
    if ($Keyboard) {
        Invoke-DsuKeyboard -Server $server
    }
    else {
        $total = ($scenarioSteps | Measure-Object -Property DurationMs -Sum).Sum / 1000
        'Ablauf: {0} Schritte, {1:N1} s{2}.' -f $scenarioSteps.Count, $total, $(if ($Loop) { ', wiederholt bis Esc oder Strg+C' } else { '' })
        Invoke-DsuScenario -Server $server -Step $scenarioSteps -Loop:$Loop
    }
}
finally {
    Start-Sleep -Milliseconds 100
    Show-DsuEvent -Server $server
    $server.Stop()
    ''
    Format-DsuClientStat -Server $server
    "Ungültige Pakete: $($server.InvalidPackets)"
}
