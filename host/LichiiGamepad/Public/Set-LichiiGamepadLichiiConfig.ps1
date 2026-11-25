function Set-LichiiGamepadLichiiConfig {
    <#
    .SYNOPSIS
        Sets up Lichii for the GamePad: DSU input from the bridge (ADR 0003) and, on request,
        a playback device of its own for the game audio (ADR 0004).
    .DESCRIPTION
        Sets enable_udp_controller, udp_input_servers and touch_device in the [Controls] section of
        qt-config.ini and, with -AudioDevice, output_device in [Audio], each with its Qt marker
        "\default=false". Writes a timestamped backup first.
        Lichii must not be running: it rewrites qt-config.ini when it exits.
    .PARAMETER LichiiConfigPath
        Path to Lichii's qt-config.ini. Defaults to "$env:APPDATA\lichii\config\qt-config.ini".
    .PARAMETER DsuServer
        DSU server of the bridge as "host:port". Toffee listens on 127.0.0.1:26760 only.
    .PARAMETER TouchDevice
        Touch range the DSU server sends, as "min_x:..,min_y:..,max_x:..,max_y:..".
        Toffee scales touch to a DualShock 4 touch pad, 0-1919 by 0-941.
    .PARAMETER AudioDevice
        Playback device for the game audio, by the exact name Windows shows in its sound settings,
        e.g. "CABLE Input (VB-Audio Virtual Cable)". "auto" goes back to the default device.
        Left out, the audio output stays as it is. Set it only once the bridge records that device,
        otherwise the game is not audible anywhere.
    .EXAMPLE
        Set-LichiiGamepadLichiiConfig
    .EXAMPLE
        Set-LichiiGamepadLichiiConfig -AudioDevice 'CABLE Input (VB-Audio Virtual Cable)'
    .EXAMPLE
        Set-LichiiGamepadLichiiConfig -DsuServer '192.168.0.50:26760' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string]$LichiiConfigPath = (Join-Path $env:APPDATA 'lichii\config\qt-config.ini'),
        [string]$DsuServer = '127.0.0.1:26760',
        [string]$TouchDevice = 'min_x:0,min_y:0,max_x:1919,max_y:941',
        [ValidateNotNullOrEmpty()][string]$AudioDevice
    )

    $dsu = @{
        enable_udp_controller = 'true'
        udp_input_servers     = $DsuServer
        touch_device          = $TouchDevice
    }

    if (Get-Process -Name 'lichii' -ErrorAction SilentlyContinue) {
        throw 'Lichii läuft gerade und würde qt-config.ini beim Beenden überschreiben. Lichii zuerst beenden, dann erneut ausführen.'
    }

    if (-not (Test-Path -LiteralPath $LichiiConfigPath)) {
        throw "qt-config.ini wurde nicht gefunden: $LichiiConfigPath. Lichii einmal starten und beenden, damit die Datei entsteht. Sonst -LichiiConfigPath angeben."
    }
    # .NET file APIs resolve relative paths against the process directory, not the PowerShell location.
    $configFile = (Resolve-Path -LiteralPath $LichiiConfigPath).ProviderPath

    if ($AudioDevice -and $AudioDevice -ne 'auto') {
        # Lichii silently plays on the default device when no active device has exactly this name.
        try {
            $devices = @(Get-PlaybackDeviceName -ErrorAction Stop)
            if ($devices -cnotcontains $AudioDevice) {
                Write-Warning ("Kein aktives Wiedergabegerät heißt genau `"$AudioDevice`". Lichii spielt dann ohne Meldung auf dem Standardgerät. " +
                    "Aktive Geräte: $($devices -join '; ')")
            }
        }
        catch {
            Write-Warning "Die Wiedergabegeräte ließen sich nicht lesen, `"$AudioDevice`" ist ungeprüft: $_"
        }
    }

    $before = [System.IO.File]::ReadAllText($configFile)
    $after = Merge-LichiiConfig -Text $before -Section 'Controls' -Setting $dsu
    if ($AudioDevice) {
        $after = Merge-LichiiConfig -Text $after -Section 'Audio' -Setting @{ output_device = $AudioDevice }
    }
    if ($after -ceq $before) {
        Write-Information -MessageData 'Lichii ist bereits so eingestellt.' -InformationAction Continue
    }
    elseif ($PSCmdlet.ShouldProcess($configFile, 'Einstellungen für das GamePad schreiben (mit Backup)')) {
        $backup = '{0}.{1:yyyyMMdd-HHmmss}.bak' -f $configFile, (Get-Date)
        Copy-Item -LiteralPath $configFile -Destination $backup -ErrorAction Stop
        [System.IO.File]::WriteAllText($configFile, $after, [System.Text.UTF8Encoding]::new($false))
        Write-Information -MessageData "Gespeichert. Backup: $backup" -InformationAction Continue
    }
}
