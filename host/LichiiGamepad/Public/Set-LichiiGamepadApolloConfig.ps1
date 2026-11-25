function Set-LichiiGamepadApolloConfig {
    <#
    .SYNOPSIS
        Configures Apollo so the game display, mouse and keyboard stay isolated from the host (ADR 0004).
    .DESCRIPTION
        Writes the sunshine.conf values from ADR 0004: the game display is active but not primary
        and isolated, and Apollo takes no mouse or keyboard input. Test-LichiiGamepadHost checks the
        same values. Writes a timestamped backup first.
        Needs administrator rights when Apollo lives under Program Files.
    .PARAMETER ApolloPath
        Apollo installation folder. Defaults to "Apollo" under Program Files.
    .PARAMETER RestartService
        Restart the ApolloService afterwards so the settings take effect.
    .EXAMPLE
        Set-LichiiGamepadApolloConfig -RestartService
    .EXAMPLE
        Set-LichiiGamepadApolloConfig -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string]$ApolloPath = (Join-Path $env:ProgramFiles 'Apollo'),
        [switch]$RestartService
    )

    $isolation = Get-ApolloIsolationSetting

    $confFile = Join-Path $ApolloPath 'config\sunshine.conf'
    if (-not (Test-Path -LiteralPath $confFile)) {
        throw "sunshine.conf wurde nicht gefunden: $confFile. Ist Apollo installiert? Sonst -ApolloPath angeben."
    }
    # .NET file APIs resolve relative paths against the process directory, not the PowerShell location.
    $confFile = (Resolve-Path -LiteralPath $confFile).ProviderPath

    $before = [System.IO.File]::ReadAllText($confFile)
    $after = Merge-ApolloConfig -Text $before -Setting $isolation
    if ($after -ceq $before) {
        Write-Information -MessageData 'Apollo ist bereits auf Isolation eingestellt.' -InformationAction Continue
    }
    elseif ($PSCmdlet.ShouldProcess($confFile, 'Isolationseinstellungen schreiben (mit Backup)')) {
        $backup = '{0}.{1:yyyyMMdd-HHmmss}.bak' -f $confFile, (Get-Date)
        try {
            Copy-Item -LiteralPath $confFile -Destination $backup -ErrorAction Stop
            # Apollo reads the raw bytes, a BOM would corrupt the first key.
            [System.IO.File]::WriteAllText($confFile, $after, [System.Text.UTF8Encoding]::new($false))
        }
        catch {
            $denied = $_.Exception -is [System.UnauthorizedAccessException] -or $_.CategoryInfo.Category -eq 'PermissionDenied'
            if ($denied) {
                throw "Kein Schreibzugriff auf $confFile. PowerShell als Administrator starten und erneut ausführen."
            }
            throw
        }
        Write-Information -MessageData "Gespeichert. Backup: $backup" -InformationAction Continue
    }

    if ($RestartService -and $PSCmdlet.ShouldProcess('ApolloService', 'Dienst neu starten')) {
        try {
            Restart-Service -Name 'ApolloService' -ErrorAction Stop
        }
        catch {
            throw "ApolloService ließ sich nicht neu starten. Dafür braucht es Administratorrechte. Fehler: $($_.Exception.Message)"
        }
    }
}
