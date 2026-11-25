function Get-ConfigValue {
    <#
    .SYNOPSIS
        Reads a key from a hashtable, returning a default when the table or key is missing.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][System.Collections.IDictionary]$Table,
        [Parameter(Mandatory)][string]$Key,
        [AllowNull()]$Default = $null
    )
    if ($null -ne $Table -and $Table.Contains($Key)) { return $Table[$Key] }
    return $Default
}
