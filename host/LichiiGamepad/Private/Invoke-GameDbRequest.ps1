function Invoke-GameDbRequest {
    <#
    .SYNOPSIS
        Fetches one JSON file of LizardByte's GameDB, the IGDB mirror Apollo's web UI searches for covers.
    .PARAMETER Path
        Path inside the database, for example "buckets/po.json" or "games/37382.json".
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    # Windows PowerShell 5.1 does not offer TLS 1.2 by default.
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    $uri = "https://raw.githubusercontent.com/LizardByte/GameDB/gh-pages/$Path"
    Invoke-RestMethod -Uri $uri -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
}
