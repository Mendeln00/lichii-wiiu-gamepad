function New-HostCheck {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory object only.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][ValidateSet('Basis', 'Bild', 'Ton', 'Eingabe')][string]$Area,
        [Parameter(Mandatory)][ValidateSet('Pass', 'Warn', 'Fail')][string]$Status,
        [Parameter(Mandatory)][string]$Message,
        [string]$Fix = ''
    )
    $check = [pscustomobject][ordered]@{
        Id      = $Id
        Area    = $Area
        Status  = $Status
        Message = $Message
        Fix     = $Fix
    }
    $check.PSObject.TypeNames.Insert(0, 'LichiiGamepad.HostCheck')
    $check
}
