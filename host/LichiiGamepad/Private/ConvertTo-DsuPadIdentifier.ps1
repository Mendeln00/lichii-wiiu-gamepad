function ConvertTo-DsuPadIdentifier {
    <#
    .SYNOPSIS
        Returns the guid and port by which Lichii identifies the pads of one DSU server.
    .DESCRIPTION
        Pure function. Lichii builds the guid from the server's IPv4 address: "00000000-0000-0000-0000-0000"
        followed by the address in hex with at least six digits (UDPClient::GetHostUUID), stored as
        32 hex digits (UUID::RawString). Below 16.0.0.0 that string is one digit short, Lichii rejects it
        and uses the empty guid. Lichii accepts only IPv4 addresses: a host name or IPv6 makes it use
        0.0.0.0, and it cannot connect.
    .EXAMPLE
        ConvertTo-DsuPadIdentifier -DsuServer '127.0.0.1:26760'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$DsuServer
    )

    $invalid = "Der DSU-Server `"$DsuServer`" ist keine IPv4-Adresse mit Port wie 127.0.0.1:26760. Lichii verbindet sich nur mit solchen Adressen."
    if ($DsuServer -notmatch '^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3}):(\d{1,5})$') { throw $invalid }
    $octets = @([int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4])
    $port = [int]$Matches[5]
    if (@($octets | Where-Object { $_ -gt 255 }).Count -gt 0 -or $port -lt 1 -or $port -gt 65535) { throw $invalid }

    [long]$address = 0
    foreach ($octet in $octets) { $address = $address * 256 + $octet }
    $formatted = '00000000-0000-0000-0000-0000' + ('{0:x6}' -f $address)
    $guid = '0' * 32
    if ($formatted.Length -eq 36) { $guid = $formatted.Replace('-', '') }

    [pscustomobject]@{ Guid = $guid; Port = $port }
}
