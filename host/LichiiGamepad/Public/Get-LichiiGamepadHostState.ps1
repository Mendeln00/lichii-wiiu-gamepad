function Get-LichiiGamepadHostState {
    <#
    .SYNOPSIS
        Collects the facts about this PC that Get-LichiiGamepadHostCheck evaluates. Read-only.
    .PARAMETER ApolloPath
        Apollo install folder. Defaults to "$env:ProgramFiles\Apollo".
    .PARAMETER LichiiPath
        Path to lichii.exe. If omitted, the executables referenced by Apollo's game profiles are tried.
    .PARAMETER LichiiConfigPath
        Path to Lichii's qt-config.ini. Defaults to "$env:APPDATA\lichii\config\qt-config.ini".
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$ApolloPath = (Join-Path $env:ProgramFiles 'Apollo'),
        [string]$LichiiPath,
        [string]$LichiiConfigPath = (Join-Path $env:APPDATA 'lichii\config\qt-config.ini')
    )

    $configDir = Join-Path $ApolloPath 'config'
    $apolloConfig = @{}
    $confFile = Join-Path $configDir 'sunshine.conf'
    if (Test-Path -LiteralPath $confFile) {
        $apolloConfig = ConvertFrom-ApolloConfig -Text (Get-Content -LiteralPath $confFile -Raw -Encoding UTF8)
    }

    $apps = @()
    $appsFile = Join-Path $configDir 'apps.json'
    if (Test-Path -LiteralPath $appsFile) {
        $apps = @(ConvertFrom-ApolloAppList -Json (Get-Content -LiteralPath $appsFile -Raw -Encoding UTF8))
    }

    $lichiiCandidates = @()
    if ($LichiiPath) { $lichiiCandidates += $LichiiPath }
    $lichiiCandidates += @($apps | Where-Object { $_.IsLichii } | ForEach-Object { $_.ExecutablePath })
    $lichiiFound = @($lichiiCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) }).Count -gt 0

    $lichiiConfig = $null
    if (Test-Path -LiteralPath $LichiiConfigPath) {
        $lichiiConfig = ConvertFrom-LichiiConfig -Text (Get-Content -LiteralPath $LichiiConfigPath -Raw -Encoding UTF8)
    }

    $sudoVda = $false
    try {
        $sudoVda = @(Get-CimInstance -ClassName Win32_PnPEntity -Filter "Name LIKE '%SudoMaker%'" -ErrorAction Stop).Count -gt 0
    }
    catch {
        Write-Verbose "PnP query failed: $_"
    }

    $vigem = $false
    $service = Get-Service -Name 'ViGEmBus' -ErrorAction SilentlyContinue
    if ($null -ne $service) { $vigem = $service.Status -eq 'Running' }

    [pscustomobject][ordered]@{
        ApolloInstalled       = Test-Path -LiteralPath (Join-Path $ApolloPath 'sunshine.exe')
        SudoVdaPresent        = $sudoVda
        ViGEmBusRunning       = $vigem
        LichiiExecutableFound = $lichiiFound
        ApolloConfig          = $apolloConfig
        ApolloApps            = $apps
        LichiiConfig          = $lichiiConfig
    }
}
