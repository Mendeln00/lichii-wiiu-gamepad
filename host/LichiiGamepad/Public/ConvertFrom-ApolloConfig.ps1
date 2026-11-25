function ConvertFrom-ApolloConfig {
    <#
    .SYNOPSIS
        Parses Apollo/Sunshine's sunshine.conf ("key = value" lines) into a hashtable.
    .EXAMPLE
        Get-Content "$env:ProgramFiles\Apollo\config\sunshine.conf" -Raw | ConvertFrom-ApolloConfig
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][AllowEmptyString()][string]$Text
    )
    process {
        $config = @{}
        foreach ($line in ($Text -split "`r?`n")) {
            $trimmed = $line.Trim()
            if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
            $separator = $trimmed.IndexOf('=')
            if ($separator -lt 1) { continue }
            $key = $trimmed.Substring(0, $separator).Trim()
            $config[$key] = $trimmed.Substring($separator + 1).Trim()
        }
        $config
    }
}
