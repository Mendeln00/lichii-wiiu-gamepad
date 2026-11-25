function Find-GameCover {
    <#
    .SYNOPSIS
        Looks up a Switch cover for a game name in the GameDB, the way Apollo's "Find Cover" does.
    .DESCRIPTION
        Searches the buckets for the first two words of the name and for "th" (names starting with
        "The"), ranks the entries with Select-GameDbMatch and takes the best one for Nintendo Switch
        or Switch 2 that has a cover. Returns Id, Name and Url, or nothing. The Url points to IGDB's
        t_cover_big_2x as PNG: the box art in portrait format with the game's name on it, which
        Apollo's own cover search saves as well.
    .PARAMETER Cache
        Buckets that were already fetched, keyed by bucket name. Shared across games of one run.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Name,
        [hashtable]$Cache = @{}
    )

    # IGDB platform IDs of Nintendo Switch and Nintendo Switch 2.
    $switchPlatforms = @(130, 508)

    $words = @(ConvertTo-GameSearchToken -Name $Name)
    if ($words.Count -eq 0) { return }
    # Apollo files every entry under the first two characters of its name.
    $buckets = @($words | Select-Object -First 2 | ForEach-Object { $_.Substring(0, [Math]::Min(2, $_.Length)) }) + 'th' |
        Select-Object -Unique

    # GameDB records leave out fields they have no value for; StrictMode would throw on them.
    $field = {
        param($Object, [string]$Field)
        if ($null -ne $Object -and $null -ne $Object.PSObject.Properties[$Field]) { $Object.PSObject.Properties[$Field].Value }
    }

    # A bucket holds thousands of names and splitting each costs time, so an entry is split only
    # when its raw name can share a word: it contains one, or has characters or apostrophes that
    # the split turns into plain letters. Words found are kept in the cache for later games.
    $mayShare = [regex]::new(((@($words | ForEach-Object { [regex]::Escape($_) }) + "[^\x00-\x7F'’]") -join '|'), 'IgnoreCase')
    $entries = foreach ($bucket in $buckets) {
        if (-not $Cache.ContainsKey($bucket)) {
            $Cache[$bucket] = @(
                foreach ($property in (Invoke-GameDbRequest -Path "buckets/$bucket.json").PSObject.Properties) {
                    $entryName = & $field $property.Value 'name'
                    if ($entryName) { [pscustomobject]@{ Id = $property.Name; Name = [string]$entryName; Words = $null } }
                }
            )
        }
        foreach ($entry in $Cache[$bucket]) {
            if (-not $mayShare.IsMatch($entry.Name)) { continue }
            if ($null -eq $entry.Words) { $entry.Words = @(ConvertTo-GameSearchToken -Name $entry.Name) }
            $entry
        }
    }

    foreach ($match in @(Select-GameDbMatch -Name $Name -Entry @($entries) | Select-Object -First 5)) {
        $game = Invoke-GameDbRequest -Path "games/$($match.Id).json"
        $platforms = @(foreach ($platform in @(& $field $game 'platforms')) {
                $id = & $field $platform 'id'
                if ($null -ne $id) { $id } else { $platform }
            })
        if (-not @($platforms | Where-Object { $switchPlatforms -contains $_ })) { continue }
        $url = [string](& $field (& $field $game 'cover') 'url')
        if (-not $url) { continue }
        # "//images.igdb.com/igdb/image/upload/t_thumb/co1zk2.jpg" gives the image ID "co1zk2".
        $image = [System.IO.Path]::GetFileNameWithoutExtension($url.Split('/')[-1])
        if ($image -notmatch '^[A-Za-z0-9_]+$') { continue }
        $title = [string](& $field $game 'name')
        if (-not $title) { $title = $match.Name }
        return [pscustomobject][ordered]@{
            Id   = $match.Id
            Name = $title
            Url  = "https://images.igdb.com/igdb/image/upload/t_cover_big_2x/$image.png"
        }
    }
}
