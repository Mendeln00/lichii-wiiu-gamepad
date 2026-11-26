<#
.SYNOPSIS
    Measures what a process-loopback capture receives while the target process is muted in the Windows volume mixer.
.DESCRIPTION
    Captures the audio of one process tree with the Windows process-loopback API
    (AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK, Windows 10 build 20348 or later). A bridge such as
    Toffee would use the same API to take only Lichii's audio.

    While capturing, the script changes the audio sessions of the process in four phases: normal, muted,
    10 % volume, normal again. It uses ISimpleAudioVolume, the interface behind the per-app sliders and
    mute buttons of the Windows volume mixer. For every phase it reports packets, silent packets, peak
    and RMS level. At the end it restores the original volume and mute state.

    Research tool for issue #15, see research/audio-isolation.md. Needs no build and no installation.
.PARAMETER ProcessName
    Name of the process to capture, without .exe. Defaults to lichii.
.PARAMETER ProcessId
    ID of the process to capture, if several processes share the name.
.PARAMETER SelfTest
    Instead of Lichii, start a child process that plays a 440 Hz tone at -30 dBFS on ToneDevice and
    measure that. Checks the script and the Windows behaviour without Lichii.
.PARAMETER ToneDevice
    Playback device for the self-test tone, by its Core Audio name, e.g. "CABLE Input (VB-Audio Virtual Cable)".
    Defaults to the Windows default device: the tone is then audible, quietly.
.PARAMETER PhaseSeconds
    Length of each phase in seconds. Defaults to 5.
.PARAMETER Polling
    Read the capture buffer by polling every 10 ms instead of waiting on an event handle, the way Toffee reads.
.PARAMETER WavPath
    Also write everything captured (48 kHz, 16 bit, stereo) to this WAV file, for listening or for Audacity.
.PARAMETER PlayTone
    Internal: plays the self-test tone. Used by -SelfTest for its child process.
.EXAMPLE
    .\Measure-ProcessLoopback.ps1 -WavPath "$env:TEMP\lichii-loopback.wav"
.EXAMPLE
    .\Measure-ProcessLoopback.ps1 -SelfTest -ToneDevice 'CABLE Input (VB-Audio Virtual Cable)'
.EXAMPLE
    .\Measure-ProcessLoopback.ps1 -Polling
#>
[CmdletBinding(DefaultParameterSetName = 'ByName')]
param(
    [Parameter(ParameterSetName = 'ByName')][string]$ProcessName = 'lichii',
    [Parameter(ParameterSetName = 'ById', Mandatory)][int]$ProcessId,
    [Parameter(ParameterSetName = 'SelfTest', Mandatory)][switch]$SelfTest,
    [Parameter(ParameterSetName = 'SelfTest')][Parameter(ParameterSetName = 'Tone')][string]$ToneDevice,
    [ValidateRange(1, 60)][int]$PhaseSeconds = 5,
    [switch]$Polling,
    [string]$WavPath,
    [Parameter(ParameterSetName = 'Tone', Mandatory)][switch]$PlayTone
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$source = @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

namespace ProcessLoopbackProbe
{
    [StructLayout(LayoutKind.Sequential)]
    public struct PropertyKey { public Guid FormatId; public int PropertyId; }

    // Large enough for PROPVARIANT on x86 (16 bytes) and x64 (24 bytes).
    [StructLayout(LayoutKind.Explicit, Size = 24)]
    public struct PropVariant { [FieldOffset(0)] public ushort VarType; [FieldOffset(8)] public IntPtr Pointer; }

    // Only the vtable slots up to the last method used are declared.
    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDeviceEnumerator
    {
        [PreserveSig] int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
        [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
    }

    [ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDeviceCollection
    {
        [PreserveSig] int GetCount(out int count);
        [PreserveSig] int Item(int index, out IMMDevice device);
    }

    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDevice
    {
        [PreserveSig] int Activate(ref Guid iid, int context, IntPtr parameters, [MarshalAs(UnmanagedType.IUnknown)] out object instance);
        [PreserveSig] int OpenPropertyStore(int access, out IPropertyStore store);
    }

    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPropertyStore
    {
        [PreserveSig] int GetCount(out int count);
        [PreserveSig] int GetAt(int index, out PropertyKey key);
        [PreserveSig] int GetValue(ref PropertyKey key, out PropVariant value);
    }

    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    public class MMDeviceEnumerator { }

    [ComImport, Guid("1CB9AD4C-DBFA-4C32-B178-C2F568A703B2"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioClient
    {
        [PreserveSig] int Initialize(int shareMode, uint streamFlags, long bufferDuration, long periodicity, IntPtr format, IntPtr sessionGuid);
        [PreserveSig] int GetBufferSize(out uint frames);
        [PreserveSig] int GetStreamLatency(out long latency);
        [PreserveSig] int GetCurrentPadding(out uint frames);
        [PreserveSig] int IsFormatSupported(int shareMode, IntPtr format, out IntPtr closestMatch);
        [PreserveSig] int GetMixFormat(out IntPtr format);
        [PreserveSig] int GetDevicePeriod(out long defaultPeriod, out long minimumPeriod);
        [PreserveSig] int Start();
        [PreserveSig] int Stop();
        [PreserveSig] int Reset();
        [PreserveSig] int SetEventHandle(IntPtr eventHandle);
        [PreserveSig] int GetService(ref Guid iid, [MarshalAs(UnmanagedType.IUnknown)] out object service);
    }

    [ComImport, Guid("C8ADBD64-E71E-48A0-A4DE-185C395CD317"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioCaptureClient
    {
        [PreserveSig] int GetBuffer(out IntPtr data, out uint frames, out uint flags, out ulong devicePosition, out ulong qpcPosition);
        [PreserveSig] int ReleaseBuffer(uint frames);
        [PreserveSig] int GetNextPacketSize(out uint frames);
    }

    [ComImport, Guid("F294ACFC-3146-4483-A7BF-ADDCA7C260E2"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioRenderClient
    {
        [PreserveSig] int GetBuffer(uint frames, out IntPtr data);
        [PreserveSig] int ReleaseBuffer(uint frames, uint flags);
    }

    [ComImport, Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioSessionManager2
    {
        [PreserveSig] int GetAudioSessionControl(IntPtr sessionGuid, uint flags, out IntPtr control);
        [PreserveSig] int GetSimpleAudioVolume(IntPtr sessionGuid, uint flags, out IntPtr volume);
        [PreserveSig] int GetSessionEnumerator(out IAudioSessionEnumerator sessions);
    }

    [ComImport, Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioSessionEnumerator
    {
        [PreserveSig] int GetCount(out int count);
        [PreserveSig] int GetSession(int index, [MarshalAs(UnmanagedType.IUnknown)] out object session);
    }

    [ComImport, Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioSessionControl2
    {
        // IAudioSessionControl
        [PreserveSig] int GetState(out int state);
        [PreserveSig] int GetDisplayName(out IntPtr name);
        [PreserveSig] int SetDisplayName(IntPtr name, IntPtr context);
        [PreserveSig] int GetIconPath(out IntPtr path);
        [PreserveSig] int SetIconPath(IntPtr path, IntPtr context);
        [PreserveSig] int GetGroupingParam(out Guid grouping);
        [PreserveSig] int SetGroupingParam(IntPtr grouping, IntPtr context);
        [PreserveSig] int RegisterAudioSessionNotification(IntPtr client);
        [PreserveSig] int UnregisterAudioSessionNotification(IntPtr client);
        // IAudioSessionControl2
        [PreserveSig] int GetSessionIdentifier(out IntPtr id);
        [PreserveSig] int GetSessionInstanceIdentifier(out IntPtr id);
        [PreserveSig] int GetProcessId(out uint processId);
    }

    [ComImport, Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface ISimpleAudioVolume
    {
        [PreserveSig] int SetMasterVolume(float level, ref Guid context);
        [PreserveSig] int GetMasterVolume(out float level);
        [PreserveSig] int SetMute(int mute, ref Guid context);
        [PreserveSig] int GetMute(out int mute);
    }

    [ComImport, Guid("72A22D78-CDE4-431D-B8CC-843A71199B6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IActivateAudioInterfaceAsyncOperation
    {
        [PreserveSig] int GetActivateResult(out int activateResult, [MarshalAs(UnmanagedType.IUnknown)] out object activatedInterface);
    }

    [ComImport, Guid("41D949AB-9862-444A-80F6-C261334DA5EB"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IActivateAudioInterfaceCompletionHandler
    {
        [PreserveSig] int ActivateCompleted(IActivateAudioInterfaceAsyncOperation operation);
    }

    // Marks the completion handler as agile, as ActivateAudioInterfaceAsync requires.
    [ComImport, Guid("94EA2B94-E9CC-49E0-C0FF-EE64CA8F5B90"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAgileObject { }

    [ComVisible(true)]
    public sealed class ActivationHandler : IActivateAudioInterfaceCompletionHandler, IAgileObject
    {
        public readonly ManualResetEvent Completed = new ManualResetEvent(false);
        public int ActivateCompleted(IActivateAudioInterfaceAsyncOperation operation) { Completed.Set(); return 0; }
    }

    internal static class NativeMethods
    {
        [DllImport("Mmdevapi.dll", ExactSpelling = true)]
        public static extern int ActivateAudioInterfaceAsync(
            [MarshalAs(UnmanagedType.LPWStr)] string deviceInterfacePath, ref Guid riid, IntPtr activationParams,
            IActivateAudioInterfaceCompletionHandler completionHandler, out IActivateAudioInterfaceAsyncOperation operation);

        [DllImport("ole32.dll")]
        public static extern int PropVariantClear(ref PropVariant value);
    }

    internal static class Hr
    {
        public static void Check(int hr, string what)
        {
            if (hr < 0) { throw new COMException(what + " failed with 0x" + hr.ToString("X8"), hr); }
        }
    }

    // 48 kHz, 16 bit, stereo PCM for capture and tone alike. AUTOCONVERTPCM lets the audio engine convert.
    internal static class Pcm
    {
        public const int SampleRate = 48000;
        public const int Channels = 2;
        public const int BlockAlign = 4;

        public static IntPtr AllocFormat()
        {
            IntPtr format = Marshal.AllocCoTaskMem(18);
            Marshal.WriteInt16(format, 0, (short)1);
            Marshal.WriteInt16(format, 2, (short)Channels);
            Marshal.WriteInt32(format, 4, SampleRate);
            Marshal.WriteInt32(format, 8, SampleRate * BlockAlign);
            Marshal.WriteInt16(format, 12, (short)BlockAlign);
            Marshal.WriteInt16(format, 14, (short)16);
            Marshal.WriteInt16(format, 16, (short)0);
            return format;
        }

        public static void WriteWav(string path, byte[] data)
        {
            using (FileStream file = File.Create(path))
            using (BinaryWriter writer = new BinaryWriter(file))
            {
                writer.Write(new char[] { 'R', 'I', 'F', 'F' });
                writer.Write(36 + data.Length);
                writer.Write(new char[] { 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ' });
                writer.Write(16);
                writer.Write((short)1);
                writer.Write((short)Channels);
                writer.Write(SampleRate);
                writer.Write(SampleRate * BlockAlign);
                writer.Write((short)BlockAlign);
                writer.Write((short)16);
                writer.Write(new char[] { 'd', 'a', 't', 'a' });
                writer.Write(data.Length);
                writer.Write(data);
            }
        }
    }

    public sealed class PhaseStats
    {
        public string Name;
        public long Packets;
        public long SilentPackets;
        public long Frames;
        public double SumSquares;
        public int Peak;

        public double PeakDbfs { get { return Peak == 0 ? double.NegativeInfinity : 20 * Math.Log10(Peak / 32768.0); } }

        public double RmsDbfs
        {
            get
            {
                if (Frames == 0 || SumSquares == 0) { return double.NegativeInfinity; }
                return 20 * Math.Log10(Math.Sqrt(SumSquares / (Frames * Pcm.Channels)) / 32768.0);
            }
        }
    }

    public sealed class LoopbackCapture
    {
        private const uint StreamFlagsLoopback = 0x00020000u;
        private const uint StreamFlagsEventCallback = 0x00040000u;
        private const uint StreamFlagsAutoConvertPcm = 0x80000000u;
        private const uint BufferFlagsSilent = 0x2u;

        private readonly uint processId;
        private readonly bool polling;
        private readonly MemoryStream audio;
        private readonly object gate = new object();
        private readonly ManualResetEvent ready = new ManualResetEvent(false);
        private Thread thread;
        private volatile bool stopRequested;
        private PhaseStats current;

        public LoopbackCapture(uint processId, bool polling, bool keepAudio)
        {
            this.processId = processId;
            this.polling = polling;
            if (keepAudio) { audio = new MemoryStream(); }
        }

        public Exception Error { get; private set; }

        public void Start()
        {
            // Process loopback is activated asynchronously; a multithreaded apartment keeps the
            // activated IAudioClient usable on the capture thread.
            thread = new Thread(Run);
            thread.SetApartmentState(ApartmentState.MTA);
            thread.IsBackground = true;
            thread.Start();
            if (!ready.WaitOne(10000)) { throw new TimeoutException("Capture did not start within 10 s."); }
            if (Error != null) { throw new InvalidOperationException(Error.Message, Error); }
        }

        public void BeginPhase(PhaseStats stats) { lock (gate) { current = stats; } }

        public void EndPhase() { lock (gate) { current = null; } }

        public void Stop()
        {
            stopRequested = true;
            if (thread != null) { thread.Join(5000); }
        }

        public void SaveWav(string path)
        {
            if (audio == null) { return; }
            lock (gate) { Pcm.WriteWav(path, audio.ToArray()); }
        }

        private void Run()
        {
            IntPtr blob = IntPtr.Zero, variant = IntPtr.Zero, format = IntPtr.Zero;
            AutoResetEvent packetReady = null;
            try
            {
                // AUDIOCLIENT_ACTIVATION_PARAMS: type PROCESS_LOOPBACK (1), target process,
                // mode PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE (0).
                blob = Marshal.AllocCoTaskMem(12);
                Marshal.WriteInt32(blob, 0, 1);
                Marshal.WriteInt32(blob, 4, unchecked((int)processId));
                Marshal.WriteInt32(blob, 8, 0);

                // PROPVARIANT of type VT_BLOB pointing at those parameters.
                variant = Marshal.AllocCoTaskMem(24);
                for (int offset = 0; offset < 24; offset += 4) { Marshal.WriteInt32(variant, offset, 0); }
                Marshal.WriteInt16(variant, 0, (short)65);
                Marshal.WriteInt32(variant, 8, 12);
                Marshal.WriteIntPtr(variant, IntPtr.Size == 8 ? 16 : 12, blob);

                Guid clientIid = typeof(IAudioClient).GUID;
                ActivationHandler handler = new ActivationHandler();
                IActivateAudioInterfaceAsyncOperation operation;
                Hr.Check(NativeMethods.ActivateAudioInterfaceAsync(@"VAD\Process_Loopback", ref clientIid, variant, handler, out operation), "ActivateAudioInterfaceAsync");
                if (!handler.Completed.WaitOne(5000)) { throw new TimeoutException("Process loopback activation did not complete within 5 s."); }
                int activateResult;
                object instance;
                Hr.Check(operation.GetActivateResult(out activateResult, out instance), "GetActivateResult");
                Hr.Check(activateResult, "Process loopback activation");
                IAudioClient client = (IAudioClient)instance;

                format = Pcm.AllocFormat();
                uint flags = StreamFlagsLoopback | StreamFlagsAutoConvertPcm;
                if (!polling) { flags |= StreamFlagsEventCallback; }
                // Same buffer as Microsoft's ApplicationLoopback sample (20 ms); polling gets 100 ms of headroom.
                Hr.Check(client.Initialize(0, flags, polling ? 1000000 : 200000, 0, format, IntPtr.Zero), "IAudioClient.Initialize");
                if (!polling)
                {
                    packetReady = new AutoResetEvent(false);
                    Hr.Check(client.SetEventHandle(packetReady.SafeWaitHandle.DangerousGetHandle()), "IAudioClient.SetEventHandle");
                }

                Guid captureIid = typeof(IAudioCaptureClient).GUID;
                object service;
                Hr.Check(client.GetService(ref captureIid, out service), "IAudioClient.GetService");
                IAudioCaptureClient capture = (IAudioCaptureClient)service;

                Hr.Check(client.Start(), "IAudioClient.Start");
                ready.Set();
                while (!stopRequested)
                {
                    if (polling) { Thread.Sleep(10); } else { packetReady.WaitOne(100); }
                    Drain(capture);
                }
                client.Stop();
            }
            catch (Exception e)
            {
                Error = e;
            }
            finally
            {
                ready.Set();
                if (packetReady != null) { packetReady.Dispose(); }
                if (format != IntPtr.Zero) { Marshal.FreeCoTaskMem(format); }
                if (variant != IntPtr.Zero) { Marshal.FreeCoTaskMem(variant); }
                if (blob != IntPtr.Zero) { Marshal.FreeCoTaskMem(blob); }
            }
        }

        private void Drain(IAudioCaptureClient capture)
        {
            uint packetFrames;
            Hr.Check(capture.GetNextPacketSize(out packetFrames), "IAudioCaptureClient.GetNextPacketSize");
            while (packetFrames > 0)
            {
                IntPtr data;
                uint frames, flags;
                ulong devicePosition, qpcPosition;
                Hr.Check(capture.GetBuffer(out data, out frames, out flags, out devicePosition, out qpcPosition), "IAudioCaptureClient.GetBuffer");
                bool silent = (flags & BufferFlagsSilent) != 0;
                byte[] buffer = new byte[frames * Pcm.BlockAlign];
                if (!silent && buffer.Length > 0) { Marshal.Copy(data, buffer, 0, buffer.Length); }
                Hr.Check(capture.ReleaseBuffer(frames), "IAudioCaptureClient.ReleaseBuffer");
                Account(buffer, frames, silent);
                Hr.Check(capture.GetNextPacketSize(out packetFrames), "IAudioCaptureClient.GetNextPacketSize");
            }
        }

        private void Account(byte[] buffer, uint frames, bool silent)
        {
            lock (gate)
            {
                if (audio != null) { audio.Write(buffer, 0, buffer.Length); }
                PhaseStats stats = current;
                if (stats == null) { return; }
                stats.Packets++;
                stats.Frames += frames;
                if (silent) { stats.SilentPackets++; return; }
                for (int i = 0; i + 1 < buffer.Length; i += 2)
                {
                    int sample = (short)(buffer[i] | (buffer[i + 1] << 8));
                    int magnitude = sample < 0 ? -sample : sample;
                    if (magnitude > stats.Peak) { stats.Peak = magnitude; }
                    stats.SumSquares += (double)sample * sample;
                }
            }
        }
    }

    // The audio sessions of one process on all active playback devices, as the volume mixer shows them.
    public sealed class SessionSnapshot
    {
        private readonly List<ISimpleAudioVolume> controls = new List<ISimpleAudioVolume>();
        private readonly List<float> volumes = new List<float>();
        private readonly List<int> mutes = new List<int>();

        public int Count { get { return controls.Count; } }

        public string Describe()
        {
            List<string> parts = new List<string>();
            for (int i = 0; i < controls.Count; i++)
            {
                parts.Add(Math.Round(volumes[i] * 100) + " %" + (mutes[i] != 0 ? ", stumm" : ", nicht stumm"));
            }
            return string.Join("; ", parts.ToArray());
        }

        public static SessionSnapshot Take(uint processId)
        {
            SessionSnapshot snapshot = new SessionSnapshot();
            IMMDeviceEnumerator enumerator = (IMMDeviceEnumerator)new MMDeviceEnumerator();
            IMMDeviceCollection devices;
            Hr.Check(enumerator.EnumAudioEndpoints(0, 1, out devices), "EnumAudioEndpoints");
            int deviceCount;
            Hr.Check(devices.GetCount(out deviceCount), "IMMDeviceCollection.GetCount");
            Guid managerIid = typeof(IAudioSessionManager2).GUID;
            for (int d = 0; d < deviceCount; d++)
            {
                IMMDevice device;
                Hr.Check(devices.Item(d, out device), "IMMDeviceCollection.Item");
                object instance;
                Hr.Check(device.Activate(ref managerIid, 23, IntPtr.Zero, out instance), "IMMDevice.Activate");
                IAudioSessionEnumerator sessions;
                Hr.Check(((IAudioSessionManager2)instance).GetSessionEnumerator(out sessions), "GetSessionEnumerator");
                int sessionCount;
                Hr.Check(sessions.GetCount(out sessionCount), "IAudioSessionEnumerator.GetCount");
                for (int s = 0; s < sessionCount; s++)
                {
                    object session;
                    Hr.Check(sessions.GetSession(s, out session), "IAudioSessionEnumerator.GetSession");
                    IAudioSessionControl2 control = session as IAudioSessionControl2;
                    uint owner;
                    if (control == null || control.GetProcessId(out owner) < 0 || owner != processId) { continue; }
                    ISimpleAudioVolume volume = (ISimpleAudioVolume)session;
                    float level;
                    int mute;
                    Hr.Check(volume.GetMasterVolume(out level), "ISimpleAudioVolume.GetMasterVolume");
                    Hr.Check(volume.GetMute(out mute), "ISimpleAudioVolume.GetMute");
                    snapshot.controls.Add(volume);
                    snapshot.volumes.Add(level);
                    snapshot.mutes.Add(mute);
                }
            }
            return snapshot;
        }

        // A negative level keeps each session's original volume.
        public void Apply(bool mute, float level)
        {
            Guid context = Guid.Empty;
            for (int i = 0; i < controls.Count; i++)
            {
                Hr.Check(controls[i].SetMasterVolume(level < 0 ? volumes[i] : level, ref context), "ISimpleAudioVolume.SetMasterVolume");
                Hr.Check(controls[i].SetMute(mute ? 1 : 0, ref context), "ISimpleAudioVolume.SetMute");
            }
        }

        public void Restore()
        {
            Guid context = Guid.Empty;
            for (int i = 0; i < controls.Count; i++)
            {
                // Best effort: a session that ended in the meantime cannot be restored and needs no restoring.
                controls[i].SetMasterVolume(volumes[i], ref context);
                controls[i].SetMute(mutes[i], ref context);
            }
        }
    }

    public static class Tone
    {
        public static void Play(string deviceName, double levelDbfs, int seconds)
        {
            IMMDevice device = FindPlaybackDevice(deviceName);
            Guid clientIid = typeof(IAudioClient).GUID;
            object instance;
            Hr.Check(device.Activate(ref clientIid, 23, IntPtr.Zero, out instance), "IMMDevice.Activate");
            IAudioClient client = (IAudioClient)instance;
            IntPtr format = Pcm.AllocFormat();
            try
            {
                // AUTOCONVERTPCM | SRC_DEFAULT_QUALITY, 100 ms buffer.
                Hr.Check(client.Initialize(0, 0x80000000u | 0x08000000u, 1000000, 0, format, IntPtr.Zero), "IAudioClient.Initialize");
            }
            finally
            {
                Marshal.FreeCoTaskMem(format);
            }
            uint bufferFrames;
            Hr.Check(client.GetBufferSize(out bufferFrames), "IAudioClient.GetBufferSize");
            Guid renderIid = typeof(IAudioRenderClient).GUID;
            object service;
            Hr.Check(client.GetService(ref renderIid, out service), "IAudioClient.GetService");
            IAudioRenderClient render = (IAudioRenderClient)service;

            double amplitude = 32767 * Math.Pow(10, levelDbfs / 20);
            byte[] buffer = new byte[bufferFrames * Pcm.BlockAlign];
            long frame = 0;
            DateTime end = DateTime.UtcNow.AddSeconds(seconds);
            Hr.Check(client.Start(), "IAudioClient.Start");
            while (DateTime.UtcNow < end)
            {
                uint padding;
                Hr.Check(client.GetCurrentPadding(out padding), "IAudioClient.GetCurrentPadding");
                uint free = bufferFrames - padding;
                if (free > 0)
                {
                    IntPtr data;
                    Hr.Check(render.GetBuffer(free, out data), "IAudioRenderClient.GetBuffer");
                    for (int f = 0; f < free; f++, frame++)
                    {
                        short sample = (short)(amplitude * Math.Sin(2 * Math.PI * 440 * frame / Pcm.SampleRate));
                        buffer[f * 4] = (byte)sample;
                        buffer[f * 4 + 1] = (byte)(sample >> 8);
                        buffer[f * 4 + 2] = (byte)sample;
                        buffer[f * 4 + 3] = (byte)(sample >> 8);
                    }
                    Marshal.Copy(buffer, 0, data, (int)free * Pcm.BlockAlign);
                    Hr.Check(render.ReleaseBuffer(free, 0), "IAudioRenderClient.ReleaseBuffer");
                }
                Thread.Sleep(10);
            }
            client.Stop();
        }

        private static IMMDevice FindPlaybackDevice(string deviceName)
        {
            IMMDeviceEnumerator enumerator = (IMMDeviceEnumerator)new MMDeviceEnumerator();
            IMMDevice device;
            if (string.IsNullOrEmpty(deviceName))
            {
                Hr.Check(enumerator.GetDefaultAudioEndpoint(0, 0, out device), "GetDefaultAudioEndpoint");
                return device;
            }
            PropertyKey friendlyName = new PropertyKey();
            friendlyName.FormatId = new Guid("A45C254E-DF1C-4EFD-8020-67D146A850E0");
            friendlyName.PropertyId = 14;
            IMMDeviceCollection devices;
            Hr.Check(enumerator.EnumAudioEndpoints(0, 1, out devices), "EnumAudioEndpoints");
            int count;
            Hr.Check(devices.GetCount(out count), "IMMDeviceCollection.GetCount");
            List<string> names = new List<string>();
            for (int i = 0; i < count; i++)
            {
                Hr.Check(devices.Item(i, out device), "IMMDeviceCollection.Item");
                IPropertyStore store;
                Hr.Check(device.OpenPropertyStore(0, out store), "IMMDevice.OpenPropertyStore");
                PropVariant value;
                Hr.Check(store.GetValue(ref friendlyName, out value), "IPropertyStore.GetValue");
                string name = value.VarType == 31 ? Marshal.PtrToStringUni(value.Pointer) : null;
                NativeMethods.PropVariantClear(ref value);
                if (name == deviceName) { return device; }
                names.Add(name);
            }
            throw new ArgumentException("Playback device not found: " + deviceName + ". Active devices: " + string.Join(", ", names.ToArray()));
        }
    }
}
'@

if (-not ('ProcessLoopbackProbe.LoopbackCapture' -as [type])) {
    Add-Type -TypeDefinition $source
}

if ($PlayTone) {
    [ProcessLoopbackProbe.Tone]::Play($ToneDevice, -30, 300)
    return
}

function Format-Level {
    param([double]$Value)
    if ([double]::IsNegativeInfinity($Value)) { return 'Stille' }
    return [Math]::Round($Value, 1)
}

$build = [int](Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
if ($build -lt 20348) {
    throw "Prozess-Loopback braucht Windows 10 Build 20348 oder neuer, dieser PC hat Build $build."
}

$toneProcess = $null
if ($SelfTest) {
    $shell = (Get-Process -Id $PID).Path
    $toneArguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -PlayTone' -f $PSCommandPath
    if ($ToneDevice) { $toneArguments += ' -ToneDevice "{0}"' -f $ToneDevice }
    $toneProcess = Start-Process -FilePath $shell -ArgumentList $toneArguments -WindowStyle Hidden -PassThru
    $targetId = $toneProcess.Id
    $targetLabel = "Testton (Prozess $targetId, Gerät: $(if ($ToneDevice) { $ToneDevice } else { 'Standardgerät' }))"
    Start-Sleep -Seconds 3
    if ($toneProcess.HasExited) { throw "Der Testton-Prozess hat sich gleich beendet. Stimmt der Gerätename '$ToneDevice'?" }
}
elseif ($PSCmdlet.ParameterSetName -eq 'ById') {
    $targetId = $ProcessId
    $targetLabel = "Prozess $targetId ($((Get-Process -Id $ProcessId).ProcessName))"
}
else {
    $candidates = @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
    if ($candidates.Count -eq 0) { throw "Kein Prozess '$ProcessName' gefunden. Lichii mit einem Spiel starten, das durchgehend Ton macht." }
    if ($candidates.Count -gt 1) { throw "Mehrere Prozesse '$ProcessName': $($candidates.Id -join ', '). Einen mit -ProcessId wählen." }
    $targetId = $candidates[0].Id
    $targetLabel = "$ProcessName (Prozess $targetId)"
}

$snapshot = $null
$capture = $null
$results = @()
try {
    $snapshot = [ProcessLoopbackProbe.SessionSnapshot]::Take([uint32]$targetId)
    if ($snapshot.Count -eq 0) {
        throw "Prozess $targetId hat keine Tonsitzung. Läuft das Spiel und macht es gerade Ton?"
    }
    $before = $snapshot.Describe()

    $capture = New-Object ProcessLoopbackProbe.LoopbackCapture ([uint32]$targetId), ([bool]$Polling), ([bool]$WavPath)
    $capture.Start()

    $phases = @(
        @{ Name = 'normal'; Mute = $false; Level = -1 },
        @{ Name = 'stumm'; Mute = $true; Level = -1 },
        @{ Name = 'leise (10 %)'; Mute = $false; Level = 0.1 },
        @{ Name = 'normal (zurück)'; Mute = $false; Level = -1 }
    )
    foreach ($phase in $phases) {
        $snapshot.Apply($phase.Mute, $phase.Level)
        # Let the change settle; this half second is not counted.
        Start-Sleep -Milliseconds 500
        $stats = New-Object ProcessLoopbackProbe.PhaseStats
        $stats.Name = $phase.Name
        $capture.BeginPhase($stats)
        Start-Sleep -Seconds $PhaseSeconds
        $capture.EndPhase()
        $results += $stats
        if ($capture.Error) { throw "Die Aufnahme brach ab: $($capture.Error.Message)" }
    }
}
finally {
    $after = 'unbekannt'
    if ($snapshot) {
        $snapshot.Restore()
        try { $after = [ProcessLoopbackProbe.SessionSnapshot]::Take([uint32]$targetId).Describe() } catch { $after = "nicht lesbar: $($_.Exception.Message)" }
    }
    if ($capture) { $capture.Stop() }
    if ($toneProcess -and -not $toneProcess.HasExited) { Stop-Process -Id $toneProcess.Id -Force }
}

if ($WavPath) {
    $capture.SaveWav($WavPath)
}

$windows = Get-CimInstance -ClassName Win32_OperatingSystem
Write-Output ''
Write-Output "Ziel:      $targetLabel"
Write-Output "Windows:   $($windows.Caption) Build $($windows.BuildNumber)"
Write-Output "Lesen:     $(if ($Polling) { 'Abfragen alle 10 ms (wie Toffee)' } else { 'Ereignis-Handle (wie das Microsoft-Beispiel)' })"
Write-Output "Sitzungen: $($snapshot.Count). Vorher: $before. Nachher: $after"
if ($WavPath) { Write-Output "WAV:       $WavPath" }

$results | ForEach-Object {
    [pscustomobject]@{
        Phase           = $_.Name
        Pakete          = $_.Packets
        'Stille Pakete' = $_.SilentPackets
        'Spitze dBFS'   = Format-Level $_.PeakDbfs
        'RMS dBFS'      = Format-Level $_.RmsDbfs
    }
} | Format-Table -AutoSize | Out-String

$normal, $muted, $quiet = $results[0], $results[1], $results[2]
if ($normal.Packets -eq 0) {
    Write-Output 'Ergebnis: Der Prozess-Loopback lieferte keine Pakete. Die Messung taugt nicht.'
}
elseif ($normal.RmsDbfs -lt -70) {
    Write-Output 'Ergebnis: In Phase normal kam fast kein Ton an. Mit einer Stelle im Spiel wiederholen, die durchgehend Ton macht.'
}
else {
    # Below -80 dBFS counts as silence: muted streams still carry rounding noise of about 1 LSB (-90 dBFS peak).
    if ($muted.RmsDbfs -lt -80) {
        Write-Output 'Ergebnis: Stummschalten wirkt auch auf den Prozess-Loopback. Die Brücke bekäme Stille. Lichii braucht weiter ein eigenes stilles Gerät.'
    }
    elseif ([Math]::Abs($normal.RmsDbfs - $muted.RmsDbfs) -lt 6) {
        Write-Output 'Ergebnis: Stummschalten wirkt NICHT auf den Prozess-Loopback. Die Brücke bekäme den Spielton trotzdem.'
    }
    else {
        Write-Output ('Ergebnis: unklar. Stumm liegt {0} dB unter normal. Messung wiederholen.' -f [Math]::Round($normal.RmsDbfs - $muted.RmsDbfs, 1))
    }
    if ($quiet.RmsDbfs -gt -90) {
        Write-Output ('Lautstärke 10 %: Pegel {0} dB unter normal. Erwartet sind etwa 20 dB, wenn der Mixer auf den Loopback wirkt, und etwa 0 dB, wenn nicht.' -f [Math]::Round($normal.RmsDbfs - $quiet.RmsDbfs, 1))
    }
}
