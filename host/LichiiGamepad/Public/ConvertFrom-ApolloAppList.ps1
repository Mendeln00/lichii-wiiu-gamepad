function ConvertFrom-ApolloAppList {
    <#
    .SYNOPSIS
        Parses Apollo's apps.json into one object per app, flagging Lichii game profiles.
    .EXAMPLE
        Get-Content "$env:ProgramFiles\Apollo\config\apps.json" -Raw -Encoding UTF8 | ConvertFrom-ApolloAppList
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][string]$Json
    )
    process {
        $document = $Json | ConvertFrom-Json
        if ($null -eq $document -or -not ($document.PSObject.Properties.Name -contains 'apps')) { return }
        foreach ($app in @($document.apps)) {
            $names = $app.PSObject.Properties.Name
            $command = ''
            if ($names -contains 'cmd' -and $null -ne $app.cmd) { $command = [string]$app.cmd }
            $executable = Get-CommandExecutable -CommandLine $command
            $leaf = ''
            if ($executable -match '([^\\/]+)$') { $leaf = $Matches[1] }
            $virtualDisplay = $false
            if ($names -contains 'virtual-display') { $virtualDisplay = [bool]$app.'virtual-display' }

            [pscustomobject][ordered]@{
                Name           = [string]$app.name
                Command        = $command
                ExecutablePath = $executable
                IsLichii       = ($leaf -match '^lichii.*\.exe$')
                VirtualDisplay = $virtualDisplay
                GamePath       = Get-LichiiGameArgument -CommandLine $command
            }
        }
    }
}
