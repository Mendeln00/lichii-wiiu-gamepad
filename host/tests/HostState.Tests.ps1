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
}
