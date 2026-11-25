BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\LichiiGamepad\LichiiGamepad.psd1') -Force

    function New-TestState {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
        param([hashtable]$Override = @{})
        $state = [ordered]@{
            ApolloInstalled       = $true
            SudoVdaPresent        = $true
            ViGEmBusRunning       = $true
            LichiiExecutableFound = $true
            ApolloConfig          = @{
                dd_configuration_option         = 'ensure_active'
                isolated_virtual_display_option = 'enabled'
                mouse                           = 'disabled'
                keyboard                        = 'disabled'
            }
            ApolloApps            = @(
                [pscustomobject]@{ Name = 'Spiel'; IsLichii = $true; VirtualDisplay = $true; ExecutablePath = 'C:\L\lichii.exe' }
            )
            LichiiConfig          = @{
                Controls = @{ enable_udp_controller = 'true'; udp_input_servers = '192.168.0.50:26760' }
            }
        }
        foreach ($key in $Override.Keys) { $state[$key] = $Override[$key] }
        [pscustomobject]$state
    }

    function Get-Check {
        param($State, [string]$Id)
        Get-LichiiGamepadHostCheck -State $State | Where-Object Id -eq $Id
    }
}

Describe 'Get-LichiiGamepadHostCheck' {
    It 'passes every check for a fully prepared host' {
        $checks = Get-LichiiGamepadHostCheck -State (New-TestState)
        $checks | Where-Object Status -ne 'Pass' | Should -BeNullOrEmpty
    }

    It 'returns objects with Id, Area, Status, Message and Fix' {
        $check = Get-LichiiGamepadHostCheck -State (New-TestState) | Select-Object -First 1
        $check.PSObject.Properties.Name | Should -Be @('Id', 'Area', 'Status', 'Message', 'Fix')
    }

    It 'fails when Apollo is missing' {
        (Get-Check (New-TestState @{ ApolloInstalled = $false }) 'apollo-installed').Status | Should -Be 'Fail'
    }

    It 'fails when the SudoVDA driver is missing' {
        (Get-Check (New-TestState @{ SudoVdaPresent = $false }) 'sudovda-present').Status | Should -Be 'Fail'
    }

    It 'warns when ViGEmBus is not running (fallback input only)' {
        (Get-Check (New-TestState @{ ViGEmBusRunning = $false }) 'vigembus-running').Status | Should -Be 'Warn'
    }

    It 'fails when no Lichii executable was found' {
        (Get-Check (New-TestState @{ LichiiExecutableFound = $false }) 'lichii-found').Status | Should -Be 'Fail'
    }

    Context 'isolation of the game display' {
        It 'warns when the game display becomes the primary display' {
            $state = New-TestState
            $state.ApolloConfig['dd_configuration_option'] = 'ensure_primary'
            $check = Get-Check $state 'display-not-primary'
            $check.Status | Should -Be 'Warn'
            $check.Fix | Should -Match 'ensure_active'
        }

        It 'warns when ensure_only_display would switch off the host monitors' {
            $state = New-TestState
            $state.ApolloConfig['dd_configuration_option'] = 'ensure_only_display'
            (Get-Check $state 'display-not-primary').Status | Should -Be 'Warn'
        }

        It 'passes when the option is absent (Apollo default)' {
            $state = New-TestState
            $state.ApolloConfig.Remove('dd_configuration_option')
            (Get-Check $state 'display-not-primary').Status | Should -Be 'Pass'
        }

        It 'warns when the virtual display is not isolated' {
            $state = New-TestState
            $state.ApolloConfig.Remove('isolated_virtual_display_option')
            (Get-Check $state 'display-isolated').Status | Should -Be 'Warn'
        }
    }

    Context 'isolation of input' {
        It 'warns when Apollo accepts mouse input (defaults to enabled)' {
            $state = New-TestState
            $state.ApolloConfig.Remove('mouse')
            (Get-Check $state 'apollo-mouse-disabled').Status | Should -Be 'Warn'
        }

        It 'warns when Apollo accepts keyboard input' {
            $state = New-TestState
            $state.ApolloConfig['keyboard'] = 'enabled'
            (Get-Check $state 'apollo-keyboard-disabled').Status | Should -Be 'Warn'
        }
    }

    Context 'game profiles' {
        It 'warns when no Apollo app starts Lichii' {
            $state = New-TestState @{ ApolloApps = @() }
            (Get-Check $state 'game-profile').Status | Should -Be 'Warn'
        }

        It 'warns when a Lichii profile does not use the virtual display' {
            $apps = @([pscustomobject]@{ Name = 'Spiel'; IsLichii = $true; VirtualDisplay = $false; ExecutablePath = 'x' })
            $check = Get-Check (New-TestState @{ ApolloApps = $apps }) 'game-profile'
            $check.Status | Should -Be 'Warn'
            $check.Message | Should -Match 'Spiel'
        }
    }

    Context 'DSU input channel in Lichii' {
        It 'warns when UDP controllers are disabled in Lichii' {
            $state = New-TestState
            $state.LichiiConfig['Controls']['enable_udp_controller'] = 'false'
            (Get-Check $state 'lichii-dsu-enabled').Status | Should -Be 'Warn'
        }

        It 'warns when Lichii only polls localhost for DSU' {
            $state = New-TestState
            $state.LichiiConfig['Controls']['udp_input_servers'] = '127.0.0.1:26760'
            (Get-Check $state 'lichii-dsu-server').Status | Should -Be 'Warn'
        }

        It 'warns once when the Lichii config file is missing' {
            $checks = Get-LichiiGamepadHostCheck -State (New-TestState @{ LichiiConfig = $null })
            $lichiiChecks = @($checks | Where-Object Id -like 'lichii-dsu*')
            $lichiiChecks.Count | Should -Be 1
            $lichiiChecks[0].Status | Should -Be 'Warn'
        }
    }
}
