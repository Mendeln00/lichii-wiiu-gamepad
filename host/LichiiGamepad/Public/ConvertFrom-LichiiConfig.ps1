function ConvertFrom-LichiiConfig {
    <#
    .SYNOPSIS
        Parses Lichii's Qt INI file (qt-config.ini) into a hashtable of sections.
    .DESCRIPTION
        Returns @{ Section = @{ key = value } }. Qt's "key\default" markers are kept as their own keys.
        Values wrapped in double quotes are unquoted.
    .EXAMPLE
        (Get-Content "$env:APPDATA\lichii\config\qt-config.ini" -Raw | ConvertFrom-LichiiConfig)['Controls']
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][AllowEmptyString()][string]$Text
    )
    process {
        $ini = @{}
        $section = ''
        foreach ($line in ($Text -split "`r?`n")) {
            $trimmed = $line.Trim()
            if ($trimmed -eq '' -or $trimmed.StartsWith(';') -or $trimmed.StartsWith('#')) { continue }
            if ($trimmed -match '^\[(.+)\]$') {
                $section = $Matches[1]
                if (-not $ini.ContainsKey($section)) { $ini[$section] = @{} }
                continue
            }
            $separator = $trimmed.IndexOf('=')
            if ($separator -lt 1) { continue }
            if (-not $ini.ContainsKey($section)) { $ini[$section] = @{} }
            $key = $trimmed.Substring(0, $separator).Trim()
            $value = $trimmed.Substring($separator + 1).Trim()
            if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $ini[$section][$key] = $value
        }
        $ini
    }
}
