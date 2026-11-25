BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LichiiGamepad\LichiiGamepad.psd1') -Force
    $script:Fixtures = Join-Path $PSScriptRoot 'fixtures'
}

Describe 'ConvertFrom-ApolloConfig' {
    It 'reads key = value pairs and ignores comments and blank lines' {
        $text = Get-Content (Join-Path $Fixtures 'sunshine.conf') -Raw
        $config = ConvertFrom-ApolloConfig -Text $text

        $config['mouse'] | Should -Be 'disabled'
        $config['dd_configuration_option'] | Should -Be 'ensure_primary'
        $config.Keys | Should -Not -Contain '# Example Apollo config (placeholders only)'
    }

    It 'keeps values that contain = and JSON' {
        $config = ConvertFrom-ApolloConfig -Text 'server_cmd = [{"a":"b=c"}]'
        $config['server_cmd'] | Should -Be '[{"a":"b=c"}]'
    }

    It 'stores empty values as empty strings' {
        $config = ConvertFrom-ApolloConfig -Text 'audio_sink ='
        $config.ContainsKey('audio_sink') | Should -BeTrue
        $config['audio_sink'] | Should -Be ''
    }

    It 'returns an empty table for empty input' {
        (ConvertFrom-ApolloConfig -Text '').Count | Should -Be 0
    }

    It 'compares keys case-sensitively, like Apollo' {
        $config = ConvertFrom-ApolloConfig -Text "Mouse = disabled`n"
        $config.ContainsKey('mouse') | Should -BeFalse
        $config['Mouse'] | Should -Be 'disabled'
    }

    It 'keeps the first of two equal keys, like Apollo' {
        $config = ConvertFrom-ApolloConfig -Text "mouse = enabled`nmouse = disabled`n"
        $config['mouse'] | Should -Be 'enabled'
    }

    It 'cuts the value at an inline comment and keeps the blank before it, like Apollo' {
        $config = ConvertFrom-ApolloConfig -Text "mouse = enabled # set by hand`n"
        $config['mouse'] | Should -BeExactly 'enabled '
    }

    It 'ignores a line whose = only appears inside the comment' {
        (ConvertFrom-ApolloConfig -Text "locale # = de`n").Count | Should -Be 0
    }
}

Describe 'ConvertFrom-LichiiConfig' {
    BeforeAll {
        $text = Get-Content (Join-Path $Fixtures 'qt-config.ini') -Raw
        $script:Ini = ConvertFrom-LichiiConfig -Text $text
    }

    It 'groups keys by section' {
        $Ini['Controls']['enable_udp_controller'] | Should -Be 'false'
        $Ini['Audio']['output_device'] | Should -Be 'auto'
    }

    It 'keeps Qt default markers as separate keys' {
        $Ini['Controls']['enable_udp_controller\default'] | Should -Be 'true'
    }

    It 'strips surrounding quotes from values' {
        $Ini['Controls']['touch_device'] | Should -Be 'min_x:100,min_y:50,max_x:1800,max_y:850'
    }
}

Describe 'ConvertFrom-ApolloAppList' {
    BeforeAll {
        $json = Get-Content (Join-Path $Fixtures 'apps.json') -Raw
        $script:Apps = @(ConvertFrom-ApolloAppList -Json $json)
    }

    It 'returns one entry per app' {
        $Apps.Count | Should -Be 3
    }

    It 'detects Lichii game profiles and their executable' {
        $game = $Apps | Where-Object Name -eq 'Beispielspiel'
        $game.IsLichii | Should -BeTrue
        $game.ExecutablePath | Should -Be 'C:\Emulators\Lichii\lichii.exe'
        $game.VirtualDisplay | Should -BeTrue
    }

    It 'handles unquoted commands' {
        $other = $Apps | Where-Object Name -eq 'Ohne virtuelles Display'
        $other.ExecutablePath | Should -Be 'C:\Emulators\Lichii\lichii.exe'
        $other.VirtualDisplay | Should -BeFalse
    }

    It 'marks apps without a command as not Lichii' {
        ($Apps | Where-Object Name -eq 'Desktop').IsLichii | Should -BeFalse
    }
}
