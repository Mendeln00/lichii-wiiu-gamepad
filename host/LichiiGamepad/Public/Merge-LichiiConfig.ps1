function Merge-LichiiConfig {
    <#
    .SYNOPSIS
        Applies settings to one section of Lichii's qt-config.ini text and returns the new text.
    .DESCRIPTION
        Pure function. Sets "key=value" and the Qt marker "key\default=false" for every setting,
        so Lichii reads the value instead of its built-in default.
    .EXAMPLE
        Merge-LichiiConfig -Text $ini -Section 'Controls' -Setting @{ enable_udp_controller = 'true' }
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][hashtable]$Setting
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($Text -split "`n")) { $lines.Add($line) }

    # Changed lines keep their own ending; inserted lines follow the file's style.
    $newLineEnding = ''
    if ($Text.Contains("`r`n")) { $newLineEnding = "`r" }

    $header = "[$Section]"
    if (-not ($lines | Where-Object { $_.Trim() -ceq $header })) {
        # A trailing newline leaves an empty last element: add the section before it.
        if ($lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
        else { $lines[$lines.Count - 1] += $newLineEnding }
        if ($lines.Count -gt 0) { $lines.Add($newLineEnding) }
        $lines.Add("$header$newLineEnding")
        $lines.Add('')
    }

    foreach ($name in @($Setting.Keys | Sort-Object)) {
        # Qt reads an unquoted value with commas as a string list.
        $value = [string]$Setting[$name]
        if ($value.Contains(',')) { $value = '"' + $value + '"' }

        $valueIndex = -1
        $markerIndex = -1
        $sectionEnd = -1
        $inSection = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].TrimEnd([char]13)
            if ($line.Trim() -match '^\[(.+)\]$') {
                $inSection = $Matches[1] -ceq $Section
                if ($inSection) { $sectionEnd = $i }
                continue
            }
            if (-not $inSection) { continue }
            if ($line.Trim() -ne '') { $sectionEnd = $i }
            $separator = $line.IndexOf('=')
            if ($separator -lt 1) { continue }
            $key = $line.Substring(0, $separator).Trim()
            if ($key -ceq $name) { $valueIndex = $i }
            elseif ($key -ceq "$name\default") { $markerIndex = $i }
        }

        if ($valueIndex -ge 0) {
            $lineEnding = $lines[$valueIndex].Substring($lines[$valueIndex].TrimEnd([char]13).Length)
            $lines[$valueIndex] = "$name=$value$lineEnding"
            if ($markerIndex -ge 0) {
                $lines[$markerIndex] = "$name\default=false$lineEnding"
            }
            else {
                $lines.Insert($valueIndex, "$name\default=false$lineEnding")
            }
        }
        elseif ($sectionEnd -ge 0) {
            $valueEnding = $newLineEnding
            if ($sectionEnd -eq $lines.Count - 1) {
                # Appending after the file's unterminated last line: it gets the ending, the new last line none.
                $lines[$sectionEnd] += $newLineEnding
                $valueEnding = ''
            }
            $lines.Insert($sectionEnd + 1, "$name=$value$valueEnding")
            $lines.Insert($sectionEnd + 1, "$name\default=false$newLineEnding")
        }
    }

    ($lines -join "`n")
}
