// DSU server and client (Cemuhook protocol, version 1001) for Start-DsuTestServer.ps1 in this folder.
// Written from the protocol description at https://github.com/v1993/cemuhook-protocol. Lichii's DSU
// client was only read to check what it expects, no code is taken from it.
// Loaded with Add-Type -Path, so it must compile with the C# 5 compiler of Windows PowerShell 5.1.
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Threading;

namespace DsuProbe
{
    // The 16 digital buttons as one little-endian 16-bit mask: the low byte is the first button
    // byte of a pad data message (offset 16 after the header), the high byte the second (offset 17).
    [Flags]
    public enum DsuButtons : ushort
    {
        None = 0,
        Share = 0x0001,
        L3 = 0x0002,
        R3 = 0x0004,
        Options = 0x0008,
        Up = 0x0010,
        Right = 0x0020,
        Down = 0x0040,
        Left = 0x0080,
        L2 = 0x0100,
        R2 = 0x0200,
        L1 = 0x0400,
        R1 = 0x0800,
        Triangle = 0x1000,
        Circle = 0x2000,
        Cross = 0x4000,
        Square = 0x8000
    }

    public enum MessageType : uint
    {
        Version = 0x100000,
        PortInfo = 0x100001,
        PadData = 0x100002
    }

    // Everything one pad reports in a pad data message. Sticks use 0-255 with 128 as centre, +X right
    // and +Y up. Accelerometer in g, gyroscope in deg/s. Touch coordinates have no fixed range.
    public sealed class PadState
    {
        public DsuButtons Buttons;
        public bool Home;
        public bool TouchButton;
        public byte LeftX = 128;
        public byte LeftY = 128;
        public byte RightX = 128;
        public byte RightY = 128;
        public float AccelX;
        public float AccelY;
        public float AccelZ;
        public float GyroPitch;
        public float GyroYaw;
        public float GyroRoll;
        public bool Touch1Active;
        public byte Touch1Id;
        public ushort Touch1X;
        public ushort Touch1Y;
        public bool Touch2Active;
        public byte Touch2Id;
        public ushort Touch2X;
        public ushort Touch2Y;

        public PadState Clone()
        {
            return (PadState)MemberwiseClone();
        }

        public bool SameAs(PadState other)
        {
            return other != null
                && Buttons == other.Buttons && Home == other.Home && TouchButton == other.TouchButton
                && LeftX == other.LeftX && LeftY == other.LeftY && RightX == other.RightX && RightY == other.RightY
                && AccelX == other.AccelX && AccelY == other.AccelY && AccelZ == other.AccelZ
                && GyroPitch == other.GyroPitch && GyroYaw == other.GyroYaw && GyroRoll == other.GyroRoll
                && Touch1Active == other.Touch1Active && Touch1Id == other.Touch1Id
                && Touch1X == other.Touch1X && Touch1Y == other.Touch1Y
                && Touch2Active == other.Touch2Active && Touch2Id == other.Touch2Id
                && Touch2X == other.Touch2X && Touch2Y == other.Touch2Y;
        }
    }

    // The 11 bytes every port info and pad data response starts with.
    public sealed class SlotInfo
    {
        public byte Slot;
        public byte State;      // 0 not connected, 1 reserved, 2 connected
        public byte Model;      // 0 n/a, 1 no or partial gyro, 2 full gyro
        public byte Connection; // 0 n/a, 1 USB, 2 Bluetooth
        public byte[] Mac = new byte[6];
        public byte Battery;    // 0x05 full, 0xEE charging, 0xEF charged, ...

        public static SlotInfo NotConnected(byte slot)
        {
            SlotInfo info = new SlotInfo();
            info.Slot = slot;
            return info;
        }
    }

    public static class Crc32
    {
        // Reflected IEEE 802.3 polynomial, as in zlib and boost::crc_32_type.
        private static readonly uint[] Table = BuildTable();

        private static uint[] BuildTable()
        {
            uint[] table = new uint[256];
            for (uint i = 0; i < 256; i++)
            {
                uint c = i;
                for (int k = 0; k < 8; k++)
                {
                    c = (c & 1) != 0 ? 0xEDB88320u ^ (c >> 1) : c >> 1;
                }
                table[i] = c;
            }
            return table;
        }

        public static uint Compute(byte[] data, int offset, int count)
        {
            uint crc = 0xFFFFFFFFu;
            for (int i = offset; i < offset + count; i++)
            {
                crc = Table[(crc ^ data[i]) & 0xFF] ^ (crc >> 8);
            }
            return crc ^ 0xFFFFFFFFu;
        }
    }

    // A parsed message. Error is null for a valid message, otherwise one of:
    // "short", "magic", "version", "length", "crc", "type".
    public sealed class Message
    {
        public string Error;
        public uint SenderId;
        public uint RawType;
        public int Length;

        // Requests
        public byte[] RequestedSlots;
        public byte RegisterFlags;
        public byte RegisterSlot;
        public byte[] RegisterMac;

        // Responses
        public ushort ServerVersion;
        public SlotInfo Slot;
        public bool Connected;
        public uint PacketNumber;
        public ulong Timestamp;
        public PadState Pad;

        public bool IsValid { get { return Error == null; } }
        public MessageType Type { get { return (MessageType)RawType; } }
    }

    public static class Protocol
    {
        public const ushort Version = 1001;
        public const int HeaderLength = 16;          // magic, version, length, CRC32, sender ID
        public const int TypeLength = 4;             // counts as payload, not as header
        public const uint ServerMagic = 0x53555344u; // "DSUS" read as little-endian uint
        public const uint ClientMagic = 0x43555344u; // "DSUC"
        public const int VersionDataLength = 2;
        public const int PortInfoDataLength = 12;
        public const int PadDataDataLength = 80;
        public const int MaxSlots = 4;
        public const byte RegisterBySlot = 1;
        public const byte RegisterByMac = 2;

        public static byte[] CreateMessage(uint magic, uint senderId, MessageType type, int dataLength)
        {
            byte[] packet = new byte[HeaderLength + TypeLength + dataLength];
            WriteUInt32(packet, 0, magic);
            WriteUInt16(packet, 4, Version);
            WriteUInt16(packet, 6, (ushort)(TypeLength + dataLength));
            WriteUInt32(packet, 12, senderId);
            WriteUInt32(packet, 16, (uint)type);
            return packet;
        }

        // Writes the CRC32 of the whole packet, computed while the CRC field is zero.
        public static byte[] Seal(byte[] packet)
        {
            WriteUInt32(packet, 8, 0);
            WriteUInt32(packet, 8, Crc32.Compute(packet, 0, packet.Length));
            return packet;
        }

        public static byte[] BuildVersionResponse(uint serverId)
        {
            byte[] p = CreateMessage(ServerMagic, serverId, MessageType.Version, VersionDataLength);
            WriteUInt16(p, 20, Version);
            return Seal(p);
        }

        public static byte[] BuildPortInfoResponse(uint serverId, SlotInfo slot)
        {
            byte[] p = CreateMessage(ServerMagic, serverId, MessageType.PortInfo, PortInfoDataLength);
            WriteSlotInfo(p, 20, slot);
            // Offset 11 of the data stays zero, as the protocol description says.
            return Seal(p);
        }

        public static byte[] BuildPadDataResponse(uint serverId, SlotInfo slot, uint packetNumber, ulong timestamp, PadState s)
        {
            byte[] p = CreateMessage(ServerMagic, serverId, MessageType.PadData, PadDataDataLength);
            WriteSlotInfo(p, 20, slot);
            p[31] = (byte)(slot.State == 2 ? 1 : 0);
            WriteUInt32(p, 32, packetNumber);
            ushort b = (ushort)s.Buttons;
            p[36] = (byte)(b & 0xFF);
            p[37] = (byte)(b >> 8);
            p[38] = (byte)(s.Home ? 1 : 0);
            p[39] = (byte)(s.TouchButton ? 1 : 0);
            p[40] = s.LeftX;
            p[41] = s.LeftY;
            p[42] = s.RightX;
            p[43] = s.RightY;
            // Analog buttons: digital only, so 0 or 255.
            p[44] = Analog(s, DsuButtons.Left);
            p[45] = Analog(s, DsuButtons.Down);
            p[46] = Analog(s, DsuButtons.Right);
            p[47] = Analog(s, DsuButtons.Up);
            p[48] = Analog(s, DsuButtons.Square);
            p[49] = Analog(s, DsuButtons.Cross);
            p[50] = Analog(s, DsuButtons.Circle);
            p[51] = Analog(s, DsuButtons.Triangle);
            p[52] = Analog(s, DsuButtons.R1);
            p[53] = Analog(s, DsuButtons.L1);
            p[54] = Analog(s, DsuButtons.R2);
            p[55] = Analog(s, DsuButtons.L2);
            WriteTouch(p, 56, s.Touch1Active, s.Touch1Id, s.Touch1X, s.Touch1Y);
            WriteTouch(p, 62, s.Touch2Active, s.Touch2Id, s.Touch2X, s.Touch2Y);
            WriteUInt64(p, 68, timestamp);
            WriteSingle(p, 76, s.AccelX);
            WriteSingle(p, 80, s.AccelY);
            WriteSingle(p, 84, s.AccelZ);
            WriteSingle(p, 88, s.GyroPitch);
            WriteSingle(p, 92, s.GyroYaw);
            WriteSingle(p, 96, s.GyroRoll);
            return Seal(p);
        }

        public static byte[] BuildVersionRequest(uint clientId)
        {
            return Seal(CreateMessage(ClientMagic, clientId, MessageType.Version, 0));
        }

        public static byte[] BuildPortInfoRequest(uint clientId, byte[] slots)
        {
            byte[] p = CreateMessage(ClientMagic, clientId, MessageType.PortInfo, 4 + slots.Length);
            WriteUInt32(p, 20, (uint)slots.Length);
            Array.Copy(slots, 0, p, 24, slots.Length);
            return Seal(p);
        }

        public static byte[] BuildPadDataRequest(uint clientId, byte flags, byte slot, byte[] mac)
        {
            byte[] p = CreateMessage(ClientMagic, clientId, MessageType.PadData, 8);
            p[20] = flags;
            p[21] = slot;
            if (mac != null)
            {
                Array.Copy(mac, 0, p, 22, Math.Min(6, mac.Length));
            }
            return Seal(p);
        }

        public static Message ParseRequest(byte[] data, int length)
        {
            return Parse(data, length, ClientMagic);
        }

        public static Message ParseResponse(byte[] data, int length)
        {
            return Parse(data, length, ServerMagic);
        }

        private static Message Parse(byte[] data, int length, uint magic)
        {
            Message m = new Message();
            if (length < HeaderLength + TypeLength)
            {
                m.Error = "short";
                return m;
            }
            if (ReadUInt32(data, 0) != magic)
            {
                m.Error = "magic";
                return m;
            }
            if (ReadUInt16(data, 4) != Version)
            {
                m.Error = "version";
                return m;
            }
            int payload = ReadUInt16(data, 6);
            int total = HeaderLength + payload;
            // Too short: drop. Too long: only the announced length counts.
            if (payload < TypeLength || total > length)
            {
                m.Error = "short";
                return m;
            }
            m.Length = total;
            byte[] copy = new byte[total];
            Array.Copy(data, copy, total);
            uint crc = ReadUInt32(copy, 8);
            WriteUInt32(copy, 8, 0);
            if (Crc32.Compute(copy, 0, total) != crc)
            {
                m.Error = "crc";
                return m;
            }
            m.SenderId = ReadUInt32(copy, 12);
            m.RawType = ReadUInt32(copy, 16);
            int dataLength = payload - TypeLength;

            if (magic == ClientMagic)
            {
                switch (m.Type)
                {
                    case MessageType.Version:
                        break;
                    case MessageType.PortInfo:
                        int count = dataLength >= 4 ? (int)ReadUInt32(copy, 20) : -1;
                        if (count < 0 || count > MaxSlots || dataLength < 4 + count)
                        {
                            m.Error = "length";
                            break;
                        }
                        m.RequestedSlots = new byte[count];
                        Array.Copy(copy, 24, m.RequestedSlots, 0, count);
                        break;
                    case MessageType.PadData:
                        if (dataLength < 8)
                        {
                            m.Error = "length";
                            break;
                        }
                        m.RegisterFlags = copy[20];
                        m.RegisterSlot = copy[21];
                        m.RegisterMac = new byte[6];
                        Array.Copy(copy, 22, m.RegisterMac, 0, 6);
                        break;
                    default:
                        m.Error = "type";
                        break;
                }
                return m;
            }

            // Responses: exact lengths, as Lichii checks them.
            switch (m.Type)
            {
                case MessageType.Version:
                    if (dataLength != VersionDataLength) { m.Error = "length"; break; }
                    m.ServerVersion = ReadUInt16(copy, 20);
                    break;
                case MessageType.PortInfo:
                    if (dataLength != PortInfoDataLength) { m.Error = "length"; break; }
                    m.Slot = ReadSlotInfo(copy, 20);
                    break;
                case MessageType.PadData:
                    if (dataLength != PadDataDataLength) { m.Error = "length"; break; }
                    m.Slot = ReadSlotInfo(copy, 20);
                    m.Connected = copy[31] != 0;
                    m.PacketNumber = ReadUInt32(copy, 32);
                    m.Timestamp = ReadUInt64(copy, 68);
                    m.Pad = ReadPadState(copy);
                    break;
                default:
                    m.Error = "type";
                    break;
            }
            return m;
        }

        private static PadState ReadPadState(byte[] p)
        {
            PadState s = new PadState();
            s.Buttons = (DsuButtons)(ushort)(p[36] | (p[37] << 8));
            s.Home = p[38] != 0;
            s.TouchButton = p[39] != 0;
            s.LeftX = p[40];
            s.LeftY = p[41];
            s.RightX = p[42];
            s.RightY = p[43];
            s.Touch1Active = p[56] != 0;
            s.Touch1Id = p[57];
            s.Touch1X = ReadUInt16(p, 58);
            s.Touch1Y = ReadUInt16(p, 60);
            s.Touch2Active = p[62] != 0;
            s.Touch2Id = p[63];
            s.Touch2X = ReadUInt16(p, 64);
            s.Touch2Y = ReadUInt16(p, 66);
            s.AccelX = ReadSingle(p, 76);
            s.AccelY = ReadSingle(p, 80);
            s.AccelZ = ReadSingle(p, 84);
            s.GyroPitch = ReadSingle(p, 88);
            s.GyroYaw = ReadSingle(p, 92);
            s.GyroRoll = ReadSingle(p, 96);
            return s;
        }

        private static byte Analog(PadState s, DsuButtons button)
        {
            return (byte)((s.Buttons & button) != 0 ? 255 : 0);
        }

        private static void WriteSlotInfo(byte[] p, int offset, SlotInfo slot)
        {
            p[offset] = slot.Slot;
            p[offset + 1] = slot.State;
            p[offset + 2] = slot.Model;
            p[offset + 3] = slot.Connection;
            Array.Copy(slot.Mac, 0, p, offset + 4, 6);
            p[offset + 10] = slot.Battery;
        }

        private static SlotInfo ReadSlotInfo(byte[] p, int offset)
        {
            SlotInfo slot = new SlotInfo();
            slot.Slot = p[offset];
            slot.State = p[offset + 1];
            slot.Model = p[offset + 2];
            slot.Connection = p[offset + 3];
            Array.Copy(p, offset + 4, slot.Mac, 0, 6);
            slot.Battery = p[offset + 10];
            return slot;
        }

        private static void WriteTouch(byte[] p, int offset, bool active, byte id, ushort x, ushort y)
        {
            p[offset] = (byte)(active ? 1 : 0);
            p[offset + 1] = id;
            WriteUInt16(p, offset + 2, x);
            WriteUInt16(p, offset + 4, y);
        }

        public static void WriteUInt16(byte[] p, int offset, ushort value)
        {
            p[offset] = (byte)value;
            p[offset + 1] = (byte)(value >> 8);
        }

        public static void WriteUInt32(byte[] p, int offset, uint value)
        {
            for (int i = 0; i < 4; i++) { p[offset + i] = (byte)(value >> (8 * i)); }
        }

        public static void WriteUInt64(byte[] p, int offset, ulong value)
        {
            for (int i = 0; i < 8; i++) { p[offset + i] = (byte)(value >> (8 * i)); }
        }

        public static void WriteSingle(byte[] p, int offset, float value)
        {
            byte[] bytes = BitConverter.GetBytes(value);
            if (!BitConverter.IsLittleEndian) { Array.Reverse(bytes); }
            Array.Copy(bytes, 0, p, offset, 4);
        }

        public static ushort ReadUInt16(byte[] p, int offset)
        {
            return (ushort)(p[offset] | (p[offset + 1] << 8));
        }

        public static uint ReadUInt32(byte[] p, int offset)
        {
            uint value = 0;
            for (int i = 0; i < 4; i++) { value |= (uint)p[offset + i] << (8 * i); }
            return value;
        }

        public static ulong ReadUInt64(byte[] p, int offset)
        {
            ulong value = 0;
            for (int i = 0; i < 8; i++) { value |= (ulong)p[offset + i] << (8 * i); }
            return value;
        }

        public static float ReadSingle(byte[] p, int offset)
        {
            byte[] bytes = new byte[4];
            Array.Copy(p, offset, bytes, 0, 4);
            if (!BitConverter.IsLittleEndian) { Array.Reverse(bytes); }
            return BitConverter.ToSingle(bytes, 0);
        }
    }

    public enum ServerEventKind
    {
        ClientAdded,
        ClientExpired,
        VersionRequest,
        PortInfoRequest,
        PadDataRequest,
        Invalid,
        SocketError
    }

    public sealed class ServerEvent
    {
        public TimeSpan Time;
        public ServerEventKind Kind;
        public string Client;
        // Invalid: "<parse error> <type in hex> <bytes>". PortInfoRequest: "0,1,2,3". PadDataRequest: "all", "slot 1", "mac ...".
        public string Detail;
        // PadDataRequest: whether the request names the connected pad and starts or keeps the stream.
        public bool Accepted;
    }

    public sealed class ClientStats
    {
        public string Client;
        public long VersionRequests;
        public long PortInfoRequests;
        public long PadDataRequests;
        public long PadPacketsSent;
        public bool Streaming;
    }

    internal sealed class ClientEntry
    {
        public IPEndPoint EndPoint;
        public long LastPadRequestMs = -1;
        public bool Streaming;
        public uint PacketNumber;
        public ClientStats Stats = new ClientStats();
    }

    internal static class TimerResolution
    {
        [DllImport("winmm.dll")] public static extern uint timeBeginPeriod(uint milliseconds);
        [DllImport("winmm.dll")] public static extern uint timeEndPeriod(uint milliseconds);
    }

    // Serves one connected pad in slot 0. Slots 1 to 3 report as not connected.
    public sealed class Server : IDisposable
    {
        // Windows reports an ICMP "port unreachable" from an earlier send as an error on the next
        // receive. This switches that off, so a client that went away does not stop the server.
        private const int SioUdpConnReset = -1744830452;

        private readonly object gate = new object();
        private readonly object sendGate = new object();
        private readonly Dictionary<string, ClientEntry> clients = new Dictionary<string, ClientEntry>();
        private readonly ConcurrentQueue<ServerEvent> events = new ConcurrentQueue<ServerEvent>();
        private readonly Stopwatch clock = new Stopwatch();
        private readonly IPEndPoint bind;
        private readonly int rate;
        private PadState state = new PadState();
        private UdpClient socket;
        private Thread receiver;
        private Thread sender;
        private volatile bool running;
        private long invalid;
        private bool timerRaised;

        public Server(string address, int port, int rateHz)
        {
            bind = new IPEndPoint(IPAddress.Parse(address), port);
            rate = Math.Max(1, Math.Min(1000, rateHz));
            ClientTimeoutMs = 5000;
            ServerId = (uint)new Random().Next() ^ (uint)Environment.TickCount;
            Pad = new SlotInfo();
            Pad.Slot = 0;
            Pad.State = 2;
            Pad.Model = 2;
            Pad.Connection = 2;
            Pad.Mac = new byte[] { 0x02, 0x44, 0x53, 0x55, 0x00, 0x00 }; // locally administered
            Pad.Battery = 0x05;
        }

        public uint ServerId { get; private set; }
        public SlotInfo Pad { get; private set; }
        public int ClientTimeoutMs { get; set; }
        public int Rate { get { return rate; } }
        public int Port { get; private set; }
        public long InvalidPackets { get { return Interlocked.Read(ref invalid); } }
        public TimeSpan Elapsed { get { return clock.Elapsed; } }

        public void SetState(PadState newState)
        {
            PadState copy = newState.Clone();
            lock (gate) { state = copy; }
        }

        public PadState GetState()
        {
            lock (gate) { return state.Clone(); }
        }

        public void Start()
        {
            socket = new UdpClient(bind);
            try
            {
                socket.Client.IOControl(SioUdpConnReset, new byte[] { 0, 0, 0, 0 }, null);
            }
            catch (Exception)
            {
                // Not available on this platform. The receive loop also skips these errors.
            }
            Port = ((IPEndPoint)socket.Client.LocalEndPoint).Port;
            timerRaised = TimerResolution.timeBeginPeriod(1) == 0;
            clock.Start();
            running = true;
            receiver = new Thread(ReceiveLoop);
            receiver.IsBackground = true;
            receiver.Name = "DSU receive";
            receiver.Start();
            sender = new Thread(SendLoop);
            sender.IsBackground = true;
            sender.Name = "DSU send";
            sender.Start();
        }

        public void Stop()
        {
            if (!running) { return; }
            running = false;
            socket.Close();
            receiver.Join(1000);
            sender.Join(1000);
            if (timerRaised) { TimerResolution.timeEndPeriod(1); timerRaised = false; }
        }

        public void Dispose()
        {
            Stop();
        }

        public ServerEvent[] DrainEvents()
        {
            List<ServerEvent> list = new List<ServerEvent>();
            ServerEvent e;
            while (events.TryDequeue(out e)) { list.Add(e); }
            return list.ToArray();
        }

        public ClientStats[] GetClientStats()
        {
            lock (gate)
            {
                List<ClientStats> list = new List<ClientStats>();
                foreach (ClientEntry c in clients.Values)
                {
                    ClientStats s = c.Stats;
                    ClientStats copy = new ClientStats();
                    copy.Client = s.Client;
                    copy.VersionRequests = s.VersionRequests;
                    copy.PortInfoRequests = s.PortInfoRequests;
                    copy.PadDataRequests = s.PadDataRequests;
                    copy.PadPacketsSent = s.PadPacketsSent;
                    copy.Streaming = c.Streaming;
                    list.Add(copy);
                }
                return list.ToArray();
            }
        }

        private void Post(ServerEventKind kind, string client, string detail, bool accepted)
        {
            ServerEvent e = new ServerEvent();
            e.Time = clock.Elapsed;
            e.Kind = kind;
            e.Client = client;
            e.Detail = detail;
            e.Accepted = accepted;
            events.Enqueue(e);
        }

        private void ReceiveLoop()
        {
            while (running)
            {
                IPEndPoint remote = new IPEndPoint(IPAddress.Any, 0);
                byte[] data;
                try
                {
                    data = socket.Receive(ref remote);
                }
                catch (SocketException ex)
                {
                    if (!running) { return; }
                    if (ex.SocketErrorCode == SocketError.ConnectionReset) { continue; }
                    Post(ServerEventKind.SocketError, null, ex.SocketErrorCode.ToString(), false);
                    continue;
                }
                catch (ObjectDisposedException)
                {
                    return;
                }
                Handle(data, remote);
            }
        }

        private void Handle(byte[] data, IPEndPoint remote)
        {
            string name = remote.ToString();
            Message m = Protocol.ParseRequest(data, data.Length);
            if (!m.IsValid)
            {
                Interlocked.Increment(ref invalid);
                Post(ServerEventKind.Invalid, name, m.Error + " " + m.RawType.ToString("x") + " " + data.Length, false);
                return;
            }

            ClientEntry client;
            lock (gate)
            {
                if (!clients.TryGetValue(name, out client))
                {
                    client = new ClientEntry();
                    client.EndPoint = remote;
                    client.Stats.Client = name;
                    clients.Add(name, client);
                    Post(ServerEventKind.ClientAdded, name, null, false);
                }
            }

            switch (m.Type)
            {
                case MessageType.Version:
                    lock (gate) { client.Stats.VersionRequests++; }
                    Post(ServerEventKind.VersionRequest, name, null, true);
                    Send(Protocol.BuildVersionResponse(ServerId), remote);
                    break;

                case MessageType.PortInfo:
                    lock (gate) { client.Stats.PortInfoRequests++; }
                    Post(ServerEventKind.PortInfoRequest, name, string.Join(",", Array.ConvertAll(m.RequestedSlots, b => b.ToString())), true);
                    foreach (byte slot in m.RequestedSlots)
                    {
                        if (slot >= Protocol.MaxSlots) { continue; }
                        SlotInfo info = slot == Pad.Slot ? Pad : SlotInfo.NotConnected(slot);
                        Send(Protocol.BuildPortInfoResponse(ServerId, info), remote);
                    }
                    break;

                case MessageType.PadData:
                    string detail;
                    bool accepted;
                    if ((m.RegisterFlags & Protocol.RegisterBySlot) != 0)
                    {
                        detail = "slot " + m.RegisterSlot;
                        accepted = m.RegisterSlot == Pad.Slot;
                    }
                    else if ((m.RegisterFlags & Protocol.RegisterByMac) != 0)
                    {
                        detail = "mac " + BitConverter.ToString(m.RegisterMac);
                        accepted = BitConverter.ToString(m.RegisterMac) == BitConverter.ToString(Pad.Mac);
                    }
                    else
                    {
                        detail = "all";
                        accepted = true;
                    }
                    lock (gate)
                    {
                        client.Stats.PadDataRequests++;
                        if (accepted)
                        {
                            client.LastPadRequestMs = clock.ElapsedMilliseconds;
                            client.Streaming = true;
                        }
                    }
                    Post(ServerEventKind.PadDataRequest, name, detail, accepted);
                    break;
            }
        }

        private void SendLoop()
        {
            double period = 1000.0 / rate;
            long tick = 0;
            while (running)
            {
                tick++;
                double wait = tick * period - clock.Elapsed.TotalMilliseconds;
                if (wait > 0)
                {
                    Thread.Sleep((int)Math.Ceiling(wait));
                }
                else if (wait < -250)
                {
                    // Fell far behind, e.g. after a suspend: start counting from now.
                    tick = (long)(clock.Elapsed.TotalMilliseconds / period);
                }
                if (!running) { return; }
                SendPadData();
            }
        }

        private void SendPadData()
        {
            long now = clock.ElapsedMilliseconds;
            ulong timestamp = (ulong)(clock.Elapsed.Ticks / (TimeSpan.TicksPerMillisecond / 1000));
            PadState current;
            List<KeyValuePair<IPEndPoint, uint>> targets = new List<KeyValuePair<IPEndPoint, uint>>();
            lock (gate)
            {
                current = state;
                foreach (ClientEntry c in clients.Values)
                {
                    if (!c.Streaming) { continue; }
                    if (now - c.LastPadRequestMs > ClientTimeoutMs)
                    {
                        c.Streaming = false;
                        Post(ServerEventKind.ClientExpired, c.Stats.Client, null, false);
                        continue;
                    }
                    c.PacketNumber++;
                    c.Stats.PadPacketsSent++;
                    targets.Add(new KeyValuePair<IPEndPoint, uint>(c.EndPoint, c.PacketNumber));
                }
            }
            foreach (KeyValuePair<IPEndPoint, uint> t in targets)
            {
                Send(Protocol.BuildPadDataResponse(ServerId, Pad, t.Value, timestamp, current), t.Key);
            }
        }

        private void Send(byte[] packet, IPEndPoint target)
        {
            try
            {
                lock (sendGate) { socket.Send(packet, packet.Length, target); }
            }
            catch (SocketException ex)
            {
                if (running) { Post(ServerEventKind.SocketError, target.ToString(), ex.SocketErrorCode.ToString(), false); }
            }
            catch (ObjectDisposedException)
            {
            }
        }
    }

    public sealed class ProbeSample
    {
        public TimeSpan Received;
        public Message Message;
    }

    // A DSU client that asks like Lichii does (pad info for slots 0 to 3 and pad data for all pads,
    // repeated), plus one version request. Used by the self-test.
    public sealed class ProbeClient : IDisposable
    {
        private readonly IPEndPoint server;
        private readonly object gate = new object();
        private readonly List<ProbeSample> samples = new List<ProbeSample>();
        private readonly List<string> invalid = new List<string>();
        private readonly Stopwatch clock = new Stopwatch();
        private UdpClient socket;
        private Thread receiver;
        private Thread requester;
        private volatile bool running;

        public ProbeClient(string address, int port)
        {
            server = new IPEndPoint(IPAddress.Parse(address), port);
            ClientId = (uint)new Random().Next();
            RequestIntervalMs = 1000;
            KeepRequesting = true;
        }

        public uint ClientId { get; private set; }
        public int RequestIntervalMs { get; set; }
        public bool KeepRequesting { get; set; }
        public TimeSpan Elapsed { get { return clock.Elapsed; } }

        public void Start()
        {
            socket = new UdpClient(new IPEndPoint(IPAddress.Loopback, 0));
            clock.Start();
            running = true;
            receiver = new Thread(ReceiveLoop);
            receiver.IsBackground = true;
            receiver.Start();
            Send(Protocol.BuildVersionRequest(ClientId));
            requester = new Thread(RequestLoop);
            requester.IsBackground = true;
            requester.Start();
        }

        public void Stop()
        {
            if (!running) { return; }
            running = false;
            socket.Close();
            receiver.Join(1000);
            requester.Join(1000);
        }

        public void Dispose()
        {
            Stop();
        }

        public void Send(byte[] packet)
        {
            socket.Send(packet, packet.Length, server);
        }

        public ProbeSample[] GetSamples()
        {
            lock (gate) { return samples.ToArray(); }
        }

        public string[] GetInvalid()
        {
            lock (gate) { return invalid.ToArray(); }
        }

        private void RequestLoop()
        {
            byte[] allSlots = new byte[] { 0, 1, 2, 3 };
            while (running)
            {
                if (KeepRequesting)
                {
                    try
                    {
                        Send(Protocol.BuildPortInfoRequest(ClientId, allSlots));
                        Send(Protocol.BuildPadDataRequest(ClientId, 0, 0, null));
                    }
                    catch (ObjectDisposedException)
                    {
                        return;
                    }
                    catch (SocketException)
                    {
                    }
                }
                Thread.Sleep(RequestIntervalMs);
            }
        }

        private void ReceiveLoop()
        {
            while (running)
            {
                IPEndPoint remote = new IPEndPoint(IPAddress.Any, 0);
                byte[] data;
                try
                {
                    data = socket.Receive(ref remote);
                }
                catch (SocketException)
                {
                    if (!running) { return; }
                    continue;
                }
                catch (ObjectDisposedException)
                {
                    return;
                }
                Message m = Protocol.ParseResponse(data, data.Length);
                lock (gate)
                {
                    if (!m.IsValid || m.Length != data.Length)
                    {
                        invalid.Add((m.Error ?? "extra bytes") + ", " + data.Length + " bytes");
                        continue;
                    }
                    ProbeSample sample = new ProbeSample();
                    sample.Received = clock.Elapsed;
                    sample.Message = m;
                    samples.Add(sample);
                }
            }
        }
    }
}
