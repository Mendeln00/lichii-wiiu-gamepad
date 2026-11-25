function Merge-ApolloAppList {
    <#
    .SYNOPSIS
        Adds a Lichii game profile to the text of Apollo's apps.json for every game that has none yet.
    .DESCRIPTION
        Pure function apart from the uuid. A game has a profile when an app starts its file, or for
        an extracted game anything inside its folder, after "-g" (any name, any case). New profiles
        start Lichii in fullscreen on Apollo's virtual display and carry the cover when there is one.
        Existing apps and all other fields stay as they are. Returns Json (the new text, unchanged
        when nothing was added) and Added (the games that got a profile).
    .PARAMETER Game
        Games as returned by Find-LichiiGame: Name, Path, Root and ImagePath.
    .PARAMETER NewUuid
        Creates the uuid Apollo needs for every app. Defaults to a new upper-case GUID, as Apollo writes it.
    .EXAMPLE
        Merge-ApolloAppList -Json $appsJson -Game $games -LichiiPath 'C:\Lichii\lichii.exe'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Json,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Game,
        [Parameter(Mandatory)][string]$LichiiPath,
        [scriptblock]$NewUuid = { [guid]::NewGuid().ToString().ToUpperInvariant() }
    )

    $started = [System.Collections.Generic.List[string]]::new()
    foreach ($app in @(ConvertFrom-ApolloAppList -Json $Json)) {
        if ($app.GamePath) { $started.Add($app.GamePath.Replace('/', '\')) }
    }

    $document = $Json | ConvertFrom-Json
    $apps = @()
    if ($document.PSObject.Properties.Name -contains 'apps') { $apps = @($document.apps) }
    $workingDir = Split-Path -Path $LichiiPath -Parent
    $added = @()

    foreach ($item in $Game) {
        $root = $item.Root.TrimEnd('\')
        $known = @($started | Where-Object {
                $_ -ieq $root -or $_.StartsWith("$root\", [System.StringComparison]::OrdinalIgnoreCase)
            })
        if ($known.Count -gt 0) { continue }

        $app = [ordered]@{
            name          = $item.Name
            cmd           = "`"$LichiiPath`" -f -g `"$($item.Path)`""
            'working-dir' = "`"$workingDir`""
        }
        if ($item.ImagePath) { $app['image-path'] = $item.ImagePath }
        $app['virtual-display'] = $true
        $app['uuid'] = [string](& $NewUuid)

        $apps += [pscustomobject]$app
        $added += $item
        $started.Add($item.Path)
    }

    if ($added.Count -eq 0) {
        return [pscustomobject]@{ Json = $Json; Added = @() }
    }

    if ($document.PSObject.Properties.Name -contains 'apps') { $document.apps = $apps }
    else { $document | Add-Member -NotePropertyName 'apps' -NotePropertyValue $apps }
    # Apollo writes apps.json with CRLF on Windows; JSON strings hold no raw line breaks.
    $text = ($document | ConvertTo-Json -Depth 32) -replace "`r?`n", "`r`n"
    [pscustomobject]@{ Json = $text; Added = $added }
}
