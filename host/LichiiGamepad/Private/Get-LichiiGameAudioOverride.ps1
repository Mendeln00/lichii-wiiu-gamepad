# How to undo a per-game output device in Lichii; shared by the host check and the setter.
$script:GameAudioOverrideFix = 'In Lichii Rechtsklick auf das Spiel > Eigenschaften > Audio: neben dem Ausgabegerät auf den Zurücksetzen-Knopf klicken ' +
    '(Tooltip "Use the global value"), dann OK. "auto" zu wählen reicht nicht. Lichii setzt den eigenen Wert beim nächsten Öffnen ' +
    'der Eigenschaften wieder, solange global ein Gerät eingestellt ist: dann vor OK erneut zurücksetzen oder mit Abbrechen schließen.'

function Get-LichiiGameAudioOverride {
    <#
    .SYNOPSIS
        Lists the games whose own configuration sets the audio output device instead of following the global one.
    .DESCRIPTION
        Pure function over parsed per-game configs (config\custom\<title id>.ini). Lichii reads a per-game
        value only when "key\use_global" is false; a missing marker counts as true
        (frontend_common/config.cpp, ReadSettingGeneric).
    .PARAMETER GameConfigs
        Title id -> parsed per-game config, as in Get-LichiiGamepadHostState's LichiiGameConfigs.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([AllowNull()][System.Collections.IDictionary]$GameConfigs)

    if ($null -eq $GameConfigs) { return }
    foreach ($titleId in @($GameConfigs.Keys | Sort-Object)) {
        $audio = Get-ConfigValue -Table $GameConfigs[$titleId] -Key 'Audio'
        if ((Get-ConfigValue -Table $audio -Key 'output_device\use_global' -Default 'true') -ne 'false') { continue }
        [pscustomobject]@{
            TitleId = $titleId
            Device  = Get-LichiiSetting -Section $audio -Key 'output_device' -Default 'auto'
        }
    }
}
