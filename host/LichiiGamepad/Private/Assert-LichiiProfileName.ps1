function Assert-LichiiProfileName {
    <#
    .SYNOPSIS
        Throws when Lichii cannot keep an input profile of that name.
    .DESCRIPTION
        Pure function. Lichii rejects the characters <>:;"/\|,.!?* (InputProfiles::IsProfileNameValid) and
        garbles names outside ASCII: the profile multiplies and cannot be deleted (zortos293/Lichii#2661).
        The name is also a file name in config\input, so Windows forbids its device names and drops
        leading or trailing spaces.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name
    )

    $problem = $null
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $problem = 'Der Name ist leer.'
    }
    elseif ($Name -cmatch '[^\x20-\x7E]') {
        $problem = 'Er enthält Zeichen außerhalb von ASCII. Lichii verdirbt solche Namen (zortos293/Lichii#2661).'
    }
    elseif ($Name.IndexOfAny('<>:;"/\|,.!?*'.ToCharArray()) -ge 0) {
        $problem = 'Er enthält eins der Zeichen <>:;"/\|,.!?*, die Lichii nicht zulässt.'
    }
    elseif ($Name.Trim() -cne $Name) {
        $problem = 'Er beginnt oder endet mit einem Leerzeichen.'
    }
    elseif ($Name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') {
        $problem = 'Er ist ein reservierter Gerätename von Windows.'
    }

    if ($problem) { throw "Der Profilname `"$Name`" geht nicht. $problem" }
}
