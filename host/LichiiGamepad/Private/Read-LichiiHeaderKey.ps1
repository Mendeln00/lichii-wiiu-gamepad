function Read-LichiiHeaderKey {
    <#
    .SYNOPSIS
        Reads header_key from Lichii's prod.keys and returns it as 32 bytes, or $null.
    .DESCRIPTION
        The key stays in memory and is never written or logged. Lichii needs prod.keys to run games,
        so it is there on a working host. Returns $null when the file or the key is missing.
    #>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [AllowEmptyString()][string]$Path
    )

    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    foreach ($line in [System.IO.File]::ReadAllLines((Resolve-Path -LiteralPath $Path).ProviderPath)) {
        if ($line -match '^\s*header_key\s*=\s*([0-9a-fA-F]{64})\s*$') {
            $hex = $Matches[1]
            $key = New-Object byte[] 32
            for ($i = 0; $i -lt 32; $i++) { $key[$i] = [Convert]::ToByte($hex.Substring(2 * $i, 2), 16) }
            return , $key
        }
    }
    return $null
}
