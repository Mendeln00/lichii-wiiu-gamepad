function ConvertTo-LichiiInputProfile {
    <#
    .SYNOPSIS
        Builds the settings of a Lichii input profile that plays a DSU pad as a Pro Controller.
    .DESCRIPTION
        Pure function. Returns an ordered hashtable with the keys of an input profile (config\input\<name>.ini,
        section [Controls], no player prefix) in Lichii's order. Prefixed with "player_0_" the same keys set
        player 1 in qt-config.ini.
        Without -ButtonMap every button follows Lichii's own mapping for a UDP controller
        (UDPClient::GetButtonMappingForDevice): the face buttons by position, so the right one (Circle) is A.
        Sticks and motion follow GetAnalogMappingForDevice and GetMotionMappingForDevice.
    .PARAMETER DsuServer
        DSU server of the bridge as "IPv4:port", as in Lichii's udp_input_servers.
    .PARAMETER Pad
        Lichii's pad number. Lichii counts four pads per server in the order of udp_input_servers,
        so slot 0 of the second server is pad 4.
    .PARAMETER ButtonMap
        Replaces single buttons: Lichii's key (button_a) to a DSU button (Circle).
        DSU buttons: Share, L3, R3, Options, Up, Right, Down, Left, L2, R2, L1, R1, Triangle, Circle,
        Cross, Square, Home, TouchHardPress.
    .EXAMPLE
        ConvertTo-LichiiInputProfile -DsuServer '127.0.0.1:26760'
    .EXAMPLE
        ConvertTo-LichiiInputProfile -DsuServer '127.0.0.1:26760' -ButtonMap @{ button_a = 'Cross'; button_b = 'Circle' }
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)][string]$DsuServer,
        [ValidateRange(0, 31)][int]$Pad = 0,
        [hashtable]$ButtonMap = @{}
    )

    # Bit values of Lichii's PadButton (input_common/drivers/udp_client.h), named like the DSU buttons.
    $dsuButton = [ordered]@{
        Share = 0x1; L3 = 0x2; R3 = 0x4; Options = 0x8; Up = 0x10; Right = 0x20; Down = 0x40; Left = 0x80
        L2 = 0x100; R2 = 0x200; L1 = 0x400; R1 = 0x800; Triangle = 0x1000; Circle = 0x2000; Cross = 0x4000; Square = 0x8000
        Home = 0x40000; TouchHardPress = 0x80000
    }

    # Lichii's button keys in the order of Settings::NativeButton, each with the DSU button Lichii maps to it.
    $mapping = [ordered]@{
        button_a = 'Circle'; button_b = 'Cross'; button_x = 'Triangle'; button_y = 'Square'
        button_lstick = 'L3'; button_rstick = 'R3'; button_l = 'L1'; button_r = 'R1'; button_zl = 'L2'; button_zr = 'R2'
        button_plus = 'Options'; button_minus = 'Share'
        button_dleft = 'Left'; button_dup = 'Up'; button_dright = 'Right'; button_ddown = 'Down'
        button_slleft = 'L2'; button_srleft = 'R2'; button_home = 'Home'; button_screenshot = 'TouchHardPress'
        button_slright = 'L2'; button_srright = 'R2'
    }

    foreach ($key in @($ButtonMap.Keys)) {
        if (-not $mapping.Contains($key)) {
            throw "Lichii kennt die Taste `"$key`" nicht. Möglich sind: $(@($mapping.Keys) -join ', ')."
        }
        $button = [string]$ButtonMap[$key]
        if (-not $dsuButton.Contains($button)) {
            throw "`"$button`" ist keine DSU-Taste. Möglich sind: $(@($dsuButton.Keys) -join ', ')."
        }
        $mapping[$key] = $button
    }

    $identifier = ConvertTo-DsuPadIdentifier -DsuServer $DsuServer
    $device = "engine:cemuhookudp,guid:$($identifier.Guid),port:$($identifier.Port),pad:$Pad"

    $result = [ordered]@{}
    foreach ($key in @($mapping.Keys)) {
        $result[$key] = "$device,button:$($dsuButton[$mapping[$key]])"
    }
    $result['lstick'] = "$device,axis_x:0,axis_y:1"
    $result['rstick'] = "$device,axis_x:2,axis_y:3"
    $result['motionleft'] = "$device,motion:0"
    $result['motionright'] = "$device,motion:0"
    # Settings::ControllerType::ProController: every button, both sticks and motion.
    $result['type'] = '0'
    $result
}
