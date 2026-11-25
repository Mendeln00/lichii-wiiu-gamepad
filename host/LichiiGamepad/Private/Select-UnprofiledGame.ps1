function Select-UnprofiledGame {
    <#
    .SYNOPSIS
        Returns the games that no app in Apollo's apps.json starts yet.
    .DESCRIPTION
        Pure function. A game has a profile when an app starts its file, or for an extracted game
        anything inside its folder, after "-g" (any name, any case).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Json,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Game
    )

    $started = [System.Collections.Generic.List[string]]::new()
    foreach ($app in @(ConvertFrom-ApolloAppList -Json $Json)) {
        if ($app.GamePath) { $started.Add($app.GamePath.Replace('/', '\')) }
    }

    foreach ($item in $Game) {
        $root = $item.Root.TrimEnd('\')
        $known = @($started | Where-Object {
                $_ -ieq $root -or $_.StartsWith("$root\", [System.StringComparison]::OrdinalIgnoreCase)
            })
        if ($known.Count -gt 0) { continue }
        $started.Add($item.Path)
        $item
    }
}
