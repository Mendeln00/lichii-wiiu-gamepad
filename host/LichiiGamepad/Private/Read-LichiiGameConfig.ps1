function Read-LichiiGameConfig {
    <#
    .SYNOPSIS
        Reads Lichii's per-game configs (custom\<title id>.ini next to qt-config.ini). Thin file wrapper.
    .PARAMETER LichiiConfigPath
        Path to the global qt-config.ini; the per-game configs sit in its "custom" subfolder.
    .OUTPUTS
        Hashtable: title id -> parsed config. Empty when Lichii has written no per-game config yet.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][string]$LichiiConfigPath)

    $games = @{}
    $customDir = Join-Path (Split-Path -Parent $LichiiConfigPath) 'custom'
    if (Test-Path -LiteralPath $customDir) {
        foreach ($file in Get-ChildItem -LiteralPath $customDir -Filter '*.ini' -File) {
            $games[$file.BaseName] = ConvertFrom-LichiiConfig -Text ([string](Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8))
        }
    }
    $games
}
