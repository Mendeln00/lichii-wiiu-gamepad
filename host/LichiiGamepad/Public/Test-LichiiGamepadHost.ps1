function Test-LichiiGamepadHost {
    <#
    .SYNOPSIS
        Checks whether this PC is ready to stream Lichii to the Wii U GamePad in isolation.
    .DESCRIPTION
        Reads Apollo, SudoVDA, ViGEmBus and Lichii settings (read-only) and reports each check.
        Use -Detailed to see the suggested fix for every warning or failure.
    .EXAMPLE
        Test-LichiiGamepadHost
    .EXAMPLE
        Test-LichiiGamepadHost -Detailed | Where-Object Status -ne 'Pass'
    #>
    [CmdletBinding()]
    param(
        [string]$ApolloPath = (Join-Path $env:ProgramFiles 'Apollo'),
        [string]$LichiiPath,
        [string]$LichiiConfigPath = (Join-Path $env:APPDATA 'lichii\config\qt-config.ini'),
        [switch]$Detailed
    )

    $stateArgs = @{ ApolloPath = $ApolloPath; LichiiConfigPath = $LichiiConfigPath }
    if ($LichiiPath) { $stateArgs.LichiiPath = $LichiiPath }
    $checks = @(Get-LichiiGamepadHostState @stateArgs | Get-LichiiGamepadHostCheck)

    if ($Detailed) {
        $checks | Select-Object Status, Area, Message, Fix
    }
    else {
        $checks
    }

    $failed = @($checks | Where-Object Status -eq 'Fail').Count
    $warned = @($checks | Where-Object Status -eq 'Warn').Count
    Write-Information -MessageData "Ergebnis: $failed Fehler, $warned Warnungen, $($checks.Count - $failed - $warned) OK." -InformationAction Continue
}
