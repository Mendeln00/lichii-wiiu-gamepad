function Get-LichiiSetting {
    <#
    .SYNOPSIS
        Returns the value Lichii actually uses for a key of one qt-config.ini section.
    .DESCRIPTION
        Lichii uses the stored value only when the Qt marker "key\default" is false.
        A missing marker counts as true, so Lichii then uses its built-in default
        (frontend_common/config.cpp, ReadSettingGeneric).
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][System.Collections.IDictionary]$Section,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Default
    )
    if ((Get-ConfigValue -Table $Section -Key "$Key\default" -Default 'true') -ne 'false') { return $Default }
    return [string](Get-ConfigValue -Table $Section -Key $Key -Default $Default)
}
