namespace DM_Helper.Core.Interop;

/// <summary>
/// Windows virtual-key codes (winuser.h VK_*).
///
/// The macOS build stored <c>kVK_*</c> codes (a compact 0x00-0x7E layout). Windows uses
/// <c>VK_*</c> codes, so every persisted profile needs a translation table rather than a
/// raw reinterpretation of the same number.
/// </summary>
public enum Vk : ushort
{
    None = 0x00,

    // ---- Editing / whitespace ----
    Backspace = 0x08,
    Tab = 0x09,
    Clear = 0x0C,
    Enter = 0x0D,
    Pause = 0x13,
    CapsLock = 0x14,
    Escape = 0x1B,
    Space = 0x20,
    Prior = 0x21,   // Page Up
    Next = 0x22,    // Page Down
    End = 0x23,
    Home = 0x24,

    // ---- Arrows (all four are "extended" keys on the Windows keyboard) ----
    Left = 0x25,
    Up = 0x26,
    Right = 0x27,
    Down = 0x28,
    Snapshot = 0x2C, // Print Screen
    Insert = 0x2D,
    Delete = 0x2E,

    // ---- Digits ----
    D0 = 0x30, D1 = 0x31, D2 = 0x32, D3 = 0x33, D4 = 0x34,
    D5 = 0x35, D6 = 0x36, D7 = 0x37, D8 = 0x38, D9 = 0x39,

    // ---- Letters ----
    A = 0x41, B = 0x42, C = 0x43, D = 0x44, E = 0x45, F = 0x46, G = 0x47, H = 0x48,
    I = 0x49, J = 0x4A, K = 0x4B, L = 0x4C, M = 0x4D, N = 0x4E, O = 0x4F, P = 0x50,
    Q = 0x51, R = 0x52, S = 0x53, T = 0x54, U = 0x55, V = 0x56, W = 0x57, X = 0x58,
    Y = 0x59, Z = 0x5A,

    LeftWin = 0x5B,
    RightWin = 0x5C,
    Apps = 0x5D, // context menu key

    // ---- Numeric keypad ----
    NumPad0 = 0x60, NumPad1 = 0x61, NumPad2 = 0x62, NumPad3 = 0x63, NumPad4 = 0x64,
    NumPad5 = 0x65, NumPad6 = 0x66, NumPad7 = 0x67, NumPad8 = 0x68, NumPad9 = 0x69,
    NumPadMultiply = 0x6A,
    NumPadAdd = 0x6B,
    NumPadSeparator = 0x6C,
    NumPadSubtract = 0x6D,
    NumPadDecimal = 0x6E,
    NumPadDivide = 0x6F,

    // ---- Function keys ----
    F1 = 0x70, F2 = 0x71, F3 = 0x72, F4 = 0x73, F5 = 0x74, F6 = 0x75,
    F7 = 0x76, F8 = 0x77, F9 = 0x78, F10 = 0x79, F11 = 0x7A, F12 = 0x7B,
    F13 = 0x7C, F14 = 0x7D, F15 = 0x7E, F16 = 0x7F, F17 = 0x80, F18 = 0x81,
    F19 = 0x82, F20 = 0x83, F21 = 0x84, F22 = 0x85, F23 = 0x86, F24 = 0x87,

    NumLock = 0x90,
    Scroll = 0x91,

    // ---- Modifiers ----
    Shift = 0x10,
    Control = 0x11,
    Menu,      // 0x12 - Alt / Option
    LShift = 0xA0,
    RShift = 0xA1,
    LControl = 0xA2,
    RControl = 0xA3,
    LMenu = 0xA4,
    RMenu = 0xA5,

    // ---- OEM punctuation (US layout positions) ----
    Semicolon = 0xBA,       // ;:
    OemPlus = 0xBB,         // =+
    OemComma = 0xBC,        // ,<
    OemMinus = 0xBD,        // -_
    OemPeriod = 0xBE,       // .>
    Oem2 = 0xBF,            // /?
    Oem3 = 0xC0,            // `~
    Oem4 = 0xDB,            // [{
    Oem5 = 0xDC,            // \|
    Oem6 = 0xDD,            // ]}
    Oem7 = 0xDE,            // '"
    Oem8 = 0xDF,            // !  (102nd key on ISO layouts)
    Oem102 = 0xE2,          // \ on 102-key ISO layouts

    // ---- IME ----
    /// <summary>
    /// 한/영 (Hangul) toggle. Windows reports this as <c>VK_PROCESSKEY</c> through the
    /// low-level hook rather than as a discrete scancode.
    /// </summary>
    Hangul = 0xE5,
}

public static class VkExtensions
{
    /// <summary>
    /// Keys that live on the "extended" part of the keyboard. These must carry
    /// <c>KEYEVENTF_EXTENDEDKEY</c> or the OS maps them onto the numpad instead.
    /// </summary>
    public static bool IsExtendedKey(this Vk vk) => vk switch
    {
        Vk.Insert or Vk.Delete or Vk.Home or Vk.End or Vk.Prior or Vk.Next
            or Vk.Left or Vk.Up or Vk.Right or Vk.Down
            or Vk.NumLock or (Vk)0x2C /* Snapshot */
            or Vk.NumPadDivide or Vk.Enter or Vk.RControl or Vk.RMenu
            or Vk.LeftWin or Vk.RightWin or Vk.Apps => true,
        _ => false,
    };

    /// <summary>
    /// True for keys that sit on the numeric keypad. Games bind these separately from the
    /// main block (D4 lets you map both <c>1</c> and <c>Num 1</c> independently).
    /// </summary>
    public static bool IsKeypadKey(this Vk vk) =>
        vk >= Vk.NumPad0 && vk <= Vk.NumPadDivide;

    /// <summary>Human-readable label used in the UI and in <c>displayString</c>.</summary>
    public static string ToDisplayString(this Vk vk) => vk switch
    {
        Vk.None => "",
        Vk.Backspace => "Delete",
        Vk.Tab => "Tab",
        Vk.Clear => "Clear",
        Vk.Enter => "Enter",
        Vk.Pause => "Pause",
        Vk.CapsLock => "CapsLock",
        Vk.Escape => "Escape",
        Vk.Space => "Space",
        Vk.Prior => "PageUp",
        Vk.Next => "PageDown",
        Vk.End => "End",
        Vk.Home => "Home",
        Vk.Left => "LeftArrow",
        Vk.Up => "UpArrow",
        Vk.Right => "RightArrow",
        Vk.Down => "DownArrow",
        Vk.Insert => "Insert",
        Vk.Delete => "ForwardDelete",
        (Vk)0x2C => "Snapshot",
        Vk.Shift or Vk.LShift => "Shift",
        Vk.RShift => "RightShift",
        Vk.Control or Vk.LControl => "Control",
        Vk.RControl => "RightControl",
        Vk.Menu or Vk.LMenu => "Option",
        Vk.RMenu => "RightOption",
        Vk.LeftWin => "LeftCommand",
        Vk.RightWin => "RightCommand",
        Vk.Apps => "Apps",
        Vk.Hangul => "한/영",
        Vk.Semicolon => ";",
        Vk.OemPlus => "=",
        Vk.OemComma => ",",
        Vk.OemMinus => "-",
        Vk.OemPeriod => ".",
        Vk.Oem2 => "/",
        Vk.Oem3 => "`",
        Vk.Oem4 => "[",
        Vk.Oem5 => "\\",
        Vk.Oem6 => "]",
        Vk.Oem7 => "'",
        Vk.Oem8 => "!",
        Vk.Oem102 => "Oem102",
        Vk.NumPadDecimal => "KeypadDecimal",
        Vk.NumPadMultiply => "KeypadMultiply",
        Vk.NumPadAdd => "KeypadPlus",
        Vk.NumPadSubtract => "KeypadMinus",
        Vk.NumPadDivide => "KeypadDivide",
        _ => HandleDigitsAndLetters(vk),
    };

    private static string HandleDigitsAndLetters(Vk vk)
    {
        var v = (int)vk;
        if (vk >= Vk.D0 && vk <= Vk.D9) return ((char)('0' + (v - (int)Vk.D0))).ToString();
        if (vk >= Vk.A && vk <= Vk.Z) return ((char)('A' + (v - (int)Vk.A))).ToString();
        if (vk >= Vk.NumPad0 && vk <= Vk.NumPad9) return $"Keypad{((char)('0' + (v - (int)Vk.NumPad0)))}";
        if (vk >= Vk.F1 && vk <= Vk.F24) return $"F{1 + (v - (int)Vk.F1)}";
        return vk.ToString();
    }

    /// <summary>
    /// Reverse of <see cref="ToDisplayString"/>. Returns <see cref="Vk.None"/> when the label
    /// is not a bindable key (this is what <c>D3InputKey.keyWithString:</c> did with 0xFE).
    /// </summary>
    public static Vk FromDisplayString(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return Vk.None;
        var t = text.Trim();

        foreach (Vk candidate in Enum.GetValues<Vk>())
        {
            if (candidate == Vk.Menu || candidate == Vk.Control || candidate == Vk.Shift) continue;
            if (candidate.ToDisplayString() == t) return candidate;
        }

        if (t.Length == 1)
        {
            var c = char.ToUpperInvariant(t[0]);
            if (c is >= 'A' and <= 'Z') return (Vk)(ushort)c;
            if (c is >= '0' and <= '9') return (Vk)(ushort)(0x30 + (c - '0'));
        }

        return Vk.None;
    }

    /// <summary>
    /// Keys the sanitizer treats as "too dangerous to bind" - the Windows analogue of the
    /// macOS build rejecting Command (55/54) and Fn (63) as the start/stop key.
    /// Windows equivalents are the Win keys and the Pause key (which cannot be suppressed
    /// safely) plus Print Screen (captures the screen mid-macro).
    /// </summary>
    public static bool IsForbiddenAsShortcut(this Vk vk) => vk is
        Vk.LeftWin or Vk.RightWin or Vk.Pause or (Vk)0x2C /* Snapshot */ or Vk.CapsLock;
}
