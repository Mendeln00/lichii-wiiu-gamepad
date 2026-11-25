function Get-PlaybackDeviceName {
    <#
    .SYNOPSIS
        Returns the friendly names of all active playback devices, as Windows Core Audio reports them.
    .DESCRIPTION
        Thin wrapper around IMMDeviceEnumerator. Lichii's cubeb and SDL3 sinks compare
        output_device with exactly this name (PKEY_Device_FriendlyName). The PnP device
        name from Win32_PnPEntity can differ: VB-CABLE shows up there as
        "Lautsprecher (VB-Audio Virtual Cable)", in Core Audio as "CABLE Input (VB-Audio Virtual Cable)".
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if (-not ('LichiiGamepad.CoreAudio' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace LichiiGamepad
{
    [StructLayout(LayoutKind.Sequential)]
    internal struct PropertyKey { public Guid FormatId; public int PropertyId; }

    // Large enough for PROPVARIANT on x86 (16 bytes) and x64 (24 bytes).
    [StructLayout(LayoutKind.Explicit, Size = 24)]
    internal struct PropVariant { [FieldOffset(0)] public ushort VarType; [FieldOffset(8)] public IntPtr Pointer; }

    // Only the vtable slots up to the last method used are declared.
    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDeviceEnumerator
    {
        [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
    }

    [ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDeviceCollection
    {
        [PreserveSig] int GetCount(out int count);
        [PreserveSig] int Item(int index, out IMMDevice device);
    }

    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDevice
    {
        [PreserveSig] int Activate(ref Guid iid, int context, IntPtr parameters, [MarshalAs(UnmanagedType.IUnknown)] out object instance);
        [PreserveSig] int OpenPropertyStore(int access, out IPropertyStore store);
    }

    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IPropertyStore
    {
        [PreserveSig] int GetCount(out int count);
        [PreserveSig] int GetAt(int index, out PropertyKey key);
        [PreserveSig] int GetValue(ref PropertyKey key, out PropVariant value);
    }

    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    internal class MMDeviceEnumerator { }

    public static class CoreAudio
    {
        [DllImport("ole32.dll")]
        private static extern int PropVariantClear(ref PropVariant value);

        public static string[] GetActivePlaybackDeviceNames()
        {
            const int eRender = 0, DEVICE_STATE_ACTIVE = 1, STGM_READ = 0;
            const ushort VT_LPWSTR = 31;
            PropertyKey friendlyName = new PropertyKey();
            friendlyName.FormatId = new Guid("A45C254E-DF1C-4EFD-8020-67D146A850E0");
            friendlyName.PropertyId = 14;

            List<string> names = new List<string>();
            IMMDeviceEnumerator enumerator = (IMMDeviceEnumerator)new MMDeviceEnumerator();
            try
            {
                IMMDeviceCollection devices;
                Marshal.ThrowExceptionForHR(enumerator.EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, out devices));
                int count;
                Marshal.ThrowExceptionForHR(devices.GetCount(out count));
                for (int i = 0; i < count; i++)
                {
                    IMMDevice device;
                    Marshal.ThrowExceptionForHR(devices.Item(i, out device));
                    IPropertyStore store;
                    Marshal.ThrowExceptionForHR(device.OpenPropertyStore(STGM_READ, out store));
                    PropVariant value;
                    Marshal.ThrowExceptionForHR(store.GetValue(ref friendlyName, out value));
                    try
                    {
                        if (value.VarType == VT_LPWSTR) { names.Add(Marshal.PtrToStringUni(value.Pointer)); }
                    }
                    finally
                    {
                        PropVariantClear(ref value);
                    }
                    Marshal.ReleaseComObject(store);
                    Marshal.ReleaseComObject(device);
                }
                Marshal.ReleaseComObject(devices);
            }
            finally
            {
                Marshal.ReleaseComObject(enumerator);
            }
            return names.ToArray();
        }
    }
}
'@
    }
    [LichiiGamepad.CoreAudio]::GetActivePlaybackDeviceNames()
}
