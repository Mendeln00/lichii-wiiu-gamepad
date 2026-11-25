function Select-GameDbMatch {
    <#
    .SYNOPSIS
        Ranks GameDB entries by how well their name fits a game or file name; best first.
    .DESCRIPTION
        Pure function. Compares the words of both names (ConvertTo-GameSearchToken).
        Contained: share of the entry's words found in the name. Explained: share of the name's words
        found in the entry. An entry counts when Contained is at least 0.5 and Explained at least 0.3.
        Order: Contained, then Explained, then the older entry (lower ID). So "Pokémon Sword" wins
        for "pokemon_sword" over "Pokémon Sword: The Isle of Armor", which has words the file lacks.
    .PARAMETER Entry
        Objects with Id and Name, for example from a bucket of the GameDB. An optional Words property
        holds the entry's words already split, which saves time on large buckets.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Entry
    )

    $wanted = [System.Collections.Generic.HashSet[string]]::new([string[]]@(ConvertTo-GameSearchToken -Name $Name))
    if ($wanted.Count -eq 0) { return }

    # A bucket holds thousands of entries: plain loops, no pipeline per entry.
    $ranked = foreach ($candidate in $Entry) {
        if ($candidate.PSObject.Properties.Name -contains 'Words') { $words = @($candidate.Words) }
        else { $words = @(ConvertTo-GameSearchToken -Name ([string]$candidate.Name)) }
        if ($words.Count -eq 0) { continue }
        $common = 0
        foreach ($word in $words) { if ($wanted.Contains($word)) { $common++ } }
        if ($common -eq 0) { continue }
        $contained = $common / $words.Count
        $explained = $common / $wanted.Count
        if ($contained -lt 0.5 -or $explained -lt 0.3) { continue }
        [pscustomobject][ordered]@{
            Id        = [long]$candidate.Id
            Name      = [string]$candidate.Name
            Contained = $contained
            Explained = $explained
        }
    }
    $ranked | Sort-Object @{ Expression = 'Contained'; Descending = $true }, @{ Expression = 'Explained'; Descending = $true }, Id
}
