function ConvertFrom-NcaHeader {
    <#
    .SYNOPSIS
        Decrypts the first 0x400 bytes of an NCA and returns its ContentType and ProgramId.
    .DESCRIPTION
        Pure function. Needs the header_key from prod.keys (32 bytes). ContentType 1 is Meta, the
        content meta (.cnmt.nca) of a title; its ProgramId is the title ID. Returns nothing when the
        decrypted magic is not NCA0, NCA2 or NCA3, for example with a wrong key.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][byte[]]$Bytes,
        [Parameter(Mandatory)][byte[]]$HeaderKey
    )

    if ($Bytes.Length -lt 0x400) { return }
    $plain = Invoke-AesXtsTransform -Data ([byte[]]$Bytes[0..0x3FF]) -Key $HeaderKey
    $magic = [System.Text.Encoding]::ASCII.GetString($plain, 0x200, 4)
    if ($magic -cnotin @('NCA0', 'NCA2', 'NCA3')) { return }
    [pscustomobject][ordered]@{
        Magic       = $magic
        ContentType = [int]$plain[0x205]
        ProgramId   = [BitConverter]::ToUInt64($plain, 0x210)
    }
}
