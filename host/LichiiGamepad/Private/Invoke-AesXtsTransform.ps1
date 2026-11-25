function Invoke-AesXtsTransform {
    <#
    .SYNOPSIS
        Decrypts or encrypts data with AES-128-XTS the way Nintendo does for NCA headers.
    .DESCRIPTION
        Pure function. Key holds 32 bytes: the data key, then the tweak key. Sectors are 0x200 bytes
        and numbered from FirstSector; unlike IEEE 1619, Nintendo writes the sector number into the
        tweak big-endian. The length must be a multiple of 16. Encrypt exists for tests.
    #>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory)][byte[]]$Data,
        [Parameter(Mandatory)][ValidateCount(32, 32)][byte[]]$Key,
        [long]$FirstSector = 0,
        [switch]$Encrypt
    )

    if ($Data.Length % 16 -ne 0) { throw 'XTS braucht eine Länge in Vielfachen von 16 Byte.' }
    $zero = New-Object byte[] 16
    $aes = [System.Security.Cryptography.Aes]::Create()
    try {
        $aes.Mode = [System.Security.Cryptography.CipherMode]::ECB
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::None
        $dataKey = [byte[]]$Key[0..15]
        if ($Encrypt) { $cipher = $aes.CreateEncryptor($dataKey, $zero) }
        else { $cipher = $aes.CreateDecryptor($dataKey, $zero) }
        $tweakCipher = $aes.CreateEncryptor([byte[]]$Key[16..31], $zero)

        $result = New-Object byte[] $Data.Length
        $block = New-Object byte[] 16
        $out = New-Object byte[] 16
        for ($sectorStart = 0; $sectorStart -lt $Data.Length; $sectorStart += 0x200) {
            $sector = $FirstSector + $sectorStart / 0x200
            $tweakIn = New-Object byte[] 16
            for ($k = 15; $k -ge 8; $k--) {
                $tweakIn[$k] = [byte]($sector -band 0xFF)
                $sector = $sector -shr 8
            }
            $tweak = New-Object byte[] 16
            [void]$tweakCipher.TransformBlock($tweakIn, 0, 16, $tweak, 0)

            $sectorEnd = [Math]::Min($sectorStart + 0x200, $Data.Length)
            for ($offset = $sectorStart; $offset -lt $sectorEnd; $offset += 16) {
                for ($k = 0; $k -lt 16; $k++) { $block[$k] = $Data[$offset + $k] -bxor $tweak[$k] }
                [void]$cipher.TransformBlock($block, 0, 16, $out, 0)
                for ($k = 0; $k -lt 16; $k++) { $result[$offset + $k] = $out[$k] -bxor $tweak[$k] }

                # Next tweak: multiply by x in GF(2^128), stored little-endian.
                $carry = 0
                for ($k = 0; $k -lt 16; $k++) {
                    $next = ($tweak[$k] -shr 7) -band 1
                    $tweak[$k] = [byte]((($tweak[$k] -shl 1) -band 0xFF) -bor $carry)
                    $carry = $next
                }
                if ($carry) { $tweak[0] = $tweak[0] -bxor 0x87 }
            }
        }
        , $result
    }
    finally {
        $aes.Dispose()
    }
}
