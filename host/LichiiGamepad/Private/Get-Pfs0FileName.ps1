function Get-Pfs0FileName {
    <#
    .SYNOPSIS
        Lists the file names in a PFS0 header, the container format of .nsp files.
    .DESCRIPTION
        Pure function. Expects the first bytes of the file and returns nothing when they hold no
        complete PFS0 header. Layout: "PFS0", file count, size of the name table, a reserved field,
        then 0x18 bytes per file (offset, size, name offset, reserved) and the zero-terminated names.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Bytes
    )

    if ($Bytes.Length -lt 16 -or [System.Text.Encoding]::ASCII.GetString($Bytes, 0, 4) -cne 'PFS0') { return }
    $count = [long][BitConverter]::ToUInt32($Bytes, 4)
    $tableSize = [long][BitConverter]::ToUInt32($Bytes, 8)
    $tableStart = 16 + 24 * $count
    $tableEnd = $tableStart + $tableSize
    if ($tableEnd -gt $Bytes.Length) { return }

    for ($i = 0; $i -lt $count; $i++) {
        $start = $tableStart + [BitConverter]::ToUInt32($Bytes, [int](16 + 24 * $i + 16))
        if ($start -ge $tableEnd) { return }
        $end = [Array]::IndexOf($Bytes, [byte]0, [int]$start, [int]($tableEnd - $start))
        if ($end -lt 0) { $end = $tableEnd }
        [System.Text.Encoding]::ASCII.GetString($Bytes, [int]$start, [int]($end - $start))
    }
}
