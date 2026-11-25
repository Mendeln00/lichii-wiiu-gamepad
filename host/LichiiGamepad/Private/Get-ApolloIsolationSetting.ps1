function Get-ApolloIsolationSetting {
    <#
    .SYNOPSIS
        Returns the sunshine.conf values from ADR 0004 that keep the game display, mouse and keyboard isolated.
    .DESCRIPTION
        The only place these values live: Set-LichiiGamepadApolloConfig writes them and
        Get-LichiiGamepadHostCheck checks against them. Returns a new table on every call.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    @{
        dd_configuration_option         = 'ensure_active'
        isolated_virtual_display_option = 'enabled'
        mouse                           = 'disabled'
        keyboard                        = 'disabled'
    }
}
