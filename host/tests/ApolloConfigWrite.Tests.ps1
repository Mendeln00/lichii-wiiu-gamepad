BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LichiiGamepad\LichiiGamepad.psd1') -Force
}

Describe 'Merge-ApolloConfig' {
    It 'replaces an existing value in place' {
        $text = "locale = de`nmouse = enabled`ngamepad = x360`n"
        $result = Merge-ApolloConfig -Text $text -Setting @{ mouse = 'disabled' }
        $result | Should -Be "locale = de`nmouse = disabled`ngamepad = x360`n"
    }

    It 'appends missing keys at the end, keeping the trailing newline' {
        $result = Merge-ApolloConfig -Text "locale = de`n" -Setting @{ keyboard = 'disabled' }
        $result | Should -Be "locale = de`nkeyboard = disabled`n"
    }

    It 'leaves commented-out keys alone and appends the real setting' {
        $result = Merge-ApolloConfig -Text "# mouse = enabled`n" -Setting @{ mouse = 'disabled' }
        $result | Should -Be "# mouse = enabled`nmouse = disabled`n"
    }

    It 'keeps CRLF line endings' {
        $result = Merge-ApolloConfig -Text "mouse = enabled`r`n" -Setting @{ mouse = 'disabled'; keyboard = 'disabled' }
        $result | Should -Be "mouse = disabled`r`nkeyboard = disabled`r`n"
    }

    It 'appends missing keys in a stable, sorted order' {
        $result = Merge-ApolloConfig -Text '' -Setting @{ mouse = 'disabled'; keyboard = 'disabled' }
        $result | Should -Be "keyboard = disabled`nmouse = disabled`n"
    }

    It 'returns the text unchanged when every setting already matches' {
        $text = "# Apollo`nmouse = disabled`n"
        Merge-ApolloConfig -Text $text -Setting @{ mouse = 'disabled' } | Should -BeExactly $text
    }

    It 'matches keys case-sensitively, like Apollo does' {
        $result = Merge-ApolloConfig -Text "Mouse = enabled`n" -Setting @{ mouse = 'disabled' }
        $result | Should -BeExactly "Mouse = enabled`nmouse = disabled`n"
    }

    It 'moves an inline comment to its own line, because Apollo would keep the blank before it in the value' {
        $result = Merge-ApolloConfig -Text "mouse = enabled # set by hand`n" -Setting @{ mouse = 'disabled' }
        $result | Should -BeExactly "# set by hand`nmouse = disabled`n"
    }

    It 'keeps CRLF when it moves an inline comment' {
        $result = Merge-ApolloConfig -Text "mouse = enabled # set by hand`r`n" -Setting @{ mouse = 'disabled' }
        $result | Should -BeExactly "# set by hand`r`nmouse = disabled`r`n"
    }

    It 'updates every line of a repeated key' {
        $result = Merge-ApolloConfig -Text "mouse = enabled`nmouse = enabled`n" -Setting @{ mouse = 'disabled' }
        $result | Should -BeExactly "mouse = disabled`nmouse = disabled`n"
    }

    It 'does not add a newline to a file without one when nothing is appended' {
        Merge-ApolloConfig -Text 'mouse = enabled' -Setting @{ mouse = 'disabled' } | Should -BeExactly 'mouse = disabled'
    }
}

Describe 'Set-LichiiGamepadApolloConfig' {
    BeforeEach {
        $script:Apollo = Join-Path $TestDrive 'Apollo'
        if (Test-Path -LiteralPath $Apollo) { Remove-Item -LiteralPath $Apollo -Recurse -Force }
        New-Item -ItemType Directory -Path (Join-Path $Apollo 'config') -Force | Out-Null
        $script:Conf = Join-Path $Apollo 'config\sunshine.conf'
        Set-Content -LiteralPath $Conf -Value "dd_configuration_option = ensure_primary`r`nmouse = disabled" -Encoding UTF8
    }

    It 'writes the isolation settings from ADR 0004' {
        Set-LichiiGamepadApolloConfig -ApolloPath $Apollo -Confirm:$false
        $config = ConvertFrom-ApolloConfig -Text (Get-Content -LiteralPath $Conf -Raw)
        $config['dd_configuration_option'] | Should -Be 'ensure_active'
        $config['isolated_virtual_display_option'] | Should -Be 'enabled'
        $config['mouse'] | Should -Be 'disabled'
        $config['keyboard'] | Should -Be 'disabled'
    }

    It 'keeps a backup of the previous file' {
        Set-LichiiGamepadApolloConfig -ApolloPath $Apollo -Confirm:$false
        $backup = @(Get-ChildItem -LiteralPath (Split-Path $Conf) -Filter 'sunshine.conf.*.bak')
        $backup.Count | Should -Be 1
        Get-Content -LiteralPath $backup[0].FullName -Raw | Should -Match 'ensure_primary'
    }

    It 'changes nothing with -WhatIf' {
        $before = Get-Content -LiteralPath $Conf -Raw
        Set-LichiiGamepadApolloConfig -ApolloPath $Apollo -WhatIf
        Get-Content -LiteralPath $Conf -Raw | Should -BeExactly $before
        @(Get-ChildItem -LiteralPath (Split-Path $Conf) -Filter '*.bak').Count | Should -Be 0
    }

    It 'skips writing and backup when everything already matches' {
        Set-LichiiGamepadApolloConfig -ApolloPath $Apollo -Confirm:$false
        Get-ChildItem -LiteralPath (Split-Path $Conf) -Filter '*.bak' | Remove-Item
        Set-LichiiGamepadApolloConfig -ApolloPath $Apollo -Confirm:$false
        @(Get-ChildItem -LiteralPath (Split-Path $Conf) -Filter '*.bak').Count | Should -Be 0
    }

    It 'accepts a path relative to the current location' {
        Push-Location -LiteralPath $TestDrive
        try { Set-LichiiGamepadApolloConfig -ApolloPath 'Apollo' -Confirm:$false }
        finally { Pop-Location }
        (ConvertFrom-ApolloConfig -Text (Get-Content -LiteralPath $Conf -Raw))['keyboard'] | Should -Be 'disabled'
    }

    It 'explains a failed service restart, e.g. without administrator rights' {
        Mock Restart-Service -ModuleName LichiiGamepad { throw 'Cannot open ApolloService service on computer.' }
        { Set-LichiiGamepadApolloConfig -ApolloPath $Apollo -RestartService -Confirm:$false } |
            Should -Throw -ExpectedMessage '*ApolloService*Administrator*'
    }

    It 'fails clearly when sunshine.conf does not exist' {
        { Set-LichiiGamepadApolloConfig -ApolloPath (Join-Path $TestDrive 'missing') -Confirm:$false } |
            Should -Throw -ExpectedMessage '*sunshine.conf*'
    }
}
