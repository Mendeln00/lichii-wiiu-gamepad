function ConvertTo-GameSearchToken {
    <#
    .SYNOPSIS
        Turns a game or file name into the words that matter for a search, in order and without repeats.
    .DESCRIPTION
        Pure function. Lower case, accents removed ("Pokémon" gives "pokemon"), apostrophes dropped
        ("Let's" gives "lets"). Removed: tags in brackets, version numbers (v2.0.1a, v131072), title
        IDs, long numbers, single letters and filler words such as "the", "edition", "dump" or "plus".
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()][string]$Name
    )

    $stopWords = @(
        'a', 'an', 'and', 'the', 'of', 'for', 'to', 'in', 'on', 'with', 'plus',
        'edition', 'deluxe', 'complete', 'definitive', 'nintendo', 'switch', 'nsw', 'ns',
        'game', 'dlc', 'update', 'upd', 'base', 'dump', 'xci', 'nsp', 'nsz', 'xcz'
    )

    $text = $Name -replace '\[[^\]]*\]|\([^)]*\)', ' '
    $text = $text -replace '(?i)(?<![a-z0-9])v\d+(?:\.\d+)*[a-z]?(?![a-z0-9])', ' '
    $text = $text -replace '(?i)\b0100[0-9a-f]{12}\b|\b\d{5,}\b', ' '
    $text = $text.Replace('ß', 'ss').Normalize([System.Text.NormalizationForm]::FormD)
    $text = [regex]::Replace($text, '\p{Mn}', '').ToLowerInvariant() -replace "['’]", ''

    $seen = @{}
    foreach ($word in ($text -split '[^a-z0-9]+')) {
        if ($word -eq '' -or $word -in $stopWords -or $word -match '^[a-z]$' -or $seen.ContainsKey($word)) { continue }
        $seen[$word] = $true
        $word
    }
}
