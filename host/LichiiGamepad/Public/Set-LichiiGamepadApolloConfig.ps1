function Set-LichiiGamepadApolloConfig {
    <#
    .SYNOPSIS
        Configures Apollo so the game display, mouse and keyboard stay isolated from the host (ADR 0004).
    .DESCRIPTION
        Sets dd_configuration_option = ensure_active, isolated_virtual_display_option = enabled,
        mouse = disabled and keyboard = disabled in sunshine.conf. Writes a timestamped backup first.
        Needs administrator rights when Apollo lives under Program Files.
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

    $isolation = @{
        dd_configuration_option         = 'ensure_active'
        isolated_virtual_display_option = 'enabled'
        mouse                           = 'disabled'
        keyboard                        = 'disabled'
    }

    $confFile = Join-Path $ApolloPath 'config\sunshine.conf'
    if (-not (Test-Path -LiteralPath $confFile)) {
        throw "sunshine.conf wurde nicht gefunden: $confFile. Ist Apollo installiert? Sonst -ApolloPath angeben."
    }

    $before = [System.IO.File]::ReadAllText($confFile)
    $after = Merge-ApolloConfig -Text $before -Setting $isolation
    if ($after -ceq $before) {
        Write-Information -MessageData 'Apollo ist bereits auf Isolation eingestellt.' -InformationAction Continue
    }
    elseif ($PSCmdlet.ShouldProcess($confFile, 'Isolationseinstellungen schreiben (mit Backup)')) {
        $backup = '{0}.{1:yyyyMMdd-HHmmss}.bak' -f $confFile, (Get-Date)
        try {
            Copy-Item -LiteralPath $confFile -Destination $backup -ErrorAction Stop
            [System.IO.File]::WriteAllText($confFile, $after, [System.Text.UTF8Encoding]::new($false))
        }
        catch [System.UnauthorizedAccessException] {
            throw "Kein Schreibzugriff auf $confFile. PowerShell als Administrator starten und erneut ausführen."
        }
        catch {
            if ($_.Exception -is [System.UnauthorizedAccessException] -or $_.CategoryInfo.Category -eq 'PermissionDenied') {
                throw "Kein Schreibzugriff auf $confFile. PowerShell als Administrator starten und erneut ausführen."
            }
            throw
        }
        Write-Information -MessageData "Gespeichert. Backup: $backup" -InformationAction Continue
    }

    if ($RestartService -and $PSCmdlet.ShouldProcess('ApolloService', 'Dienst neu starten')) {
        Restart-Service -Name 'ApolloService' -ErrorAction Stop
    }
}
