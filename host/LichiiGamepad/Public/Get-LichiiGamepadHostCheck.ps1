function Get-LichiiGamepadHostCheck {
    <#
    .SYNOPSIS
        Evaluates a host state (from Get-LichiiGamepadHostState) and returns one check result per rule.
    .DESCRIPTION
        Pure function: it only inspects the given state object and never touches the system.
        Each result has Id, Area (Basis/Bild/Ton/Eingabe), Status (Pass/Warn/Fail), Message and Fix.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][pscustomobject]$State
    )
    process {
        $apollo = $State.ApolloConfig

        # --- Basis ---------------------------------------------------------
        if ($State.ApolloInstalled) {
            New-HostCheck -Id 'apollo-installed' -Area Basis -Status Pass -Message 'Apollo ist installiert.'
        }
        else {
            New-HostCheck -Id 'apollo-installed' -Area Basis -Status Fail -Message 'Apollo wurde nicht gefunden.' `
                -Fix 'Apollo von https://github.com/ClassicOldSong/Apollo/releases installieren (inklusive SudoVDA).'
        }

        if ($State.SudoVdaPresent) {
            New-HostCheck -Id 'sudovda-present' -Area Bild -Status Pass -Message 'SudoVDA (virtuelles Display) ist vorhanden.'
        }
        else {
            New-HostCheck -Id 'sudovda-present' -Area Bild -Status Fail -Message 'Der SudoVDA-Treiber fehlt, Apollo kann keine Spielanzeige anlegen.' `
                -Fix 'Apollo neu installieren und dabei den Treiber "SudoVDA" auswählen.'
        }

        if ($State.ViGEmBusRunning) {
            New-HostCheck -Id 'vigembus-running' -Area Eingabe -Status Pass -Message 'ViGEmBus läuft (Rückfall-Eingabe über virtuellen Xbox-Controller).'
        }
        else {
            New-HostCheck -Id 'vigembus-running' -Area Eingabe -Status Warn -Message 'ViGEmBus läuft nicht. Ohne DSU kommen dann keine GamePad-Tasten an.' `
                -Fix 'ViGEmBus von https://github.com/nefarius/ViGEmBus/releases installieren und den PC neu starten.'
        }

        if ($State.LichiiExecutableFound) {
            New-HostCheck -Id 'lichii-found' -Area Basis -Status Pass -Message 'lichii.exe wurde gefunden.'
        }
        else {
            New-HostCheck -Id 'lichii-found' -Area Basis -Status Fail -Message 'lichii.exe wurde nicht gefunden.' `
                -Fix 'Lichii von https://github.com/zortos293/Lichii/releases entpacken und den Pfad mit -LichiiPath angeben.'
        }

        # --- Bild: Isolation der Spielanzeige --------------------------------
        # The target values come from the same place Set-LichiiGamepadApolloConfig writes them from.
        $target = Get-ApolloIsolationSetting
        $apolloFix = 'Set-LichiiGamepadApolloConfig -RestartService als Administrator ausführen (setzt {0} = {1}).'

        $ddOption = Get-ConfigValue -Table $apollo -Key 'dd_configuration_option' -Default 'disabled'
        # Apollo matches the option exactly and treats any other value as disabled.
        if ($ddOption -cin @('ensure_primary', 'ensure_only_display')) {
            New-HostCheck -Id 'display-not-primary' -Area Bild -Status Warn `
                -Message "Apollo macht die Spielanzeige zur Hauptanzeige (dd_configuration_option = $ddOption). Fenster und Taskleiste springen dann vom PC-Bildschirm weg." `
                -Fix ($apolloFix -f 'dd_configuration_option', $target['dd_configuration_option'])
        }
        else {
            New-HostCheck -Id 'display-not-primary' -Area Bild -Status Pass -Message 'Die Spielanzeige wird nicht zur Hauptanzeige.'
        }

        # Apollo's defaults: no isolated display, mouse and keyboard input on.
        $isolated = ConvertTo-ApolloBoolean -Value (Get-ConfigValue -Table $apollo -Key 'isolated_virtual_display_option') -Default $false
        if ($isolated -eq (ConvertTo-ApolloBoolean -Value $target['isolated_virtual_display_option'] -Default $false)) {
            New-HostCheck -Id 'display-isolated' -Area Bild -Status Pass -Message 'Die Spielanzeige ist isoliert (die Maus gerät nicht versehentlich hinüber).'
        }
        else {
            New-HostCheck -Id 'display-isolated' -Area Bild -Status Warn -Message 'Die Spielanzeige ist nicht isoliert. Die Maus kann vom PC-Bildschirm auf sie wandern.' `
                -Fix ($apolloFix -f 'isolated_virtual_display_option', $target['isolated_virtual_display_option'])
        }

        # --- Eingabe: keine globalen Eingaben über Apollo ----------------------
        foreach ($device in @('mouse', 'keyboard')) {
            $accepts = ConvertTo-ApolloBoolean -Value (Get-ConfigValue -Table $apollo -Key $device) -Default $true
            $label = @{ mouse = 'Maus'; keyboard = 'Tastatur' }[$device]
            if ($accepts -eq (ConvertTo-ApolloBoolean -Value $target[$device] -Default $true)) {
                New-HostCheck -Id "apollo-$device-disabled" -Area Eingabe -Status Pass -Message "Apollo nimmt keine $label-Eingaben vom Client an."
            }
            else {
                New-HostCheck -Id "apollo-$device-disabled" -Area Eingabe -Status Warn `
                    -Message "Apollo nimmt $label-Eingaben vom Client an. Touch oder Tasten können dann den PC steuern." `
                    -Fix ($apolloFix -f $device, $target[$device])
            }
        }

        # --- Spielprofile -----------------------------------------------------
        $lichiiApps = @($State.ApolloApps | Where-Object { $_.IsLichii })
        $withoutDisplay = @($lichiiApps | Where-Object { -not $_.VirtualDisplay })
        if ($lichiiApps.Count -eq 0) {
            New-HostCheck -Id 'game-profile' -Area Basis -Status Warn -Message 'In Apollo gibt es kein Spielprofil, das Lichii startet.' `
                -Fix 'In Apollo eine App mit Befehl "<Pfad>\lichii.exe -f -g <Spiel>" und "Always use Virtual Display" anlegen.'
        }
        elseif ($withoutDisplay.Count -gt 0) {
            $names = ($withoutDisplay | ForEach-Object { $_.Name }) -join ', '
            New-HostCheck -Id 'game-profile' -Area Bild -Status Warn -Message "Diese Spielprofile nutzen keine Spielanzeige: $names" `
                -Fix 'In Apollo bei diesen Apps "Always use Virtual Display" aktivieren.'
        }
        else {
            New-HostCheck -Id 'game-profile' -Area Basis -Status Pass -Message "$($lichiiApps.Count) Spielprofil(e) mit Spielanzeige gefunden."
        }

        # --- Eingabe: DSU in Lichii ------------------------------------------
        $controls = $null
        if ($null -ne $State.LichiiConfig) { $controls = Get-ConfigValue -Table $State.LichiiConfig -Key 'Controls' }
        if ($null -eq $controls) {
            New-HostCheck -Id 'lichii-dsu' -Area Eingabe -Status Warn -Message 'Die Lichii-Konfiguration (qt-config.ini) wurde nicht gefunden.' `
                -Fix 'Lichii einmal starten und beenden, damit %APPDATA%\lichii\config\qt-config.ini angelegt wird.'
            return
        }

        if ((Get-LichiiSetting -Section $controls -Key 'enable_udp_controller' -Default 'false') -eq 'true') {
            New-HostCheck -Id 'lichii-dsu-enabled' -Area Eingabe -Status Pass -Message 'UDP-Controller (DSU) sind in Lichii aktiv.'
        }
        else {
            New-HostCheck -Id 'lichii-dsu-enabled' -Area Eingabe -Status Warn -Message 'UDP-Controller (DSU) sind in Lichii aus. Gyro und Touch vom GamePad kommen nicht an.' `
                -Fix 'Set-LichiiGamepadLichiiConfig ausführen (Lichii vorher beenden).'
        }

        $servers = Get-LichiiSetting -Section $controls -Key 'udp_input_servers' -Default '127.0.0.1:26760'
        # A bridge on this PC (Toffee) serves DSU on 127.0.0.1, so a local server is fine.
        $configured = @($servers -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($configured.Count -gt 0) {
            New-HostCheck -Id 'lichii-dsu-server' -Area Eingabe -Status Pass -Message "Lichii fragt DSU bei $($configured -join ', ') ab."
        }
        else {
            New-HostCheck -Id 'lichii-dsu-server' -Area Eingabe -Status Warn -Message 'In Lichii ist kein DSU-Server eingetragen.' `
                -Fix 'Set-LichiiGamepadLichiiConfig ausführen (Toffee: 127.0.0.1:26760) oder mit -DsuServer die Adresse der Brücke angeben.'
        }

        # --- Ton: Spielton auf einem eigenen Gerät (ADR 0004) -----------------
        $audio = Get-ConfigValue -Table $State.LichiiConfig -Key 'Audio'
        $device = Get-LichiiSetting -Section $audio -Key 'output_device' -Default 'auto'
        if ($device -in @('auto', '')) {
            New-HostCheck -Id 'audio-isolated' -Area Ton -Status Warn `
                -Message 'Lichii spielt auf dem Windows-Standardgerät. Spielton und übriger PC-Ton lassen sich dann nicht trennen.' `
                -Fix "Ein eigenes Wiedergabegerät einrichten (etwa VB-CABLE) und Set-LichiiGamepadLichiiConfig -AudioDevice '<Anzeigename>' ausführen (Lichii vorher beenden)."
        }
        elseif ($null -eq $State.PlaybackDevices) {
            New-HostCheck -Id 'audio-isolated' -Area Ton -Status Warn `
                -Message "Lichii soll auf `"$device`" spielen. Ob es dieses Gerät gibt, ließ sich nicht prüfen." `
                -Fix 'In den Windows-Soundeinstellungen nachsehen, ob das Wiedergabegerät genau so heißt und aktiv ist.'
        }
        # Lichii (cubeb, SDL3) compares the exact friendly name of active devices and
        # falls back to the default device without logging anything.
        elseif ($State.PlaybackDevices -cnotcontains $device) {
            New-HostCheck -Id 'audio-isolated' -Area Ton -Status Warn `
                -Message "Lichii soll auf `"$device`" spielen, aber kein aktives Wiedergabegerät heißt genau so. Lichii spielt dann ohne Meldung auf dem Standardgerät." `
                -Fix "Set-LichiiGamepadLichiiConfig -AudioDevice mit einem dieser Namen ausführen: $($State.PlaybackDevices -join '; ')"
        }
        else {
            New-HostCheck -Id 'audio-isolated' -Area Ton -Status Pass -Message "Lichii spielt auf ein eigenes Gerät: $device."
        }

        # Lichii's game properties dialog marks the output device as per-game while it loads, as soon as the
        # global device is not "auto" (configure_audio.cpp: SetOutputDevicesFromDeviceID runs after the
        # updating_devices guard). Saving the dialog then pins that device for the game.
        $overrides = @(Get-LichiiGameAudioOverride -GameConfigs $State.LichiiGameConfigs)
        if ($overrides.Count -gt 0) {
            $list = ($overrides | ForEach-Object { "$($_.TitleId): $($_.Device)" }) -join '; '
            New-HostCheck -Id 'audio-game-override' -Area Ton -Status Warn `
                -Message "Diese Spiele legen ihr Tongerät selbst fest und folgen der globalen Einstellung nicht: $list" `
                -Fix $script:GameAudioOverrideFix
        }
        else {
            New-HostCheck -Id 'audio-game-override' -Area Ton -Status Pass -Message 'Alle Spiele folgen dem globalen Tongerät.'
        }
    }
}
