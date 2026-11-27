@{
    RootModule        = 'LichiiGamepad.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '5d1f0d8e-3f7a-4b8e-9a51-2c6f1b7f4a10'
    Author            = 'lichii-wiiu-gamepad contributors'
    Description       = 'Host-side helpers to play Lichii on a Wii U GamePad: checks, setup and game profiles.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'ConvertFrom-ApolloConfig'
        'ConvertFrom-ApolloAppList'
        'ConvertFrom-LichiiConfig'
        'ConvertTo-LichiiInputProfile'
        'Get-LichiiGamepadHostCheck'
        'Get-LichiiGamepadHostState'
        'Merge-ApolloAppList'
        'Merge-ApolloConfig'
        'Merge-LichiiConfig'
        'New-LichiiGamepadGameProfile'
        'Set-LichiiGamepadApolloConfig'
        'Set-LichiiGamepadInputProfile'
        'Set-LichiiGamepadLichiiConfig'
        'Test-LichiiGamepadHost'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('WiiU', 'GamePad', 'Lichii', 'Apollo', 'Sunshine', 'Moonlight')
            LicenseUri = 'https://www.gnu.org/licenses/gpl-3.0.html'
            ProjectUri = 'https://github.com/Mendeln00/lichii-wiiu-gamepad'
        }
    }
}
