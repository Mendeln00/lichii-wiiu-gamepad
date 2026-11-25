function ConvertTo-ApolloBoolean {
    <#
    .SYNOPSIS
        Reads a sunshine.conf value as a boolean, exactly like Apollo does.
    .DESCRIPTION
        Mirrors bool_f and to_bool in Apollo's src/config.cpp. An empty value keeps the default.
        True are true, yes, enable, enabled and on, and every value that contains the digit 1.
        Apollo means to ignore case but does not, so "Enabled" and "enabled " are false.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()][AllowEmptyString()][string]$Value,
        [Parameter(Mandatory)][bool]$Default
    )
    if ([string]::IsNullOrEmpty($Value)) { return $Default }
    ($Value -cin @('true', 'yes', 'enable', 'enabled', 'on')) -or $Value.Contains('1')
}
