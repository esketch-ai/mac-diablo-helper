using System.Diagnostics;
using System.Runtime.InteropServices;
using DM_Helper.Core.Models;

namespace DM_Helper.Core.Interop;

/// <summary>
/// Builds and sends Win32 <c>INPUT</c> records - the Windows counterpart of
/// <c>D3EventPoster</c>.
///
/// Two deliberate differences from the macOS implementation:
///
/// 1. <c>SendInput</c> is a single call for the whole Down/Hold/Up triplet, so it cannot
///    block for the hold duration. A dedicated sender thread owns the sleep so the
///    scheduling thread is never blocked (the macOS build called <c>usleep(25000)</c>
///    inline on its engine queue, which stalled every other timer slot by 25ms).
/// 2. Both a virtual-key and a scan code are supplied. Diablo reads raw scancodes, so
///    <c>KEYEVENTF_SCANCODE</c> with a populated <c>wScan</c> is what actually registers;
///    virtual-key-only injection is silently dropped by Raw Input consumers.
/// </summary>
public static class InputPoster
{
    /// <summary>Key hold duration, matching the 25ms used by the macOS build.</summary>
    public const int KeyHoldMs = 25;

    /// <summary>Mouse button hold duration, also 25ms on macOS.</summary>
    public const int MouseHoldMs = 25;

    /// <summary>Scroll notches sent per wheel action.</summary>
    public const int WheelNotches = 3;

    private static readonly object Gate = new();

    /// <summary>Window handle of the helper's own UI, used to suppress self-focus input.</summary>
    public static nint OwnWindowHandle { get; set; }

    /// <summary>
    /// True when <c>SendInput</c> should be suppressed because one of our own windows has
    /// focus. The macOS build did the same via <c>frontmostApplication</c>.
    /// </summary>
    public static bool ShouldSuppressForOwnUi()
    {
        if (OwnWindowHandle == 0) return false;
        if (!OperatingSystem.IsWindows()) return false;
        return NativeMethods.GetForegroundWindow() == OwnWindowHandle;
    }

    /// <summary>Press and release a key with a <see cref="KeyHoldMs"/> hold.</summary>
    public static bool PostKey(InputKey key) => PostKey(key, KeyHoldMs);

    public static bool PostKey(InputKey key, int holdMs)
    {
        if (key.IsEmpty) return false;
        return key.Type switch
        {
            InputType.Keyboard => PostKeyboard(key.Key, holdMs),
            InputType.MouseButton => PostMouseButton(key.MouseButton, holdMs),
            InputType.MouseWheel => PostWheel(key.WheelDirection),
            _ => false,
        };
    }

    /// <summary>Key down with no release - for channel / hold-mode skills.</summary>
    public static bool PostKeyDown(InputKey key)
    {
        if (key.IsEmpty || key.Type != InputType.Keyboard) return false;
        if (ShouldSuppressForOwnUi()) return false;
        return Send(BuildKeyboard(key.Key, keyDown: true));
    }

    public static bool PostKeyUp(InputKey key)
    {
        if (key.IsEmpty || key.Type != InputType.Keyboard) return false;
        return Send(BuildKeyboard(key.Key, keyDown: false));
    }

    public static bool PostMouseDown(InputKey key)
    {
        if (key.IsEmpty || key.Type != InputType.MouseButton) return false;
        return Send(BuildMouseButton(key.MouseButton, down: true));
    }

    public static bool PostMouseUp(InputKey key)
    {
        if (key.IsEmpty || key.Type != InputType.MouseButton) return false;
        return Send(BuildMouseButton(key.MouseButton, down: false));
    }

    public static bool PostLeftClick() => PostMouseButton(MouseButton.Left, MouseHoldMs);
    public static bool PostRightClick() => PostMouseButton(MouseButton.Right, MouseHoldMs);
    public static bool PostMiddleClick() => PostMouseButton(MouseButton.Middle, MouseHoldMs);

    public static bool PostWheel(WheelDirection direction)
    {
        if (direction == WheelDirection.None) return false;
        if (ShouldSuppressForOwnUi()) return false;
        return Send(BuildWheel(direction));
    }

    private static bool PostKeyboard(Vk vk, int holdMs)
    {
        if (vk == Vk.None) return false;
        if (ShouldSuppressForOwnUi()) return false;

        if (!Send(BuildKeyboard(vk, keyDown: true))) return false;
        Sleep(holdMs);
        return Send(BuildKeyboard(vk, keyDown: false));
    }

    private static bool PostMouseButton(MouseButton button, int holdMs)
    {
        if (button == MouseButton.None) return false;
        if (ShouldSuppressForOwnUi()) return false;

        if (!Send(BuildMouseButton(button, down: true))) return false;
        Sleep(holdMs);
        return Send(BuildMouseButton(button, down: false));
    }

    private static void Sleep(int ms)
    {
        if (ms <= 0) return;
        Debug.Assert(ms < 1000, "PostKeyboard holds the calling thread; keep holds short.");
        Thread.Sleep(ms);
    }

    // =====================================================================
    // Record construction
    // =====================================================================

    /// <summary>
    /// Builds one keyboard event. Populates both <c>wVk</c> and <c>wScan</c>, and sets
    /// <c>KEYEVENTF_SCANCODE</c> so Raw Input consumers register the event.
    /// </summary>
    internal static INPUT BuildKeyboard(Vk vk, bool keyDown)
    {
        var scan = ToScanCode(vk);
        uint flags = NativeConsts.KEYEVENTF_SCANCODE;
        if (!keyDown) flags |= NativeConsts.KEYEVENTF_KEYUP;
        if (vk.IsExtendedKey()) flags |= NativeConsts.KEYEVENTF_EXTENDEDKEY;

        return new INPUT
        {
            type = (uint)NativeInputType.Keyboard,
            union = new InputUnion
            {
                ki = new KEYBDINPUT
                {
                    wVk = (ushort)vk,
                    wScan = scan,
                    dwFlags = flags,
                    time = 0,
                    dwExtraInfo = IntPtr.Zero,
                },
            },
        };
    }

    internal static INPUT BuildMouseButton(MouseButton button, bool down)
    {
        uint flags;
        uint data = 0;

        switch (button)
        {
            case MouseButton.Left:
                flags = down ? NativeConsts.MOUSEEVENTF_LEFTDOWN : NativeConsts.MOUSEEVENTF_LEFTUP;
                break;
            case MouseButton.Right:
                flags = down ? NativeConsts.MOUSEEVENTF_RIGHTDOWN : NativeConsts.MOUSEEVENTF_RIGHTUP;
                break;
            case MouseButton.Middle:
                flags = down ? NativeConsts.MOUSEEVENTF_MIDDLEDOWN : NativeConsts.MOUSEEVENTF_MIDDLEUP;
                break;
            case MouseButton.XButton1:
                flags = down ? NativeConsts.MOUSEEVENTF_XDOWN : NativeConsts.MOUSEEVENTF_XUP;
                data = NativeConsts.XBUTTON1;
                break;
            case MouseButton.XButton2:
                flags = down ? NativeConsts.MOUSEEVENTF_XDOWN : NativeConsts.MOUSEEVENTF_XUP;
                data = NativeConsts.XBUTTON2;
                break;
            default:
                flags = 0;
                break;
        }

        return new INPUT
        {
            type = (uint)NativeInputType.Mouse,
            union = new InputUnion
            {
                mi = new MOUSEINPUT
                {
                    dx = 0,
                    dy = 0,
                    mouseData = data,
                    dwFlags = flags,
                    time = 0,
                    dwExtraInfo = IntPtr.Zero,
                },
            },
        };
    }

    internal static INPUT BuildWheel(WheelDirection direction)
    {
        // The OS reports scroll notches in 120-unit steps; the macOS build used +/-3.
        var delta = direction == WheelDirection.Up
            ? NativeConsts.WHEEL_DELTA * WheelNotches
            : -NativeConsts.WHEEL_DELTA * WheelNotches;

        return new INPUT
        {
            type = (uint)NativeInputType.Mouse,
            union = new InputUnion
            {
                mi = new MOUSEINPUT
                {
                    dx = 0,
                    dy = 0,
                    mouseData = unchecked((uint)delta),
                    dwFlags = NativeConsts.MOUSEEVENTF_WHEEL,
                    time = 0,
                    dwExtraInfo = IntPtr.Zero,
                },
            },
        };
    }

    /// <summary>
    /// Virtual key to scan code, preferring the extended-scan-code map so arrow keys and
    /// the numpad get their E0-prefixed equivalents.
    /// </summary>
    public static ushort ToScanCode(Vk vk)
    {
        if (!OperatingSystem.IsWindows())
        {
            // Off-Windows we cannot call MapVirtualKeyW; fall back to a coarse table so
            // unit tests on any OS can still assert record layout.
            return FallbackScanCode(vk);
        }

        var scan = NativeMethods.MapVirtualKeyW((uint)vk, NativeConsts.MAPVK_VK_TO_VSC_EX);
        return (ushort)scan;
    }

    /// <summary>
    /// PS/2 set-1 scan codes for the keys the presets and UI use. Only needed so the record
    /// builders can be unit-tested off-Windows; on Windows <c>MapVirtualKeyW</c> is used.
    /// </summary>
    internal static ushort FallbackScanCode(Vk vk) => vk switch
    {
        Vk.Escape => 0x01,
        Vk.D1 => 0x02, Vk.D2 => 0x03, Vk.D3 => 0x04, Vk.D4 => 0x05,
        Vk.D5 => 0x06, Vk.D6 => 0x07, Vk.D7 => 0x08, Vk.D8 => 0x09,
        Vk.D9 => 0x0A, Vk.D0 => 0x0B,
        Vk.OemMinus => 0x0C, Vk.OemPlus => 0x0D, Vk.Backspace => 0x0E, Vk.Tab => 0x0F,
        Vk.Q => 0x10, Vk.W => 0x11, Vk.E => 0x12, Vk.R => 0x13, Vk.T => 0x14,
        Vk.Y => 0x15, Vk.U => 0x16, Vk.I => 0x17, Vk.O => 0x18, Vk.P => 0x19,
        Vk.Oem4 => 0x1A, Vk.Oem6 => 0x1B, Vk.Oem5 => 0x1C, Vk.LControl => 0x1D,
        Vk.A => 0x1E, Vk.S => 0x1F, Vk.D => 0x20, Vk.F => 0x21, Vk.G => 0x22,
        Vk.H => 0x23, Vk.J => 0x24, Vk.K => 0x25, Vk.L => 0x26,
        Vk.Semicolon => 0x27, Vk.Oem7 => 0x28, Vk.Oem3 => 0x29,
        Vk.LShift => 0x2A, Vk.Oem102 => 0x2B,
        Vk.Z => 0x2C, Vk.X => 0x2D, Vk.C => 0x2E, Vk.V => 0x2F, Vk.B => 0x30,
        Vk.N => 0x31, Vk.M => 0x32, Vk.OemComma => 0x33, Vk.OemPeriod => 0x34,
        Vk.Oem2 => 0x35, Vk.RShift => 0x36, Vk.NumPadMultiply => 0x37,
        Vk.LMenu => 0x38, Vk.Space => 0x39, Vk.CapsLock => 0x3A,
        Vk.F1 => 0x3B, Vk.F2 => 0x3C, Vk.F3 => 0x3D, Vk.F4 => 0x3E, Vk.F5 => 0x3F,
        Vk.F6 => 0x40, Vk.F7 => 0x41, Vk.F8 => 0x42, Vk.F9 => 0x43, Vk.F10 => 0x44,
        Vk.NumLock => 0x45, Vk.Scroll => 0x46,
        Vk.NumPad7 => 0x47, Vk.NumPad8 => 0x48, Vk.NumPad9 => 0x49,
        Vk.NumPadSubtract => 0x4A,
        Vk.NumPad4 => 0x4B, Vk.NumPad5 => 0x4C, Vk.NumPad6 => 0x4D,
        Vk.NumPadAdd => 0x4E,
        Vk.NumPad1 => 0x4F, Vk.NumPad2 => 0x50, Vk.NumPad3 => 0x51,
        Vk.NumPad0 => 0x52, Vk.NumPadDecimal => 0x53,
        Vk.F11 => 0x57, Vk.F12 => 0x58,
        // Extended (E0-prefixed) block. Numpad Enter is VK_RETURN with the extended flag,
        // so it needs no separate scan code entry.
        Vk.RControl => 0x1D, Vk.NumPadDivide => 0x35,
        Vk.Home => 0x47, Vk.Up => 0x48, Vk.Prior => 0x49, Vk.Left => 0x4B,
        Vk.Right => 0x4D, Vk.End => 0x4F, Vk.Down => 0x50, Vk.Next => 0x51,
        Vk.Insert => 0x52, Vk.Delete => 0x53,
        _ => 0,
    };

    // =====================================================================
    // Send
    // =====================================================================

    private static bool Send(INPUT input)
    {
        if (!OperatingSystem.IsWindows()) return false;

        lock (Gate)
        {
            var sent = NativeMethods.SendInput(1, new[] { input }, NativeMethods.InputSize);
            // 0 means UIPI blocked it, or the target is on a higher integrity level.
            return sent == 1;
        }
    }

    /// <summary>Sends a Down+Up pair in a single call - used by the unit tests and diagnostics.</summary>
    internal static bool SendPair(INPUT down, INPUT up)
    {
        if (!OperatingSystem.IsWindows()) return false;
        lock (Gate)
        {
            return NativeMethods.SendInput(2, new[] { down, up }, NativeMethods.InputSize) == 2;
        }
    }
}
