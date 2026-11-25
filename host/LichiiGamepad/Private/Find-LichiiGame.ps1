function Find-LichiiGame {
    <#
    .SYNOPSIS
        Lists the games in a games folder: .xci files, .nsp files of base games and extracted games.
    .DESCRIPTION
        Looks at the top level of the folder only.
        - An .nsp counts when its ticket names a base game. The low 13 bits of the title ID are 0 for
          the game, 0x800 for its update and higher for DLC. An .nsp without a ticket counts as a game.
        - A folder counts as an extracted game when it holds exefs\main. With several versions inside,
          the main with the highest number in its path wins (updates\131072 beats base).
        - The cover is the PNG with the same name next to the file, or the first PNG inside the folder
          of an extracted game. Apollo shows only PNG files.
        Returns Name, Path (what Lichii starts), Root (the file or folder that is the game) and ImagePath.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    foreach ($item in @(Get-ChildItem -LiteralPath $Path | Sort-Object Name)) {
        $imagePath = ''
        if ($item.PSIsContainer) {
            # Depth 4 reaches updates\<version>\exefs\main without walking a whole romfs.
            $mains = @(Get-ChildItem -LiteralPath $item.FullName -Recurse -Depth 4 -File -Filter 'main' |
                    Where-Object { $_.Name -ceq 'main' -and $_.Directory.Name -eq 'exefs' })
            if ($mains.Count -eq 0) { continue }

            $version = {
                $segments = $_.FullName.Substring($item.FullName.Length) -split '[\\/]'
                $numbers = @($segments | Where-Object { $_ -match '^\d{1,18}$' } | ForEach-Object { [long]$_ })
                if ($numbers.Count -eq 0) { return -1 }
                ($numbers | Measure-Object -Maximum).Maximum
            }
            $main = $mains | Sort-Object @{ Expression = $version; Descending = $true }, @{ Expression = { $_.FullName.Length } } |
                Select-Object -First 1

            $cover = @(Get-ChildItem -LiteralPath $item.FullName -File -Filter '*.png' |
                    Where-Object { $_.Extension -eq '.png' } | Sort-Object Name)
            if ($cover.Count -gt 0) { $imagePath = $cover[0].FullName }

            [pscustomobject][ordered]@{ Name = $item.Name; Path = $main.FullName; Root = $item.FullName; ImagePath = $imagePath }
            continue
        }

        if ($item.Extension -notin @('.xci', '.nsp')) { continue }
        if ($item.Extension -eq '.nsp') {
            $titleId = Read-NspTitleId -Path $item.FullName
            if ($null -ne $titleId -and ($titleId -band 0x1FFF) -ne 0) {
                Write-Verbose "Übersprungen, Update oder DLC (Titel-ID $('{0:X16}' -f $titleId)): $($item.Name)"
                continue
            }
        }

        $cover = Join-Path $item.DirectoryName ($item.BaseName + '.png')
        if (Test-Path -LiteralPath $cover -PathType Leaf) { $imagePath = $cover }
        [pscustomobject][ordered]@{ Name = $item.BaseName; Path = $item.FullName; Root = $item.FullName; ImagePath = $imagePath }
    }
}
