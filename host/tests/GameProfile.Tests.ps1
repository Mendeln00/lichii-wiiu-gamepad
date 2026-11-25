BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LichiiGamepad\LichiiGamepad.psd1') -Force

    # Writes a minimal PFS0 header, the container format of .nsp files, that lists the given file names.
    function New-NspFile {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
        param([string]$Path, [string[]]$Names)
        $table = [System.Collections.Generic.List[byte]]::new()
        $offsets = @()
        foreach ($name in $Names) {
            $offsets += $table.Count
            $table.AddRange([System.Text.Encoding]::ASCII.GetBytes($name))
            $table.Add(0)
        }
        $bytes = [System.Collections.Generic.List[byte]]::new()
        $bytes.AddRange([System.Text.Encoding]::ASCII.GetBytes('PFS0'))
        $bytes.AddRange([BitConverter]::GetBytes([uint32]$Names.Count))
        $bytes.AddRange([BitConverter]::GetBytes([uint32]$table.Count))
        $bytes.AddRange([BitConverter]::GetBytes([uint32]0))
        foreach ($offset in $offsets) {
            $bytes.AddRange([BitConverter]::GetBytes([uint64]0))
            $bytes.AddRange([BitConverter]::GetBytes([uint64]0))
            $bytes.AddRange([BitConverter]::GetBytes([uint32]$offset))
            $bytes.AddRange([BitConverter]::GetBytes([uint32]0))
        }
        $bytes.AddRange($table)
        [System.IO.File]::WriteAllBytes($Path, $bytes.ToArray())
    }

    function New-File {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
        param([string]$Path)
        New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
        [System.IO.File]::WriteAllText($Path, '')
    }

    function Read-AppList {
        [System.IO.File]::ReadAllText($script:AppsFile) | ConvertFrom-Json
    }

    function Get-App {
        param([string]$Name)
        @((Read-AppList).apps) | Where-Object { $_.name -eq $Name }
    }

    # A games folder with a cartridge image, a base game, its update and DLC, an extracted game and noise.
    function New-TestLayout {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
        param([object[]]$ExistingApps = @())
        $script:Root = Join-Path $TestDrive 'layout'
        if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force }
        $script:Apollo = Join-Path $Root 'Apollo'
        $script:AppsFile = Join-Path $Apollo 'config\apps.json'
        $script:LichiiDir = Join-Path $Root 'Lichii'
        $script:Lichii = Join-Path $LichiiDir 'lichii.exe'
        $script:Games = Join-Path $Root 'Spiele'

        New-File $Lichii
        New-File (Join-Path $Games 'Spiel A.xci')
        New-File (Join-Path $Games 'Spiel A.png')
        New-NspFile (Join-Path $Games 'Spiel B.nsp') @('01000000000100000000000000000007.tik', 'aa.nca')
        New-File (Join-Path $Games 'Spiel B.jpg')
        New-NspFile (Join-Path $Games 'Spiel B Update.nsp') @('01000000000108000000000000000007.cert', '01000000000108000000000000000007.tik')
        New-NspFile (Join-Path $Games 'Spiel B DLC.nsp') @('01000000000110010000000000000007.tik')
        New-File (Join-Path $Games 'Spiel C.DUMP\base\exefs\main')
        New-File (Join-Path $Games 'Spiel C.DUMP\updates\65536\exefs\main')
        New-File (Join-Path $Games 'Spiel C.DUMP\updates\131072\exefs\main')
        New-File (Join-Path $Games 'Spiel C.DUMP\updates\131072\exefs\main.npdm')
        New-File (Join-Path $Games 'Spiel C.DUMP\cover.png')
        New-File (Join-Path $Games 'notes.txt')
        New-Item -ItemType Directory -Path (Join-Path $Games 'Leer') -Force | Out-Null

        $apps = @([pscustomobject]@{ name = 'Desktop'; 'image-path' = 'desktop.png'; uuid = 'D35C0000-0000-0000-0000-000000000001' }) + $ExistingApps
        $document = [pscustomobject][ordered]@{ env = [pscustomobject]@{}; apps = $apps; version = 2 }
        New-Item -ItemType Directory -Path (Split-Path $AppsFile) -Force | Out-Null
        [System.IO.File]::WriteAllText($AppsFile, ($document | ConvertTo-Json -Depth 10))
    }

    function Invoke-Profile {
        param([hashtable]$Extra = @{ LichiiPath = $script:Lichii })
        New-LichiiGamepadGameProfile -GamePath $script:Games -ApolloPath $script:Apollo -Confirm:$false @Extra 6>$null
    }
}

Describe 'New-LichiiGamepadGameProfile' {
    BeforeEach { New-TestLayout }

    It 'creates a profile for a cartridge image, a base game and an extracted game' {
        Invoke-Profile | Out-Null
        $names = @((Read-AppList).apps | ForEach-Object { $_.name })
        $names | Should -Be @('Desktop', 'Spiel A', 'Spiel B', 'Spiel C.DUMP')
    }

    It 'skips update and DLC files, recognised by the title ID in their ticket' {
        Invoke-Profile | Out-Null
        Get-App 'Spiel B Update' | Should -BeNullOrEmpty
        Get-App 'Spiel B DLC' | Should -BeNullOrEmpty
    }

    It 'writes what Apollo needs: quoted command, virtual display, uuid and the PNG cover' {
        Invoke-Profile | Out-Null
        $app = Get-App 'Spiel A'
        $app.cmd | Should -BeExactly "`"$Lichii`" -f -g `"$(Join-Path $Games 'Spiel A.xci')`""
        $app.'working-dir' | Should -BeExactly "`"$LichiiDir`""
        $app.'virtual-display' | Should -BeTrue
        $app.'image-path' | Should -BeExactly (Join-Path $Games 'Spiel A.png')
        $app.uuid | Should -MatchExactly '^[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}$'
    }

    It 'leaves out the cover when there is no PNG, because Apollo shows only PNG files' {
        Invoke-Profile | Out-Null
        (Get-App 'Spiel B').PSObject.Properties.Name | Should -Not -Contain 'image-path'
    }

    It 'starts the newest version of an extracted game and takes the PNG inside its folder' {
        Invoke-Profile | Out-Null
        $app = Get-App 'Spiel C.DUMP'
        $app.cmd | Should -BeLike "*-g `"$(Join-Path $Games 'Spiel C.DUMP\updates\131072\exefs\main')`""
        $app.'image-path' | Should -BeExactly (Join-Path $Games 'Spiel C.DUMP\cover.png')
    }

    It 'returns the new profiles' {
        $added = @(Invoke-Profile)
        @($added | ForEach-Object { $_.Name }) | Should -Be @('Spiel A', 'Spiel B', 'Spiel C.DUMP')
    }

    It 'is idempotent: a second run adds nothing and leaves the file alone' {
        Invoke-Profile | Out-Null
        $first = [System.IO.File]::ReadAllText($AppsFile)
        @(Invoke-Profile).Count | Should -Be 0
        [System.IO.File]::ReadAllText($AppsFile) | Should -BeExactly $first
        @(Get-ChildItem -LiteralPath (Split-Path $AppsFile) -Filter 'apps.json.*.bak').Count | Should -Be 1
    }

    It 'leaves a game alone that a profile already starts, whatever its name and case' {
        New-TestLayout -ExistingApps @([pscustomobject]@{
                name = 'Mein Spiel'; uuid = 'A0000000-0000-0000-0000-000000000001'
                cmd  = "`"$Lichii`" -f -g `"$((Join-Path $Games 'Spiel A.xci').ToUpperInvariant())`""
            })
        Invoke-Profile | Out-Null
        Get-App 'Spiel A' | Should -BeNullOrEmpty
        Get-App 'Mein Spiel' | Should -Not -BeNullOrEmpty
    }

    It 'counts an extracted game as covered when a profile starts any main inside its folder' {
        New-TestLayout -ExistingApps @([pscustomobject]@{
                name = 'Spiel C'; uuid = 'A0000000-0000-0000-0000-000000000002'
                cmd  = "`"$Lichii`" -f -g `"$(Join-Path $Games 'Spiel C.DUMP\base\exefs\main')`""
            })
        Invoke-Profile | Out-Null
        Get-App 'Spiel C.DUMP' | Should -BeNullOrEmpty
    }

    It 'keeps existing apps, their fields and the rest of the file' {
        New-TestLayout -ExistingApps @([pscustomobject][ordered]@{
                name       = 'Mit Vorbereitung'; uuid = 'A0000000-0000-0000-0000-000000000003'
                'prep-cmd' = @([pscustomobject]@{ do = 'a'; undo = 'b'; elevated = $false })
                detached   = @('c')
                'exit-timeout' = 5
            })
        $before = Read-AppList
        Invoke-Profile | Out-Null
        $after = Read-AppList
        $after.version | Should -Be 2
        ($after.apps[1] | ConvertTo-Json -Depth 10 -Compress) | Should -BeExactly ($before.apps[1] | ConvertTo-Json -Depth 10 -Compress)
        ($after.apps[0] | ConvertTo-Json -Depth 10 -Compress) | Should -BeExactly ($before.apps[0] | ConvertTo-Json -Depth 10 -Compress)
    }

    It 'keeps non-ASCII names and writes UTF-8 without BOM, which Apollo expects' {
        New-File (Join-Path $Games 'Spiel é.xci')
        Invoke-Profile | Out-Null
        [System.IO.File]::ReadAllBytes($AppsFile)[0] | Should -Be ([byte][char]'{')
        Get-App 'Spiel é' | Should -Not -BeNullOrEmpty
    }

    It 'takes lichii.exe from an existing profile when -LichiiPath is missing' {
        New-TestLayout -ExistingApps @([pscustomobject]@{
                name = 'Alt'; uuid = 'A0000000-0000-0000-0000-000000000004'
                cmd  = "`"$Lichii`" -f -g `"C:\woanders\alt.xci`""
            })
        Invoke-Profile -Extra @{} | Out-Null
        (Get-App 'Spiel A').cmd | Should -BeLike "`"$Lichii`"*"
    }

    It 'asks for -LichiiPath when no profile names lichii.exe' {
        { Invoke-Profile -Extra @{} } | Should -Throw '*-LichiiPath*'
    }

    It 'changes nothing with -WhatIf' {
        $before = [System.IO.File]::ReadAllText($AppsFile)
        New-LichiiGamepadGameProfile -GamePath $Games -LichiiPath $Lichii -ApolloPath $Apollo -WhatIf | Out-Null
        [System.IO.File]::ReadAllText($AppsFile) | Should -BeExactly $before
        @(Get-ChildItem -LiteralPath (Split-Path $AppsFile) -Filter '*.bak').Count | Should -Be 0
    }

    It 'explains when apps.json is missing' {
        Remove-Item -LiteralPath $AppsFile
        { Invoke-Profile } | Should -Throw '*apps.json*'
    }
}

Describe 'Merge-ApolloAppList' {
    BeforeAll {
        $script:Game = [pscustomobject]@{ Name = 'Spiel'; Path = 'C:\Spiele\spiel.xci'; Root = 'C:\Spiele\spiel.xci'; ImagePath = '' }
        $script:Empty = '{ "env": {}, "apps": [], "version": 2 }'
    }

    It 'returns the text unchanged when every game already has a profile' {
        $json = (Merge-ApolloAppList -Json $Empty -Game @($Game) -LichiiPath 'C:\L\lichii.exe').Json
        $again = Merge-ApolloAppList -Json $json -Game @($Game) -LichiiPath 'C:\L\lichii.exe'
        $again.Json | Should -BeExactly $json
        $again.Added.Count | Should -Be 0
    }

    It 'takes the uuid from the given generator' {
        $result = Merge-ApolloAppList -Json $Empty -Game @($Game) -LichiiPath 'C:\L\lichii.exe' -NewUuid { 'AAAA-BBBB' }
        ($result.Json | ConvertFrom-Json).apps[0].uuid | Should -Be 'AAAA-BBBB'
    }

    It 'accepts an empty game list' {
        (Merge-ApolloAppList -Json $Empty -Game @() -LichiiPath 'C:\L\lichii.exe').Json | Should -BeExactly $Empty
    }
}
