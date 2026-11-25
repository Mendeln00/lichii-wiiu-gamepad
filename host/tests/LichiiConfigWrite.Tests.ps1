BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LichiiGamepad\LichiiGamepad.psd1') -Force
}

Describe 'Merge-LichiiConfig' {
    It 'sets a value and clears its Qt default marker' {
        $text = "[Controls]`nenable_udp_controller\default=true`nenable_udp_controller=false`n"
        $result = Merge-LichiiConfig -Text $text -Section 'Controls' -Setting @{ enable_udp_controller = 'true' }
        $result | Should -BeExactly "[Controls]`nenable_udp_controller\default=false`nenable_udp_controller=true`n"
    }

    It 'leaves the same key in other sections alone' {
        $text = "[Other]`nmode=a`n`n[Controls]`nmode=a`n"
        $result = Merge-LichiiConfig -Text $text -Section 'Controls' -Setting @{ mode = 'b' }
        $result | Should -BeExactly "[Other]`nmode=a`n`n[Controls]`nmode\default=false`nmode=b`n"
    }

    It 'appends a missing key at the end of its section' {
        $text = "[Controls]`nother=1`n`n[Audio]`nvolume=1`n"
        $result = Merge-LichiiConfig -Text $text -Section 'Controls' -Setting @{ mode = 'b' }
        $result | Should -BeExactly "[Controls]`nother=1`nmode\default=false`nmode=b`n`n[Audio]`nvolume=1`n"
    }

    It 'adds the section when it is missing' {
        $result = Merge-LichiiConfig -Text "[Audio]`nvolume=1`n" -Section 'Controls' -Setting @{ mode = 'b' }
        $result | Should -BeExactly "[Audio]`nvolume=1`n`n[Controls]`nmode\default=false`nmode=b`n"
    }

    It 'quotes values with commas, as Qt does, so they are not read as a list' {
        $text = "[Controls]`ntouch_device\default=true`ntouch_device=`"min_x:100,min_y:50,max_x:1800,max_y:850`"`n"
        $result = Merge-LichiiConfig -Text $text -Section 'Controls' -Setting @{ touch_device = 'min_x:0,min_y:0,max_x:1919,max_y:941' }
        $result | Should -BeExactly "[Controls]`ntouch_device\default=false`ntouch_device=`"min_x:0,min_y:0,max_x:1919,max_y:941`"`n"
    }

    It 'keeps CRLF line endings, also when the file does not end with a newline' {
        $result = Merge-LichiiConfig -Text "[Controls]`r`nother=1" -Section 'Controls' -Setting @{ mode = 'b' }
        $result | Should -BeExactly "[Controls]`r`nother=1`r`nmode\default=false`r`nmode=b"
    }

    It 'returns the text unchanged when every setting already matches' {
        $text = "[Controls]`r`nmode\default=false`r`nmode=b`r`n"
        Merge-LichiiConfig -Text $text -Section 'Controls' -Setting @{ mode = 'b' } | Should -BeExactly $text
    }
}

Describe 'Set-LichiiGamepadLichiiConfig' {
    BeforeEach {
        $script:Ini = Join-Path $TestDrive 'qt-config.ini'
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures\qt-config.ini') -Destination $Ini -Force
        Get-ChildItem -LiteralPath $TestDrive -Filter '*.bak' | Remove-Item
        Remove-Item -LiteralPath (Join-Path $TestDrive 'custom') -Recurse -Force -ErrorAction SilentlyContinue
        Mock Get-Process -ModuleName LichiiGamepad { }
        Mock Get-PlaybackDeviceName -ModuleName LichiiGamepad { 'Lautsprecher (Realtek(R) Audio)'; 'CABLE Input (VB-Audio Virtual Cable)' }
    }

    It 'turns on DSU for the local bridge with Toffee''s touch range by default' {
        Set-LichiiGamepadLichiiConfig -LichiiConfigPath $Ini -Confirm:$false
        $controls = (ConvertFrom-LichiiConfig -Text (Get-Content -LiteralPath $Ini -Raw))['Controls']
        $controls['enable_udp_controller'] | Should -Be 'true'
        $controls['enable_udp_controller\default'] | Should -Be 'false'
        $controls['udp_input_servers'] | Should -Be '127.0.0.1:26760'
        $controls['udp_input_servers\default'] | Should -Be 'false'
        $controls['touch_device'] | Should -Be 'min_x:0,min_y:0,max_x:1919,max_y:941'
        $controls['touch_device\default'] | Should -Be 'false'
    }

    It 'sends the game audio to its own device with -AudioDevice' {
        Set-LichiiGamepadLichiiConfig -LichiiConfigPath $Ini -AudioDevice 'CABLE Input (VB-Audio Virtual Cable)' -Confirm:$false
        $audio = (ConvertFrom-LichiiConfig -Text (Get-Content -LiteralPath $Ini -Raw))['Audio']
        $audio['output_device'] | Should -Be 'CABLE Input (VB-Audio Virtual Cable)'
        $audio['output_device\default'] | Should -Be 'false'
    }

    It 'leaves the audio output alone without -AudioDevice, so the game stays audible until the bridge records that device' {
        Set-LichiiGamepadLichiiConfig -LichiiConfigPath $Ini -Confirm:$false
        $audio = (ConvertFrom-LichiiConfig -Text (Get-Content -LiteralPath $Ini -Raw))['Audio']
        $audio['output_device\default'] | Should -Be 'true'
    }

    It 'warns when no active playback device has that exact name' {
        Set-LichiiGamepadLichiiConfig -LichiiConfigPath $Ini -AudioDevice 'CABLE Input' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
        "$warnings" | Should -Match ([regex]::Escape('CABLE Input (VB-Audio Virtual Cable)'))
    }

    It 'warns about games that keep their own output device and would not follow -AudioDevice' {
        New-Item -ItemType Directory -Path (Join-Path $TestDrive 'custom') | Out-Null
        Set-Content -LiteralPath (Join-Path $TestDrive 'custom\0100187003A36000.ini') `
            -Value "[Audio]`r`noutput_device\use_global=false`r`noutput_device\default=false`r`noutput_device=Lautsprecher (Realtek(R) Audio)"
        Set-LichiiGamepadLichiiConfig -LichiiConfigPath $Ini -AudioDevice 'CABLE Input (VB-Audio Virtual Cable)' -Confirm:$false `
            -WarningVariable warnings -WarningAction SilentlyContinue
        "$warnings" | Should -Match '0100187003A36000'
    }

    It 'refuses to write while Lichii is running, because Lichii overwrites the file on exit' {
        Mock Get-Process -ModuleName LichiiGamepad { [pscustomobject]@{ Name = 'lichii'; Id = 4242 } } -ParameterFilter { $Name -eq 'lichii' }
        $before = Get-Content -LiteralPath $Ini -Raw
        { Set-LichiiGamepadLichiiConfig -LichiiConfigPath $Ini -Confirm:$false } | Should -Throw -ExpectedMessage '*Lichii*beenden*'
        Get-Content -LiteralPath $Ini -Raw | Should -BeExactly $before
    }

    It 'keeps a backup of the previous file' {
        Set-LichiiGamepadLichiiConfig -LichiiConfigPath $Ini -Confirm:$false
        $backup = @(Get-ChildItem -LiteralPath $TestDrive -Filter 'qt-config.ini.*.bak')
        $backup.Count | Should -Be 1
        Get-Content -LiteralPath $backup[0].FullName -Raw | Should -Match 'enable_udp_controller=false'
    }

    It 'changes nothing with -WhatIf' {
        $before = Get-Content -LiteralPath $Ini -Raw
        Set-LichiiGamepadLichiiConfig -LichiiConfigPath $Ini -WhatIf
        Get-Content -LiteralPath $Ini -Raw | Should -BeExactly $before
        @(Get-ChildItem -LiteralPath $TestDrive -Filter '*.bak').Count | Should -Be 0
    }

    It 'skips writing and backup when everything already matches' {
        Set-LichiiGamepadLichiiConfig -LichiiConfigPath $Ini -Confirm:$false
        Get-ChildItem -LiteralPath $TestDrive -Filter '*.bak' | Remove-Item
        Set-LichiiGamepadLichiiConfig -LichiiConfigPath $Ini -Confirm:$false
        @(Get-ChildItem -LiteralPath $TestDrive -Filter '*.bak').Count | Should -Be 0
    }

    It 'fails clearly when qt-config.ini does not exist yet' {
        { Set-LichiiGamepadLichiiConfig -LichiiConfigPath (Join-Path $TestDrive 'missing\qt-config.ini') -Confirm:$false } |
            Should -Throw -ExpectedMessage '*qt-config.ini*Lichii*starten*'
    }

    It 'leaves no DSU warnings in the host check (acceptance of #14)' {
        Mock Get-CimInstance -ModuleName LichiiGamepad { }
        $stateArgs = @{ ApolloPath = (Join-Path $TestDrive 'no-apollo'); LichiiConfigPath = $Ini }
        $before = Get-LichiiGamepadHostState @stateArgs | Get-LichiiGamepadHostCheck | Where-Object Id -like 'lichii-dsu*'
        @($before | Where-Object Status -ne 'Pass').Count | Should -BeGreaterThan 0

        Set-LichiiGamepadLichiiConfig -LichiiConfigPath $Ini -Confirm:$false

        $after = Get-LichiiGamepadHostState @stateArgs | Get-LichiiGamepadHostCheck | Where-Object Id -like 'lichii-dsu*'
        @($after).Count | Should -Be 2
        $after | Where-Object Status -ne 'Pass' | Should -BeNullOrEmpty
    }

    It 'turns the audio warning into a pass with -AudioDevice (acceptance of #15, Lichii side)' {
        Mock Get-CimInstance -ModuleName LichiiGamepad { }
        $stateArgs = @{ ApolloPath = (Join-Path $TestDrive 'no-apollo'); LichiiConfigPath = $Ini }
        (Get-LichiiGamepadHostState @stateArgs | Get-LichiiGamepadHostCheck | Where-Object Id -eq 'audio-isolated').Status |
            Should -Be 'Warn'

        Set-LichiiGamepadLichiiConfig -LichiiConfigPath $Ini -AudioDevice 'CABLE Input (VB-Audio Virtual Cable)' -Confirm:$false

        (Get-LichiiGamepadHostState @stateArgs | Get-LichiiGamepadHostCheck | Where-Object Id -eq 'audio-isolated').Status |
            Should -Be 'Pass'
    }
}
