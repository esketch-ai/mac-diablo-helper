using System.Runtime.InteropServices;

namespace DM_Helper.Core.Interop;

/// <summary>Mouse buttons, numbered to match the macOS <c>CGMouseButton</c> values.</summary>
public enum MouseButton
{
    None = -1,
    Left = 0,
    Right = 1,
    Middle = 2,
    XButton1 = 3,
    XButton2 = 4,
}

/// <summary>
/// What kind of payload an <c>INPUT</c> record carries (winuser.h <c>INPUT_*</c>).
/// Distinct from <c>DM_Helper.Core.Models.InputType</c>, which describes what the user bound.
/// </summary>
public enum NativeInputType
{
    Mouse = 0,
    Keyboard = 1,
    Hardware = 2,
}

public enum WheelDirection
{
    None = 0,
    Up = 1,
    Down = -1,
}

/// <summary>Win32 constant tables used when assembling <c>INPUT</c> records.</summary>
public static class NativeConsts
{
    // ---- INPUT_KEYBDINPUT flags -------------------------------------------------
    public const uint KEYEVENTF_EXTENDEDKEY = 0x0001;
    public const uint KEYEVENTF_KEYUP = 0x0002;
    public const uint KEYEVENTF_SCANCODE = 0x0008;

    // ---- INPUT_MOUSEINPUT flags -------------------------------------------------
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;
    public const uint MOUSEEVENTF_RIGHTDOWN = 0x0008;
    public const uint MOUSEEVENTF_RIGHTUP = 0x0010;
    public const uint MOUSEEVENTF_MIDDLEDOWN = 0x0020;
    public const uint MOUSEEVENTF_MIDDLEUP = 0x0040;
    public const uint MOUSEEVENTF_XDOWN = 0x0080;
    public const uint MOUSEEVENTF_XUP = 0x0100;
    public const uint MOUSEEVENTF_WHEEL = 0x0800;
    public const uint MOUSEEVENTF_HWHEEL = 0x1000;

    public const uint XBUTTON1 = 0x0001;
    public const uint XBUTTON2 = 0x0002;
    public const int WHEEL_DELTA = 120;

    // ---- Low-level hook ----------------------------------------------------------
    public const int WH_KEYBOARD_LL = 13;
    public const int WH_MOUSE_LL = 14;
    public const int HC_ACTION = 0;

    /// <summary>Set by the OS on events produced by <c>SendInput</c> rather than a device.</summary>
    public const uint LLKHF_INJECTED = 0x00000010;
    public const uint LLMHF_INJECTED = 0x00000001;

    /// <summary>Extended (E0-prefixed) scan codes come back from this map mode.</summary>
    public const uint MAPVK_VK_TO_VSC_EX = 4;

    public const int PROCESS_PER_MONITOR_DPI_AWARE = 2;

    public const uint MONITOR_DEFAULTTONEAREST = 2;
    public const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
}

/// <summary>
/// <c>INPUT</c>: a type tag followed by one of three union payloads.
/// </summary>
[StructLayout(LayoutKind.Sequential)]
internal struct INPUT
{
    public uint type;
    public InputUnion union;
}

/// <summary>
/// Union modelled as a single 32-byte blob: the largest member is <c>MOUSEINPUT</c>
/// at 32 bytes. A fixed blob removes all the manual <c>SizeOf</c> padding maths from the
/// hot path and guarantees <c>SendInput</c> is handed a correctly sized buffer.
/// </summary>
[StructLayout(LayoutKind.Explicit, Size = 32)]
public struct InputUnion
{
    [FieldOffset(0)] public MOUSEINPUT mi;
    [FieldOffset(0)] public KEYBDINPUT ki;
    [FieldOffset(0)] public HARDWAREINPUT hi;
}

/// <summary>Size of the <c>INPUT</c> payload union, exposed for diagnostics.</summary>
public static class InputLayout
{
    public static int UnionSize => Marshal.SizeOf<InputUnion>();
}

[StructLayout(LayoutKind.Sequential)]
public struct MOUSEINPUT
{
    public int dx;
    public int dy;
    public uint mouseData;
    public uint dwFlags;
    public uint time;
    public IntPtr dwExtraInfo;
}

[StructLayout(LayoutKind.Sequential)]
public struct KEYBDINPUT
{
    public ushort wVk;
    public ushort wScan;
    public uint dwFlags;
    public uint time;
    public IntPtr dwExtraInfo;
}

[StructLayout(LayoutKind.Sequential)]
public struct HARDWAREINPUT
{
    public uint uMsg;
    public ushort wParamL;
    public ushort wParamH;
}

[StructLayout(LayoutKind.Sequential)]
internal struct POINT
{
    public int X;
    public int Y;
}

[StructLayout(LayoutKind.Sequential)]
internal struct KBDLLHOOKSTRUCT
{
    public uint vkCode;
    public uint scanCode;
    public uint flags;
    public uint time;
    public IntPtr dwExtraInfo;
}

[StructLayout(LayoutKind.Sequential)]
internal struct MSLLHOOKSTRUCT
{
    public POINT pt;
    public uint mouseData;
    public uint flags;
    public uint time;
    public IntPtr dwExtraInfo;
}

[StructLayout(LayoutKind.Sequential)]
internal struct RECT
{
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
internal struct MONITORINFO
{
    public int cbSize;
    public RECT rcMonitor;
    public RECT rcWork;
    public uint dwFlags;
}

public static class NativeMethods
{
    public const string USER32 = "user32.dll";
    public const string KERNEL32 = "kernel32.dll";

    /// <summary><c>sizeof(INPUT)</c> - 40 bytes on x64 (4 pad + 4 type + 32 union).</summary>
    public static readonly int InputSize = Marshal.SizeOf<INPUT>();

    [DllImport(USER32, SetLastError = true)]
    internal static extern uint SendInput(uint nInputs, [In] INPUT[] pInputs, int cbSize);

    [DllImport(USER32)]
    internal static extern short VkKeyScanW(char ch);

    [DllImport(USER32)]
    internal static extern uint MapVirtualKeyW(uint uCode, uint uMapType);

    [DllImport(USER32)]
    internal static extern uint GetKeyState(int nVirtKey);

    [DllImport(USER32, SetLastError = true)]
    internal static extern bool GetCursorPos(out POINT lpPoint);

    // ---------------------------------------------------------------- hooks
    [DllImport(USER32, SetLastError = true, CharSet = CharSet.Unicode)]
    internal static extern IntPtr SetWindowsHookExW(int idHook, LowLevelHookProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport(USER32, SetLastError = true)]
    internal static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport(USER32)]
    internal static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport(USER32)]
    internal static extern IntPtr GetMessageW(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

    [DllImport(USER32)]
    internal static extern bool TranslateMessage(ref MSG lpMsg);

    [DllImport(USER32)]
    internal static extern IntPtr DispatchMessageW(ref MSG lpMsg);

    [DllImport(USER32)]
    internal static extern bool PostThreadMessageW(uint idThread, uint msg, IntPtr wParam, IntPtr lParam);

    // ---------------------------------------------------------------- windows
    [DllImport(USER32)]
    internal static extern IntPtr GetForegroundWindow();

    [DllImport(USER32)]
    internal static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport(USER32)]
    internal static extern IntPtr GetDesktopWindow();

    [DllImport(USER32)]
    internal static extern IntPtr GetShellWindow();

    // ---------------------------------------------------------------- monitors
    [DllImport(USER32)]
    internal static extern IntPtr MonitorFromPoint(POINT pt, uint dwFlags);

    [DllImport(USER32)]
    internal static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint dwFlags);

    [DllImport(USER32, CharSet = CharSet.Unicode)]
    internal static extern bool GetMonitorInfoW(IntPtr hMonitor, ref MONITORINFO lpmi);

    [DllImport(USER32)]
    internal static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumProc lpfn, IntPtr dwData);

    // ---------------------------------------------------------------- process / dpi
    [DllImport(KERNEL32, SetLastError = true)]
    internal static extern IntPtr GetModuleHandleW(string? lpModuleName);

    [DllImport(KERNEL32)]
    internal static extern uint GetCurrentThreadId();

    [DllImport(KERNEL32)]
    internal static extern uint GetCurrentProcessId();

    [DllImport("shcore.dll")]
    internal static extern int SetProcessDpiAwareness(int value);

    [DllImport(USER32)]
    internal static extern bool SetProcessDPIAware();

    // ---------------------------------------------------------------- system
    [DllImport(USER32)]
    internal static extern uint GetSystemMetrics(int nIndex);

    [DllImport(USER32, SetLastError = true)]
    internal static extern IntPtr FindWindowW(string? lpClassName, string? lpWindowName);

    [DllImport(USER32)]
    internal static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport(USER32)]
    internal static extern int GetWindowTextLengthW(IntPtr hWnd);

    [DllImport(USER32, CharSet = CharSet.Unicode)]
    internal static extern int GetWindowTextW(IntPtr hWnd, [Out] char[] lpString, int nMaxCount);

    [DllImport(USER32)]
    internal static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport(USER32)]
    internal static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport(KERNEL32)]
    internal static extern bool QueryFullProcessImageNameW(IntPtr hProcess, uint dwFlags,
        [Out] char[] lpExeName, ref uint lpdwSize);

    [DllImport(KERNEL32)]
    internal static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, uint dwProcessId);

    [DllImport(KERNEL32)]
    internal static extern bool CloseHandle(IntPtr hObject);

    [DllImport(USER32)]
    internal static extern bool IsWow64Process(IntPtr hProcess, [MarshalAs(UnmanagedType.Bool)] out bool wow64Process);

    [DllImport(KERNEL32)]
    internal static extern IntPtr GetCurrentProcess();
}

[StructLayout(LayoutKind.Sequential)]
internal struct MSG
{
    public IntPtr hwnd;
    public uint message;
    public IntPtr wParam;
    public IntPtr lParam;
    public uint time;
    public POINT pt;
}

internal delegate IntPtr LowLevelHookProc(int nCode, IntPtr wParam, IntPtr lParam);

internal delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdc, IntPtr lprcMonitor, IntPtr dwData);

internal delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
