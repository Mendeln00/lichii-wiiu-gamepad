BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LichiiGamepad\LichiiGamepad.psd1') -Force
}

Describe 'Get-LichiiGamepadHostState' {
    BeforeEach {
        Mock Get-CimInstance -ModuleName LichiiGamepad { }
        Mock Get-Service -ModuleName LichiiGamepad { }
        $script:StateArgs = @{
            ApolloPath       = (Join-Path $TestDrive 'no-apollo')
            LichiiConfigPath = (Join-Path $TestDrive 'no-config.ini')
        }
    }

    It 'lists the active playback devices by the name Lichii compares' {
        Mock Get-PlaybackDeviceName -ModuleName LichiiGamepad { 'CABLE Input (VB-Audio Virtual Cable)' }
        $state = Get-LichiiGamepadHostState @StateArgs
        , $state.PlaybackDevices | Should -BeOfType [object[]]
        $state.PlaybackDevices | Should -Be @('CABLE Input (VB-Audio Virtual Cable)')
    }

    It 'leaves the playback devices unknown when Windows cannot list them' {
        Mock Get-PlaybackDeviceName -ModuleName LichiiGamepad { throw 'Class not registered' }
        (Get-LichiiGamepadHostState @StateArgs).PlaybackDevices | Should -BeNullOrEmpty
        , (Get-LichiiGamepadHostState @StateArgs).PlaybackDevices | Should -Not -BeOfType [object[]]
    }

    Context 'per-game configs' {
        BeforeEach {
            Mock Get-PlaybackDeviceName -ModuleName LichiiGamepad { }
            $script:ConfigDir = Join-Path $TestDrive 'config'
            New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $ConfigDir 'qt-config.ini') -Value "[Audio]`r`noutput_device\default=true`r`noutput_device=auto"
            $StateArgs.LichiiConfigPath = Join-Path $ConfigDir 'qt-config.ini'
        }

        It 'reads the per-game configs next to qt-config.ini, keyed by title id' {
            New-Item -ItemType Directory -Path (Join-Path $ConfigDir 'custom') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $ConfigDir 'custom\0100187003A36000.ini') `
                -Value "[Audio]`r`noutput_device\use_global=false`r`noutput_device\default=false`r`noutput_device=CABLE Input (VB-Audio Virtual Cable)"
            $games = (Get-LichiiGamepadHostState @StateArgs).LichiiGameConfigs
            @($games.Keys) | Should -Be @('0100187003A36000')
            $games['0100187003A36000']['Audio']['output_device'] | Should -Be 'CABLE Input (VB-Audio Virtual Cable)'
        }

        It 'has no per-game configs when Lichii has not written any yet' {
            Remove-Item -LiteralPath (Join-Path $ConfigDir 'custom') -Recurse -Force -ErrorAction SilentlyContinue
            (Get-LichiiGamepadHostState @StateArgs).LichiiGameConfigs.Count | Should -Be 0
        }
    }
}
