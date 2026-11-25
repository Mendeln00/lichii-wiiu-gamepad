function Get-CommandExecutable {
    <#
    .SYNOPSIS
        Returns the executable path at the start of a command line, with or without quotes.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowEmptyString()][string]$CommandLine)

    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return '' }
    $trimmed = $CommandLine.Trim()
    if ($trimmed.StartsWith('"')) {
        $end = $trimmed.IndexOf('"', 1)
        if ($end -lt 0) { return $trimmed.Trim('"') }
        return $trimmed.Substring(1, $end - 1)
    }
    return ($trimmed -split '\s+', 2)[0]
}
