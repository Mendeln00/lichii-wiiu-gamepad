function Set-LichiiGamepadInputProfile {
    <#
    .SYNOPSIS
        Creates Lichii's input profile for the GamePad and assigns it to player 1.
    .DESCRIPTION
        Writes the input profile config\input\<ProfileName>.ini next to qt-config.ini and sets player 1 in
        qt-config.ini to the same mapping: the DSU pad of the bridge as a Pro Controller, with Lichii's own
        mapping for UDP controllers (ConvertTo-LichiiInputProfile). Afterwards Lichii shows the profile under
        Controls > Player 1, and nothing needs to be mapped by hand.
        Writes a timestamped backup of every file it changes. Lichii must not be running: it rewrites
        qt-config.ini when it exits.
    .PARAMETER LichiiConfigPath
        Path to Lichii's qt-config.ini. Defaults to "$env:APPDATA\lichii\config\qt-config.ini".
    .PARAMETER DsuServer
        DSU server of the bridge as "IPv4:port". It must be one of Lichii's udp_input_servers, as set by
        Set-LichiiGamepadLichiiConfig -DsuServer. Defaults to the first of them.
    .PARAMETER ProfileName
        Name of the input profile. ASCII only, because Lichii garbles other names (zortos293/Lichii#2661),
        and none of <>:;"/\|,.!?*.
    .PARAMETER ButtonMap
        Replaces single buttons, see ConvertTo-LichiiInputProfile.
    .PARAMETER Force
        Overwrites a different input profile of the same name, after a backup.
    .EXAMPLE
        Set-LichiiGamepadInputProfile
    .EXAMPLE
        Set-LichiiGamepadInputProfile -DsuServer '192.168.0.50:26760' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string]$LichiiConfigPath = (Join-Path $env:APPDATA 'lichii\config\qt-config.ini'),
        [string]$DsuServer,
        [AllowEmptyString()][string]$ProfileName = 'WiiU GamePad',
        [hashtable]$ButtonMap = @{},
        [switch]$Force
    )

    Assert-LichiiProfileName -Name $ProfileName

    if (Get-Process -Name 'lichii' -ErrorAction SilentlyContinue) {
        throw 'Lichii läuft gerade und würde qt-config.ini beim Beenden überschreiben. Lichii zuerst beenden, dann erneut ausführen.'
    }

    if (-not (Test-Path -LiteralPath $LichiiConfigPath)) {
        throw "qt-config.ini wurde nicht gefunden: $LichiiConfigPath. Lichii einmal starten und beenden, damit die Datei entsteht. Sonst -LichiiConfigPath angeben."
    }
    # .NET file APIs resolve relative paths against the process directory, not the PowerShell location.
    $configFile = (Resolve-Path -LiteralPath $LichiiConfigPath).ProviderPath
    $before = [System.IO.File]::ReadAllText($configFile)

    # Lichii counts four pads per DSU server, in the order of udp_input_servers.
    $controls = Get-ConfigValue -Table (ConvertFrom-LichiiConfig -Text $before) -Key 'Controls'
    $setting = Get-LichiiSetting -Section $controls -Key 'udp_input_servers' -Default '127.0.0.1:26760'
    $servers = @($setting -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if (-not $DsuServer -and $servers.Count -gt 0) { $DsuServer = $servers[0] }
    $index = [array]::IndexOf($servers, $DsuServer)
    if ($index -lt 0) {
        throw ("Lichii fragt den DSU-Server `"$DsuServer`" nicht ab (udp_input_servers: `"$setting`"). " +
            "Zuerst Set-LichiiGamepadLichiiConfig -DsuServer '<Adresse:Port>' ausführen, dann erneut.")
    }
    $settings = ConvertTo-LichiiInputProfile -DsuServer $DsuServer -Pad ($index * 4) -ButtonMap $ButtonMap

    # Lichii writes its own files with CRLF.
    $profileDir = Join-Path (Split-Path -Parent $configFile) 'input'
    $profileFile = Join-Path $profileDir "$ProfileName.ini"
    $profileText = (Merge-LichiiConfig -Text '' -Section 'Controls' -Setting $settings).Replace("`n", "`r`n")
    $profileExists = Test-Path -LiteralPath $profileFile
    $profileChanged = $true
    if ($profileExists) {
        $existing = Get-ConfigValue -Table (ConvertFrom-LichiiConfig -Text ([System.IO.File]::ReadAllText($profileFile))) -Key 'Controls'
        $differs = @($settings.Keys | Where-Object { (Get-LichiiSetting -Section $existing -Key $_ -Default '') -cne $settings[$_] })
        if ($differs.Count -eq 0) {
            $profileChanged = $false
        }
        elseif (-not $Force) {
            throw "Ein anderes Eingabeprofil `"$ProfileName`" gibt es schon: $profileFile. Mit -Force überschreiben (mit Backup) oder einen anderen -ProfileName wählen."
        }
    }

    $player = @{
        player_0_profile_name = $ProfileName
        player_0_connected    = 'true'
    }
    foreach ($key in $settings.Keys) { $player["player_0_$key"] = $settings[$key] }
    $after = Merge-LichiiConfig -Text $before -Section 'Controls' -Setting $player
    $configChanged = $after -cne $before

    if (-not $profileChanged -and -not $configChanged) {
        Write-Information -MessageData "Das Eingabeprofil `"$ProfileName`" ist bereits eingerichtet und Spieler 1 zugewiesen." -InformationAction Continue
        return
    }

    $target = "$profileFile; $configFile"
    if ($PSCmdlet.ShouldProcess($target, "Eingabeprofil `"$ProfileName`" anlegen und Spieler 1 zuweisen (mit Backup)")) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $utf8 = [System.Text.UTF8Encoding]::new($false)
        $backups = @()
        if ($profileChanged) {
            if ($profileExists) {
                $backups += "$profileFile.$stamp.bak"
                Copy-Item -LiteralPath $profileFile -Destination "$profileFile.$stamp.bak" -ErrorAction Stop
            }
            else {
                New-Item -ItemType Directory -Path $profileDir -Force -ErrorAction Stop | Out-Null
            }
            [System.IO.File]::WriteAllText($profileFile, $profileText, $utf8)
        }
        if ($configChanged) {
            $backups += "$configFile.$stamp.bak"
            Copy-Item -LiteralPath $configFile -Destination "$configFile.$stamp.bak" -ErrorAction Stop
            [System.IO.File]::WriteAllText($configFile, $after, $utf8)
        }
        $message = "Gespeichert: Eingabeprofil `"$ProfileName`" für Spieler 1."
        if ($backups.Count -gt 0) { $message += " Backup: $($backups -join '; ')" }
        Write-Information -MessageData $message -InformationAction Continue
    }
}
