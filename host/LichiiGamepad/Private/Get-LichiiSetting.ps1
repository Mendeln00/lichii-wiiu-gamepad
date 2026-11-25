function Get-LichiiSetting {
    <#
    .SYNOPSIS
        Returns the value Lichii actually uses for a key of one qt-config.ini section.
    .DESCRIPTION
        Lichii ignores the stored value while the Qt marker "key\default" is true, and
        falls back to its built-in default when the key is missing.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][System.Collections.IDictionary]$Section,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Default
    )
    if ((Get-ConfigValue -Table $Section -Key "$Key\default" -Default 'false') -eq 'true') { return $Default }
    return [string](Get-ConfigValue -Table $Section -Key $Key -Default $Default)
}
