BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LichiiGamepad\LichiiGamepad.psd1') -Force

    # Lichii's own mapping for a UDP controller (UDPClient::GetButtonMappingForDevice, Lichii fdc7cdaf).
    $script:LocalPad = 'engine:cemuhookudp,guid:0000000000000000000000007f000001,port:26760,pad:0'
}

Describe 'ConvertTo-LichiiInputProfile' {
    It 'maps <Key> to DSU button <Button> like Lichii''s automatic mapping' -ForEach @(
        @{ Key = 'button_a'; Button = 8192 }, @{ Key = 'button_b'; Button = 16384 }
        @{ Key = 'button_x'; Button = 4096 }, @{ Key = 'button_y'; Button = 32768 }
        @{ Key = 'button_lstick'; Button = 2 }, @{ Key = 'button_rstick'; Button = 4 }
        @{ Key = 'button_l'; Button = 1024 }, @{ Key = 'button_r'; Button = 2048 }
        @{ Key = 'button_zl'; Button = 256 }, @{ Key = 'button_zr'; Button = 512 }
        @{ Key = 'button_plus'; Button = 8 }, @{ Key = 'button_minus'; Button = 1 }
        @{ Key = 'button_dleft'; Button = 128 }, @{ Key = 'button_dup'; Button = 16 }
        @{ Key = 'button_dright'; Button = 32 }, @{ Key = 'button_ddown'; Button = 64 }
        @{ Key = 'button_slleft'; Button = 256 }, @{ Key = 'button_srleft'; Button = 512 }
        @{ Key = 'button_slright'; Button = 256 }, @{ Key = 'button_srright'; Button = 512 }
        @{ Key = 'button_home'; Button = 262144 }, @{ Key = 'button_screenshot'; Button = 524288 }
    ) {
        $result = ConvertTo-LichiiInputProfile -DsuServer '127.0.0.1:26760'
        $result[$Key] | Should -BeExactly "$LocalPad,button:$Button"
    }

    It 'maps both sticks and both motion inputs to the DSU pad' {
        $result = ConvertTo-LichiiInputProfile -DsuServer '127.0.0.1:26760'
        $result['lstick'] | Should -BeExactly "$LocalPad,axis_x:0,axis_y:1"
        $result['rstick'] | Should -BeExactly "$LocalPad,axis_x:2,axis_y:3"
        $result['motionleft'] | Should -BeExactly "$LocalPad,motion:0"
        $result['motionright'] | Should -BeExactly "$LocalPad,motion:0"
    }

    It 'makes the controller a Pro Controller' {
        (ConvertTo-LichiiInputProfile -DsuServer '127.0.0.1:26760')['type'] | Should -BeExactly '0'
    }

    It 'returns the keys in Lichii''s order' {
        $keys = @((ConvertTo-LichiiInputProfile -DsuServer '127.0.0.1:26760').Keys)
        $keys.Count | Should -Be 27
        $keys[0] | Should -Be 'button_a'
        $keys[21] | Should -Be 'button_srright'
        $keys[22..26] | Should -Be @('lstick', 'rstick', 'motionleft', 'motionright', 'type')
    }

    It 'derives the guid from the IPv4 address of the server, as Lichii does' {
        (ConvertTo-LichiiInputProfile -DsuServer '192.168.0.50:26761')['button_a'] |
            Should -BeExactly 'engine:cemuhookudp,guid:000000000000000000000000c0a80032,port:26761,pad:0,button:8192'
    }

    It 'uses an empty guid below 16.0.0.0, where Lichii''s UUID string is one digit short' {
        (ConvertTo-LichiiInputProfile -DsuServer '10.0.0.5:26760')['button_a'] |
            Should -BeExactly 'engine:cemuhookudp,guid:00000000000000000000000000000000,port:26760,pad:0,button:8192'
    }

    It 'uses the given pad number' {
        (ConvertTo-LichiiInputProfile -DsuServer '127.0.0.1:26760' -Pad 4)['lstick'] |
            Should -BeExactly 'engine:cemuhookudp,guid:0000000000000000000000007f000001,port:26760,pad:4,axis_x:0,axis_y:1'
    }

    It 'lets a button map replace single buttons and keeps the rest' {
        $result = ConvertTo-LichiiInputProfile -DsuServer '127.0.0.1:26760' -ButtonMap @{ button_a = 'Cross'; button_b = 'Circle' }
        $result['button_a'] | Should -BeExactly "$LocalPad,button:16384"
        $result['button_b'] | Should -BeExactly "$LocalPad,button:8192"
        $result['button_x'] | Should -BeExactly "$LocalPad,button:4096"
    }

    It 'rejects a button map with an unknown Switch button' {
        { ConvertTo-LichiiInputProfile -DsuServer '127.0.0.1:26760' -ButtonMap @{ button_c = 'Cross' } } |
            Should -Throw -ExpectedMessage '*button_c*'
    }

    It 'rejects a button map with an unknown DSU button' {
        { ConvertTo-LichiiInputProfile -DsuServer '127.0.0.1:26760' -ButtonMap @{ button_a = 'Kreis' } } |
            Should -Throw -ExpectedMessage '*Kreis*'
    }

    It 'rejects <DsuServer>, because Lichii only connects to IPv4 addresses with a port' -ForEach @(
        @{ DsuServer = 'localhost:26760' }, @{ DsuServer = '127.0.0.1' }, @{ DsuServer = '127.0.0.256:26760' }
        @{ DsuServer = '127.0.0.1:0' }, @{ DsuServer = '127.0.0.1:65536' }, @{ DsuServer = '::1:26760' }
    ) {
        { ConvertTo-LichiiInputProfile -DsuServer $DsuServer } | Should -Throw -ExpectedMessage '*DSU*'
    }
}

Describe 'Set-LichiiGamepadInputProfile' {
    BeforeEach {
        $script:ConfigDir = Join-Path $TestDrive 'config'
        Remove-Item -LiteralPath $ConfigDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $ConfigDir | Out-Null
        $script:Ini = Join-Path $ConfigDir 'qt-config.ini'
        Set-Content -LiteralPath $Ini -NoNewline -Value ("[Controls]`r`nenable_udp_controller\default=false`r`nenable_udp_controller=true`r`n" +
            "udp_input_servers\default=false`r`nudp_input_servers=`"192.168.0.50:26760,127.0.0.1:26760`"`r`n" +
            "player_0_button_a\default=true`r`nplayer_0_button_a=`"engine:keyboard,code:67,toggle:0`"`r`n`r`n[Audio]`r`noutput_device\default=true`r`noutput_device=auto`r`n")
        $script:ProfileFile = Join-Path $ConfigDir 'input\WiiU GamePad.ini'
        Mock Get-Process -ModuleName LichiiGamepad { }

        function Read-ControlSection([string]$Path) {
            (ConvertFrom-LichiiConfig -Text (Get-Content -LiteralPath $Path -Raw))['Controls']
        }
    }

    It 'writes the profile to config\input with Lichii''s default markers set to false' {
        Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -Confirm:$false
        $controls = Read-ControlSection $ProfileFile
        $controls['button_a'] | Should -BeExactly 'engine:cemuhookudp,guid:000000000000000000000000c0a80032,port:26760,pad:0,button:8192'
        $controls['button_a\default'] | Should -Be 'false'
        $controls['motionright\default'] | Should -Be 'false'
        $controls['type'] | Should -Be '0'
    }

    It 'quotes the values in the profile, as Lichii does for values with commas' {
        Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -Confirm:$false
        Get-Content -LiteralPath $ProfileFile | Should -Contain 'button_a="engine:cemuhookudp,guid:000000000000000000000000c0a80032,port:26760,pad:0,button:8192"'
    }

    It 'assigns the profile to player 1' {
        Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -Confirm:$false
        $controls = Read-ControlSection $Ini
        $controls['player_0_button_a'] | Should -BeExactly 'engine:cemuhookudp,guid:000000000000000000000000c0a80032,port:26760,pad:0,button:8192'
        $controls['player_0_button_a\default'] | Should -Be 'false'
        $controls['player_0_lstick'] | Should -Match 'axis_x:0,axis_y:1$'
        $controls['player_0_motionleft'] | Should -Match 'motion:0$'
        $controls['player_0_profile_name'] | Should -BeExactly 'WiiU GamePad'
        $controls['player_0_connected'] | Should -Be 'true'
        $controls['player_0_type'] | Should -Be '0'
    }

    It 'leaves the other settings in qt-config.ini alone' {
        Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -Confirm:$false
        $ini = ConvertFrom-LichiiConfig -Text (Get-Content -LiteralPath $Ini -Raw)
        $ini['Controls']['udp_input_servers'] | Should -Be '192.168.0.50:26760,127.0.0.1:26760'
        $ini['Audio']['output_device'] | Should -Be 'auto'
    }

    It 'uses pad 4 for the second DSU server, as Lichii counts four pads per server' {
        Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -DsuServer '127.0.0.1:26760' -Confirm:$false
        (Read-ControlSection $Ini)['player_0_button_a'] |
            Should -BeExactly 'engine:cemuhookudp,guid:0000000000000000000000007f000001,port:26760,pad:4,button:8192'
    }

    It 'uses Lichii''s default server 127.0.0.1:26760 when qt-config.ini sets none' {
        Set-Content -LiteralPath $Ini -Value "[Controls]`r`nudp_input_servers\default=true`r`nudp_input_servers=192.168.0.50:26760`r`n"
        Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -Confirm:$false
        (Read-ControlSection $Ini)['player_0_button_a'] | Should -BeExactly "$LocalPad,button:8192"
    }

    It 'refuses a DSU server that Lichii does not poll' {
        { Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -DsuServer '192.168.0.99:26760' -Confirm:$false } |
            Should -Throw -ExpectedMessage '*Set-LichiiGamepadLichiiConfig*'
        Test-Path -LiteralPath $ProfileFile | Should -BeFalse
    }

    It 'uses the given profile name' {
        Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -ProfileName 'GamePad 2' -Confirm:$false
        Test-Path -LiteralPath (Join-Path $ConfigDir 'input\GamePad 2.ini') | Should -BeTrue
        (Read-ControlSection $Ini)['player_0_profile_name'] | Should -BeExactly 'GamePad 2'
    }

    It 'rejects the profile name "<Name>"' -ForEach @(
        @{ Name = 'Handgerät' }, @{ Name = 'Pad<1>' }, @{ Name = 'Pad,1' }, @{ Name = 'Pad.1' }, @{ Name = 'Pad?' }
        @{ Name = 'Pad/1' }, @{ Name = 'Pad\1' }, @{ Name = 'Pad:1' }, @{ Name = ' Pad' }, @{ Name = 'Pad ' }
        @{ Name = 'CON' }, @{ Name = 'com1' }, @{ Name = '' }
    ) {
        { Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -ProfileName $Name -Confirm:$false } | Should -Throw
        Test-Path -LiteralPath (Join-Path $ConfigDir 'input') | Should -BeFalse
    }

    It 'refuses to overwrite a different profile with the same name' {
        New-Item -ItemType Directory -Path (Split-Path $ProfileFile) | Out-Null
        Set-Content -LiteralPath $ProfileFile -Value "[Controls]`r`nbutton_a\default=false`r`nbutton_a=`"engine:keyboard,code:65,toggle:0`"`r`n"
        $before = Get-Content -LiteralPath $ProfileFile -Raw
        { Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -Confirm:$false } | Should -Throw -ExpectedMessage '*-Force*'
        Get-Content -LiteralPath $ProfileFile -Raw | Should -BeExactly $before
        (Read-ControlSection $Ini)['player_0_profile_name'] | Should -BeNullOrEmpty
    }

    It 'overwrites a different profile with -Force and keeps a backup of it' {
        New-Item -ItemType Directory -Path (Split-Path $ProfileFile) | Out-Null
        Set-Content -LiteralPath $ProfileFile -Value "[Controls]`r`nbutton_a\default=false`r`nbutton_a=`"engine:keyboard,code:65,toggle:0`"`r`n"
        Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -Force -Confirm:$false
        (Read-ControlSection $ProfileFile)['button_a'] | Should -Match '^engine:cemuhookudp,'
        $backup = @(Get-ChildItem -LiteralPath (Split-Path $ProfileFile) -Filter 'WiiU GamePad.ini.*.bak')
        $backup.Count | Should -Be 1
        Get-Content -LiteralPath $backup[0].FullName -Raw | Should -Match 'engine:keyboard'
    }

    It 'runs again without -Force when the profile is already its own' {
        Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -Confirm:$false
        Get-ChildItem -LiteralPath $ConfigDir -Filter '*.bak' -Recurse | Remove-Item
        { Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -Confirm:$false } | Should -Not -Throw
        @(Get-ChildItem -LiteralPath $ConfigDir -Filter '*.bak' -Recurse).Count | Should -Be 0
    }

    It 'keeps a backup of qt-config.ini' {
        Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -Confirm:$false
        $backup = @(Get-ChildItem -LiteralPath $ConfigDir -Filter 'qt-config.ini.*.bak')
        $backup.Count | Should -Be 1
        Get-Content -LiteralPath $backup[0].FullName -Raw | Should -Match 'engine:keyboard'
    }

    It 'changes nothing with -WhatIf' {
        $before = Get-Content -LiteralPath $Ini -Raw
        Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -WhatIf
        Get-Content -LiteralPath $Ini -Raw | Should -BeExactly $before
        Test-Path -LiteralPath (Join-Path $ConfigDir 'input') | Should -BeFalse
        @(Get-ChildItem -LiteralPath $ConfigDir -Filter '*.bak').Count | Should -Be 0
    }

    It 'refuses to write while Lichii is running, because Lichii overwrites qt-config.ini on exit' {
        Mock Get-Process -ModuleName LichiiGamepad { [pscustomobject]@{ Name = 'lichii'; Id = 4242 } } -ParameterFilter { $Name -eq 'lichii' }
        $before = Get-Content -LiteralPath $Ini -Raw
        { Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -Confirm:$false } | Should -Throw -ExpectedMessage '*Lichii*beenden*'
        Get-Content -LiteralPath $Ini -Raw | Should -BeExactly $before
        Test-Path -LiteralPath $ProfileFile | Should -BeFalse
    }

    It 'fails clearly when qt-config.ini does not exist yet' {
        { Set-LichiiGamepadInputProfile -LichiiConfigPath (Join-Path $TestDrive 'missing\qt-config.ini') -Confirm:$false } |
            Should -Throw -ExpectedMessage '*qt-config.ini*Lichii*starten*'
    }

    It 'turns the host check for player 1 into a pass (acceptance of #52)' {
        Mock Get-CimInstance -ModuleName LichiiGamepad { }
        $stateArgs = @{ ApolloPath = (Join-Path $TestDrive 'no-apollo'); LichiiConfigPath = $Ini }
        (Get-LichiiGamepadHostState @stateArgs | Get-LichiiGamepadHostCheck | Where-Object Id -eq 'lichii-input-profile').Status |
            Should -Be 'Warn'

        Set-LichiiGamepadInputProfile -LichiiConfigPath $Ini -Confirm:$false

        (Get-LichiiGamepadHostState @stateArgs | Get-LichiiGamepadHostCheck | Where-Object Id -eq 'lichii-input-profile').Status |
            Should -Be 'Pass'
    }
}
