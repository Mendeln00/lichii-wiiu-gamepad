function Merge-ApolloConfig {
    <#
    .SYNOPSIS
        Applies settings to the text of Apollo's sunshine.conf and returns the new text.
    .DESCRIPTION
        Pure function. Existing "key = value" lines are updated in place, keeping order,
        comments and line endings. Keys that are missing are appended at the end.
    .EXAMPLE
        Merge-ApolloConfig -Text $conf -Setting @{ mouse = 'disabled' }
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][hashtable]$Setting
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($Text -split "`n")) { $lines.Add($line) }

    $cr = ''
    if ($Text.Contains("`r`n")) { $cr = "`r" }
    $found = @{}

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line.TrimStart().StartsWith('#')) { continue }
        $separator = $line.IndexOf('=')
        if ($separator -lt 1) { continue }
        $key = $line.Substring(0, $separator).Trim()
        if ($Setting.ContainsKey($key)) {
            $ending = ''
            if ($line.EndsWith("`r")) { $ending = "`r" }
            $lines[$i] = "$key = $($Setting[$key])$ending"
            $found[$key] = $true
        }
    }

    # The text normally ends with a newline, so the last element is empty: insert before it.
    $missing = @($Setting.Keys | Where-Object { -not $found.ContainsKey($_) } | Sort-Object)
    if ($missing.Count -gt 0) {
        $hadTrailingNewline = $lines[$lines.Count - 1] -eq ''
        if ($hadTrailingNewline) { $lines.RemoveAt($lines.Count - 1) }
        elseif ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -ne '') {
            $lines[$lines.Count - 1] = $lines[$lines.Count - 1] + $cr
        }
        foreach ($key in $missing) { $lines.Add("$key = $($Setting[$key])$cr") }
        $lines.Add('')
    }

    ($lines -join "`n")
}
