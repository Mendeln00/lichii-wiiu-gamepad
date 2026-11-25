function Read-NspTitleId {
    <#
    .SYNOPSIS
        Reads the title ID of an .nsp file, or returns $null when it cannot be determined.
    .DESCRIPTION
        1. From the name of the ticket ("<title ID><key generation>.tik"), without any key.
        2. Without a ticket: from the header of the content meta (.cnmt.nca), decrypted with
           HeaderKey (header_key from prod.keys). Its ProgramId is the title ID.
        Reads only the PFS0 header and 0x400 bytes of the content meta.
    #>
    [CmdletBinding()]
    [OutputType([uint64])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [byte[]]$HeaderKey
    )

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $buffer = New-Object byte[] 65536
        $read = $stream.Read($buffer, 0, $buffer.Length)
        [Array]::Resize([ref]$buffer, $read)
        $entries = @(Get-Pfs0Entry -Bytes $buffer)

        foreach ($entry in $entries) {
            if ($entry.Name -match '^([0-9a-fA-F]{16})[0-9a-fA-F]{16}\.tik$') {
                return [Convert]::ToUInt64($Matches[1], 16)
            }
        }

        $meta = @($entries | Where-Object { $_.Name -like '*.cnmt.nca' }) | Select-Object -First 1
        if ($null -eq $HeaderKey -or $null -eq $meta -or $meta.Size -lt 0x400) { return $null }
        $header = New-Object byte[] 0x400
        [void]$stream.Seek($meta.Offset, [System.IO.SeekOrigin]::Begin)
        if ($stream.Read($header, 0, $header.Length) -lt $header.Length) { return $null }
        $nca = ConvertFrom-NcaHeader -Bytes $header -HeaderKey $HeaderKey
        if ($null -eq $nca -or $nca.ContentType -ne 1) { return $null }
        return $nca.ProgramId
    }
    finally {
        $stream.Dispose()
    }
}
