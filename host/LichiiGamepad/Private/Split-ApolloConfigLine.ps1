function Split-ApolloConfigLine {
    <#
    .SYNOPSIS
        Splits one line of sunshine.conf into Key, Value and Comment, the way Apollo reads it.
    .DESCRIPTION
        Mirrors parse_option in Apollo's src/config.cpp. Everything from the first '#' on is a
        comment, also behind a value. The key is the trimmed text before the first '='. The value
        starts after the blanks behind '=' and runs up to the comment or the line end; like Apollo,
        it keeps blanks at its end ("enabled # x" gives "enabled "). Returns nothing for blank lines,
        comment lines and lines without a key. Expects a line without its line ending.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Line
    )

    $content = $Line
    $comment = ''
    $hash = $Line.IndexOf('#')
    if ($hash -ge 0) {
        $content = $Line.Substring(0, $hash)
        $comment = $Line.Substring($hash)
    }

    $separator = $content.IndexOf('=')
    if ($separator -lt 0) { return }
    $key = $content.Substring(0, $separator).Trim()
    if ($key -eq '') { return }

    [pscustomobject]@{
        Key     = $key
        Value   = $content.Substring($separator + 1).TrimStart([char]' ', [char]"`t")
        Comment = $comment
    }
}
