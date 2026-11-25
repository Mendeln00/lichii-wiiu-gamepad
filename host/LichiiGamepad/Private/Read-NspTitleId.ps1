function Read-NspTitleId {
    <#
    .SYNOPSIS
        Reads the title ID of an .nsp file from the name of its ticket ("<title ID><key generation>.tik").
    .DESCRIPTION
        Reads only the first 64 KiB. Returns $null when the file is no PFS0 container or has no ticket.
    #>
    [CmdletBinding()]
    [OutputType([uint64])]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $buffer = New-Object byte[] 65536
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $read = $stream.Read($buffer, 0, $buffer.Length)
    }
    finally {
        $stream.Dispose()
    }
    [Array]::Resize([ref]$buffer, $read)

    foreach ($name in @(Get-Pfs0FileName -Bytes $buffer)) {
        if ($name -match '^([0-9a-fA-F]{16})[0-9a-fA-F]{16}\.tik$') {
            return [Convert]::ToUInt64($Matches[1], 16)
        }
    }
    return $null
}
