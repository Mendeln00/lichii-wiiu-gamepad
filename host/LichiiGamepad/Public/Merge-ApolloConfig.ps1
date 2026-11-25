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

    # Changed lines keep their own ending; appended lines follow the file's style.
    $appendedLineEnding = ''
    if ($Text.Contains("`r`n")) { $appendedLineEnding = "`r" }
    $keys = @($Setting.Keys)
    $found = @{}

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].TrimEnd([char]13)
        $lineEnding = $lines[$i].Substring($line.Length)
        if ($line.TrimStart().StartsWith('#')) { continue }
        $separator = $line.IndexOf('=')
        if ($separator -lt 1) { continue }
        $key = $line.Substring(0, $separator).Trim()
        # Apollo reads keys case-sensitively, the hashtable would not.
        if ($keys -ccontains $key) {
            # Apollo treats everything from '#' on as a comment, so keep it.
            $comment = ''
            $hash = $line.IndexOf('#', $separator)
            if ($hash -ge 0) { $comment = ' ' + $line.Substring($hash) }
            $lines[$i] = "$key = $($Setting[$key])$comment$lineEnding"
            $found[$key] = $true
        }
    }

    $missing = @($keys | Where-Object { -not $found.ContainsKey($_) } | Sort-Object)
    if ($missing.Count -gt 0) {
        # A trailing newline leaves an empty last element: append before it.
        if ($lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
        else { $lines[$lines.Count - 1] += $appendedLineEnding }
        foreach ($key in $missing) { $lines.Add("$key = $($Setting[$key])$appendedLineEnding") }
        $lines.Add('')
    }

    ($lines -join "`n")
}
