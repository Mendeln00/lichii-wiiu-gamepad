function Get-LichiiGameArgument {
    <#
    .SYNOPSIS
        Returns the game path after "-g" in a Lichii command line, with or without quotes.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowEmptyString()][string]$CommandLine)

    if ($CommandLine -match '(?:^|\s)-g\s+(?:"([^"]*)"|(\S+))') {
        # $Matches only holds the groups that took part in the match.
        if ($Matches.ContainsKey(1)) { return $Matches[1] }
        return $Matches[2]
    }
    return ''
}
