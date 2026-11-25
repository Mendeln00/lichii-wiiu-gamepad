function New-LichiiGamepadGameProfile {
    <#
    .SYNOPSIS
        Creates an Apollo game profile (Spielprofil) for every game in a games folder that has none yet.
    .DESCRIPTION
        Finds .xci files, .nsp files of base games (updates and DLC are skipped) and extracted games
        (folders with exefs\main) at the top level of the folder. Each new profile starts
        "lichii.exe -f -g <game>" on Apollo's virtual display. A second run adds nothing.
        An .nsp without a ticket is checked with the header_key from Lichii's prod.keys; if that is
        not possible it gets no profile, because it may be an update.
        Cover: the PNG of the same name next to the game. Without one, the box art for Nintendo Switch
        is looked up the way Apollo's "Find Cover" does (LizardByte GameDB, IGDB t_cover_big_2x as PNG,
        portrait with the game's name on it) and saved as config\covers\igdb_<id>.png in Apollo.
        Writes apps.json directly, with a timestamped backup first: Apollo's API needs the web UI login.
        Apollo reads apps.json only at start, so the profiles show up after -RestartService.
        Needs administrator rights when Apollo lives under Program Files.
        Returns the games that got a profile.
    .PARAMETER GamePath
        The folder that holds the games.
    .PARAMETER LichiiPath
        Path to lichii.exe. Defaults to the one an existing Lichii profile in Apollo starts.
    .PARAMETER ApolloPath
        Apollo installation folder. Defaults to "Apollo" under Program Files.
    .PARAMETER KeysPath
        Lichii's prod.keys, needed only for .nsp files without a ticket. Defaults to
        "%APPDATA%\lichii\keys\prod.keys" or "user\keys\prod.keys" next to lichii.exe.
    .PARAMETER SkipCoverDownload
        Do not look up covers online.
    .PARAMETER RestartService
        Restart the ApolloService afterwards so the new profiles show up. Ends a running stream.
    .EXAMPLE
        New-LichiiGamepadGameProfile -GamePath 'D:\Spiele' -RestartService
    .EXAMPLE
        New-LichiiGamepadGameProfile -GamePath 'D:\Spiele' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$GamePath,
        [string]$LichiiPath,
        [string]$ApolloPath = (Join-Path $env:ProgramFiles 'Apollo'),
        [string]$KeysPath,
        [switch]$SkipCoverDownload,
        [switch]$RestartService
    )

    $appsFile = Join-Path $ApolloPath 'config\apps.json'
    if (-not (Test-Path -LiteralPath $appsFile -PathType Leaf)) {
        throw "apps.json wurde nicht gefunden: $appsFile. Ist Apollo installiert und lief schon einmal? Sonst -ApolloPath angeben."
    }
    # .NET file APIs resolve relative paths against the process directory, not the PowerShell location.
    $appsFile = (Resolve-Path -LiteralPath $appsFile).ProviderPath
    if (-not (Test-Path -LiteralPath $GamePath -PathType Container)) {
        throw "Der Spieleordner wurde nicht gefunden: $GamePath"
    }
    $GamePath = (Resolve-Path -LiteralPath $GamePath).ProviderPath

    $before = [System.IO.File]::ReadAllText($appsFile)
    if (-not $LichiiPath) {
        $LichiiPath = @(ConvertFrom-ApolloAppList -Json $before | Where-Object {
                $_.IsLichii -and $_.ExecutablePath -and (Test-Path -LiteralPath $_.ExecutablePath -PathType Leaf)
            } | ForEach-Object { $_.ExecutablePath }) | Select-Object -First 1
        if (-not $LichiiPath) {
            throw 'Kein Spielprofil in Apollo startet lichii.exe. Den Pfad mit -LichiiPath angeben.'
        }
    }
    elseif (-not (Test-Path -LiteralPath $LichiiPath -PathType Leaf)) {
        throw "lichii.exe wurde nicht gefunden: $LichiiPath"
    }
    $LichiiPath = (Resolve-Path -LiteralPath $LichiiPath).ProviderPath

    if (-not $KeysPath) {
        $KeysPath = @(
            (Join-Path $env:APPDATA 'lichii\keys\prod.keys')
            (Join-Path (Split-Path -Path $LichiiPath -Parent) 'user\keys\prod.keys')
        ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    }
    $headerKey = Read-LichiiHeaderKey -Path $KeysPath
    $new = @(Select-UnprofiledGame -Json $before -Game @(Find-LichiiGame -Path $GamePath -HeaderKey $headerKey))

    if (-not $SkipCoverDownload) {
        $coverDir = Join-Path (Split-Path -Path $appsFile -Parent) 'covers'
        $cache = @{}
        foreach ($game in @($new | Where-Object { -not $_.ImagePath })) {
            try {
                $cover = Find-GameCover -Name $game.Name -Cache $cache
            }
            catch {
                Write-Warning "Cover-Suche für $($game.Name) fehlgeschlagen, das Profil bekommt keins: $($_.Exception.Message)"
                continue
            }
            if (-not $cover) {
                Write-Verbose "Kein passendes Cover gefunden: $($game.Name)"
                continue
            }
            # Apollo's own cover search saves to the same place under the same name.
            $coverFile = Join-Path $coverDir "igdb_$($cover.Id).png"
            if (-not (Test-Path -LiteralPath $coverFile -PathType Leaf)) {
                if (-not $PSCmdlet.ShouldProcess($coverFile, "Cover für $($game.Name) herunterladen: $($cover.Name)")) { continue }
                try {
                    New-Item -ItemType Directory -Path $coverDir -Force -ErrorAction Stop | Out-Null
                    Save-WebFile -Uri $cover.Url -Path $coverFile
                }
                catch {
                    Write-Warning "Cover für $($game.Name) ließ sich nicht speichern, das Profil bekommt keins: $($_.Exception.Message)"
                    continue
                }
            }
            $game.ImagePath = $coverFile
        }
    }

    $result = Merge-ApolloAppList -Json $before -Game $new -LichiiPath $LichiiPath
    $names = ($result.Added | ForEach-Object { $_.Name }) -join ', '
    $written = $false
    if ($result.Added.Count -eq 0) {
        Write-Information -MessageData 'Alle Spiele im Ordner haben schon ein Spielprofil.' -InformationAction Continue
    }
    elseif ($PSCmdlet.ShouldProcess($appsFile, "Spielprofile anlegen (mit Backup): $names")) {
        $backup = '{0}.{1:yyyyMMdd-HHmmss}.bak' -f $appsFile, (Get-Date)
        try {
            Copy-Item -LiteralPath $appsFile -Destination $backup -ErrorAction Stop
            # Apollo parses the raw bytes, a BOM would break the JSON.
            [System.IO.File]::WriteAllText($appsFile, $result.Json, [System.Text.UTF8Encoding]::new($false))
        }
        catch {
            $denied = $_.Exception -is [System.UnauthorizedAccessException] -or $_.CategoryInfo.Category -eq 'PermissionDenied'
            if ($denied) {
                throw "Kein Schreibzugriff auf $appsFile. PowerShell als Administrator starten und erneut ausführen."
            }
            throw
        }
        $written = $true
        Write-Information -MessageData "Angelegt: $names. Backup: $backup" -InformationAction Continue
    }

    if ($written -and $RestartService -and $PSCmdlet.ShouldProcess('ApolloService', 'Dienst neu starten')) {
        try {
            Restart-Service -Name 'ApolloService' -ErrorAction Stop
        }
        catch {
            throw "ApolloService ließ sich nicht neu starten. Dafür braucht es Administratorrechte. Fehler: $($_.Exception.Message)"
        }
    }
    if ($written) { $result.Added }
}
