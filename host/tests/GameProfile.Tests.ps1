BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LichiiGamepad\LichiiGamepad.psd1') -Force

    # Writes a PFS0 container, the format of .nsp files, with the given file names and optional contents.
    function New-NspFile {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
        param([string]$Path, [string[]]$Names, [hashtable]$Data = @{})
        $table = [System.Collections.Generic.List[byte]]::new()
        $content = [System.Collections.Generic.List[byte]]::new()
        $entries = @()
        foreach ($name in $Names) {
            $bytes = [byte[]]@()
            if ($Data.ContainsKey($name)) { $bytes = [byte[]]$Data[$name] }
            $entries += , @($content.Count, $bytes.Length, $table.Count)
            $content.AddRange($bytes)
            $table.AddRange([System.Text.Encoding]::ASCII.GetBytes($name))
            $table.Add(0)
        }
        $file = [System.Collections.Generic.List[byte]]::new()
        $file.AddRange([System.Text.Encoding]::ASCII.GetBytes('PFS0'))
        $file.AddRange([BitConverter]::GetBytes([uint32]$Names.Count))
        $file.AddRange([BitConverter]::GetBytes([uint32]$table.Count))
        $file.AddRange([BitConverter]::GetBytes([uint32]0))
        foreach ($entry in $entries) {
            $file.AddRange([BitConverter]::GetBytes([uint64]$entry[0]))
            $file.AddRange([BitConverter]::GetBytes([uint64]$entry[1]))
            $file.AddRange([BitConverter]::GetBytes([uint32]$entry[2]))
            $file.AddRange([BitConverter]::GetBytes([uint32]0))
        }
        $file.AddRange($table)
        $file.AddRange($content)
        [System.IO.File]::WriteAllBytes($Path, $file.ToArray())
    }

    # A made-up header_key for the tests, not a real one.
    $script:TestKey = [byte[]](0..31)
    $script:TestKeyHex = -join ($TestKey | ForEach-Object { '{0:x2}' -f $_ })

    # The encrypted header of a content meta NCA (.cnmt.nca) for the given title ID.
    function Get-CnmtHeader {
        param([uint64]$ProgramId)
        $plain = New-Object byte[] 0x400
        [System.Text.Encoding]::ASCII.GetBytes('NCA3').CopyTo($plain, 0x200)
        $plain[0x205] = 1
        [BitConverter]::GetBytes($ProgramId).CopyTo($plain, 0x210)
        InModuleScope LichiiGamepad -Parameters @{ Plain = $plain; Key = $script:TestKey } {
            param($Plain, $Key)
            , (Invoke-AesXtsTransform -Data $Plain -Key $Key -Encrypt)
        }
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

    # Never reads the real prod.keys of this PC: KeysPath points to a test file unless a test says otherwise.
    function Invoke-Profile {
        [CmdletBinding()]
        param([hashtable]$Extra = @{ LichiiPath = $script:Lichii })
        $arguments = @{ KeysPath = (Join-Path $TestDrive 'fehlt.keys') }
        foreach ($key in $Extra.Keys) { $arguments[$key] = $Extra[$key] }
        New-LichiiGamepadGameProfile -GamePath $script:Games -ApolloPath $script:Apollo -Confirm:$false @arguments 6>$null
    }

    # A GameDB with the Switch game "Spiel B" (ID 11) and its DLC (ID 12). The entry "Spiel B" with
    # ID 10 ranks first but has neither platforms nor a cover, as some GameDB records do.
    function Get-FakeGameDb {
        param([string]$Path)
        switch ($Path) {
            'buckets/sp.json' {
                [pscustomobject]@{
                    '10' = [pscustomobject]@{ name = 'Spiel B' }
                    '11' = [pscustomobject]@{ name = 'Spiel B' }
                    '12' = [pscustomobject]@{ name = 'Spiel B: Erweiterung' }
                }
            }
            'games/10.json' { [pscustomobject]@{ name = 'Spiel B' } }
            'games/11.json' {
                [pscustomobject]@{ name = 'Spiel B'; platforms = @(130); cover = [pscustomobject]@{ url = '//images.igdb.com/igdb/image/upload/t_thumb/cob11.jpg' } }
            }
            'games/12.json' {
                [pscustomobject]@{ name = 'Spiel B: Erweiterung'; platforms = @(130); cover = [pscustomobject]@{ url = '//images.igdb.com/igdb/image/upload/t_thumb/cob12.jpg' } }
            }
            default { [pscustomobject]@{} }
        }
    }
}

Describe 'New-LichiiGamepadGameProfile' {
    BeforeAll {
        # No test goes online: an empty GameDB unless a test brings its own.
        Mock -ModuleName LichiiGamepad Invoke-GameDbRequest { [pscustomobject]@{} }
        Mock -ModuleName LichiiGamepad Save-WebFile { [System.IO.File]::WriteAllBytes($Path, [byte[]](137, 80, 78, 71)) }
    }

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

    It 'leaves out the cover when there is no PNG and none online, because Apollo shows only PNG files' {
        Invoke-Profile | Out-Null
        (Get-App 'Spiel B').PSObject.Properties.Name | Should -Not -Contain 'image-path'
    }

    Context '.nsp without a ticket' {
        BeforeEach {
            New-NspFile (Join-Path $Games 'Spiel D.nsp') @('dd.cnmt.nca') @{ 'dd.cnmt.nca' = (Get-CnmtHeader -ProgramId 0x0100000000020000) }
            New-NspFile (Join-Path $Games 'Spiel D Update.nsp') @('aa.nca', 'ee.cnmt.nca') @{
                'aa.nca'      = (New-Object byte[] 0x400)
                'ee.cnmt.nca' = (Get-CnmtHeader -ProgramId 0x0100000000020800)
            }
            $script:Keys = Join-Path $TestDrive 'prod.keys'
            [System.IO.File]::WriteAllText($Keys, "header_key = $TestKeyHex`r`nother_key = 00`r`n")
        }

        It 'reads the title ID from the content meta with the header_key from prod.keys and skips the update' {
            Invoke-Profile -Extra @{ LichiiPath = $Lichii; KeysPath = $Keys } | Out-Null
            Get-App 'Spiel D' | Should -Not -BeNullOrEmpty
            Get-App 'Spiel D Update' | Should -BeNullOrEmpty
        }

        It 'gives no profile and warns when prod.keys is missing, because it may be an update' {
            Invoke-Profile -Extra @{ LichiiPath = $Lichii } -WarningVariable warnings 3>$null | Out-Null
            Get-App 'Spiel D' | Should -BeNullOrEmpty
            Get-App 'Spiel D Update' | Should -BeNullOrEmpty
            ($warnings -join "`n") | Should -Match 'Spiel D Update\.nsp.*prod\.keys'
        }

        It 'gives no profile when the key is wrong' {
            [System.IO.File]::WriteAllText($Keys, "header_key = $('ab' * 32)`r`n")
            Invoke-Profile -Extra @{ LichiiPath = $Lichii; KeysPath = $Keys } 3>$null | Out-Null
            Get-App 'Spiel D Update' | Should -BeNullOrEmpty
        }
    }

    Context 'cover from the internet' {
        BeforeEach {
            Mock -ModuleName LichiiGamepad Invoke-GameDbRequest { Get-FakeGameDb -Path $Path }
            $script:CoverFile = Join-Path $Apollo 'config\covers\igdb_11.png'
        }

        It 'downloads the Switch box art as PNG into Apollo''s covers folder, the way Apollo does' {
            Invoke-Profile | Out-Null
            Should -Invoke -ModuleName LichiiGamepad Save-WebFile -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://images.igdb.com/igdb/image/upload/t_cover_big_2x/cob11.png' -and $Path -eq $CoverFile
            }
            (Get-App 'Spiel B').'image-path' | Should -BeExactly $CoverFile
        }

        It 'looks up only games without a PNG of their own' {
            Invoke-Profile | Out-Null
            Should -Invoke -ModuleName LichiiGamepad Save-WebFile -Times 1 -Exactly
            (Get-App 'Spiel A').'image-path' | Should -BeExactly (Join-Path $Games 'Spiel A.png')
        }

        It 'takes only covers for Nintendo Switch' {
            Mock -ModuleName LichiiGamepad Invoke-GameDbRequest {
                if ($Path -like 'games/*') { [pscustomobject]@{ name = 'Spiel B'; platforms = @(6); cover = [pscustomobject]@{ url = '//x/t_thumb/pc.jpg' } } }
                else { Get-FakeGameDb -Path $Path }
            }
            Invoke-Profile | Out-Null
            Should -Invoke -ModuleName LichiiGamepad Save-WebFile -Times 0 -Exactly
            (Get-App 'Spiel B').PSObject.Properties.Name | Should -Not -Contain 'image-path'
        }

        It 'reuses a cover that is already in Apollo''s covers folder' {
            New-File $CoverFile
            Invoke-Profile | Out-Null
            Should -Invoke -ModuleName LichiiGamepad Save-WebFile -Times 0 -Exactly
            (Get-App 'Spiel B').'image-path' | Should -BeExactly $CoverFile
        }

        It 'creates the profile without a cover and warns when the search fails' {
            Mock -ModuleName LichiiGamepad Invoke-GameDbRequest { throw 'offline' }
            Invoke-Profile -WarningVariable warnings 3>$null | Out-Null
            Get-App 'Spiel B' | Should -Not -BeNullOrEmpty
            ($warnings -join "`n") | Should -Match 'Spiel B.*offline'
        }

        It 'makes no request with -SkipCoverDownload and downloads nothing with -WhatIf' {
            Invoke-Profile -Extra @{ LichiiPath = $Lichii; SkipCoverDownload = $true } | Out-Null
            Should -Invoke -ModuleName LichiiGamepad Invoke-GameDbRequest -Times 0 -Exactly
            New-TestLayout
            New-LichiiGamepadGameProfile -GamePath $Games -LichiiPath $Lichii -ApolloPath $Apollo -KeysPath (Join-Path $TestDrive 'fehlt.keys') -WhatIf 6>$null | Out-Null
            Should -Invoke -ModuleName LichiiGamepad Save-WebFile -Times 0 -Exactly
        }
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

Describe 'Cover search' {
    It 'reduces a file name to the words of the game: <Name>' -ForEach @(
        @{ Name = 'pokopia.v2.0.1a.DUMP'; Words = @('pokopia') }
        @{ Name = 'v-pokemon_lets_go_eevee'; Words = @('pokemon', 'lets', 'go', 'eevee') }
        @{ Name = "Pokémon: Let's Go, Eevee!"; Words = @('pokemon', 'lets', 'go', 'eevee') }
        @{ Name = 'Spiel [0100ABF008968000][v131072] (EUR)'; Words = @('spiel') }
    ) {
        InModuleScope LichiiGamepad -Parameters @{ Name = $Name } { param($Name) @(ConvertTo-GameSearchToken -Name $Name) } |
            Should -Be $Words
    }

    It 'prefers the game whose name lies fully in the file name over bundles and DLC' {
        $best = InModuleScope LichiiGamepad {
            $entries = @(
                [pscustomobject]@{ Id = 2; Name = "Pokémon: Let's Go, Eevee! + Poké Ball Plus Pack" }
                [pscustomobject]@{ Id = 3; Name = 'Pokémon Go' }
                [pscustomobject]@{ Id = 4; Name = 'Pokémon' }
                [pscustomobject]@{ Id = 1; Name = "Pokémon: Let's Go, Eevee!" }
            )
            @(Select-GameDbMatch -Name 'v-pokemon_lets_go_eevee' -Entry $entries)[0]
        }
        $best.Id | Should -Be 1
    }

    It 'finds the main game for a file with a title ID and version, not its expansion' {
        $best = InModuleScope LichiiGamepad {
            $entries = @(
                [pscustomobject]@{ Id = 135164; Name = 'Pokémon Sword: The Isle of Armor' }
                [pscustomobject]@{ Id = 294432; Name = 'Pokémon Sword and Shield' }
                [pscustomobject]@{ Id = 37382; Name = 'Pokémon Sword' }
            )
            @(Select-GameDbMatch -Name 'Pokemon Sword [0100ABF008968000][v0]' -Entry $entries)[0]
        }
        $best.Id | Should -Be 37382
    }

    It 'finds a GameDB name with accents and apostrophes for a plain file name' {
        Mock -ModuleName LichiiGamepad Invoke-GameDbRequest {
            switch ($Path) {
                'buckets/le.json' {
                    [pscustomobject]@{
                        '7' = [pscustomobject]@{ name = "Let’s Pokémon!" }
                        '8' = [pscustomobject]@{ name = 'Lemmings' }
                    }
                }
                'games/7.json' {
                    [pscustomobject]@{
                        name      = "Let’s Pokémon!"
                        platforms = @([pscustomobject]@{ id = 508 })
                        cover     = [pscustomobject]@{ url = '//images.igdb.com/igdb/image/upload/t_thumb/co7.jpg' }
                    }
                }
                default { [pscustomobject]@{} }
            }
        }
        $cover = InModuleScope LichiiGamepad { Find-GameCover -Name 'lets_pokemon' }
        $cover.Id | Should -Be 7
        $cover.Url | Should -BeExactly 'https://images.igdb.com/igdb/image/upload/t_cover_big_2x/co7.png'
    }

    It 'finds nothing for an unrelated name rather than a wrong cover' {
        InModuleScope LichiiGamepad {
            @(Select-GameDbMatch -Name 'Mein Spiel' -Entry @([pscustomobject]@{ Id = 1; Name = 'Pokémon Sword' }))
        } | Should -BeNullOrEmpty
    }
}

Describe 'NCA header decryption' {
    It 'matches the first XTS-AES-128 test vector of IEEE 1619 (sector 0, zero keys)' {
        $cipher = [byte[]]@(
            0x91, 0x7c, 0xf6, 0x9e, 0xbd, 0x68, 0xb2, 0xec, 0x9b, 0x9f, 0xe9, 0xa3, 0xea, 0xdd, 0xa6, 0x92,
            0xcd, 0x43, 0xd2, 0xf5, 0x95, 0x98, 0xed, 0x85, 0x8c, 0x02, 0xc2, 0x65, 0x2f, 0xbf, 0x92, 0x2e)
        $plain = InModuleScope LichiiGamepad -Parameters @{ Cipher = $cipher } {
            param($Cipher) , (Invoke-AesXtsTransform -Data $Cipher -Key (New-Object byte[] 32))
        }
        $plain | Should -Be (New-Object byte[] 32)
    }

    It 'reads ContentType and ProgramId from an encrypted header' {
        $header = Get-CnmtHeader -ProgramId 0x0100000000020800
        $nca = InModuleScope LichiiGamepad -Parameters @{ Header = $header; Key = $TestKey } {
            param($Header, $Key) ConvertFrom-NcaHeader -Bytes $Header -HeaderKey $Key
        }
        $nca.Magic | Should -Be 'NCA3'
        $nca.ContentType | Should -Be 1
        $nca.ProgramId | Should -Be 0x0100000000020800
    }
}
