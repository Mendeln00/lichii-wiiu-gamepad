function Merge-ApolloConfig {
    <#
    .SYNOPSIS
        Applies settings to the text of Apollo's sunshine.conf and returns the new text.
    .DESCRIPTION
        Pure function. Existing "key = value" lines are updated in place, keeping order,
        comments and line endings. A comment behind a changed value moves to its own line above.
        Keys that are missing are appended at the end.
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
        $entry = Split-ApolloConfigLine -Line $line
        # Apollo reads keys case-sensitively, the hashtable would not.
        if ($null -eq $entry -or $keys -cnotcontains $entry.Key) { continue }
        $key = $entry.Key
        $newLine = "$key = $($Setting[$key])$lineEnding"
        # Apollo keeps the blank before an inline '#' in the value ("enabled " is not true for it),
        # so the comment moves to its own line above.
        if ($entry.Comment -ne '') { $newLine = "$($entry.Comment)$lineEnding`n$newLine" }
        $lines[$i] = $newLine
        $found[$key] = $true
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
