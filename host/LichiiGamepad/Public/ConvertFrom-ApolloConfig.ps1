function ConvertFrom-ApolloConfig {
    <#
    .SYNOPSIS
        Parses Apollo/Sunshine's sunshine.conf ("key = value" lines) into a hashtable.
    .DESCRIPTION
        Reads the file like Apollo does: keys are case-sensitive, the first of two equal keys wins,
        and a '#' starts a comment anywhere on the line. A value keeps the blanks before such a
        comment, as in Apollo ("mouse = enabled # x" gives "enabled ").
    .EXAMPLE
        Get-Content "$env:ProgramFiles\Apollo\config\sunshine.conf" -Raw | ConvertFrom-ApolloConfig
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseLiteralInitializerForHashtable', '', Justification = 'Apollo compares keys case-sensitively, a literal hashtable would not.')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][AllowEmptyString()][string]$Text
    )
    process {
        $config = [hashtable]::new([System.StringComparer]::Ordinal)
        foreach ($line in ($Text -split "`r?`n")) {
            $entry = Split-ApolloConfigLine -Line $line
            if ($null -eq $entry -or $config.ContainsKey($entry.Key)) { continue }
            $config[$entry.Key] = $entry.Value
        }
        $config
    }
}
