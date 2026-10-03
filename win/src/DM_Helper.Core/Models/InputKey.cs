namespace DM_Helper.Core.Models;

using DM_Helper.Core.Interop;

/// <summary>What the user bound. Values match the macOS <c>D3InputType</c> for JSON parity.</summary>
public enum InputType
{
    None = 0,
    Keyboard = 1,
    MouseButton = 2,
    MouseWheel = 3,
}

/// <summary>
/// A single bindable input: a key, a mouse button, or a wheel direction.
///
/// Mirrors <c>D3InputKey</c> from the macOS build, including the
/// <c>{ type, keyCode, mouseButton, wheelDirection, display }</c> JSON shape, but stores a
/// Windows virtual-key code instead of a <c>CGKeyCode</c>.
/// </summary>
public sealed record InputKey
{
    public InputType Type { get; init; } = InputType.None;
    public Vk Key { get; init; } = Vk.None;
    public MouseButton MouseButton { get; init; } = MouseButton.None;
    public WheelDirection WheelDirection { get; init; } = WheelDirection.None;

    public static InputKey Empty { get; } = new();

    public static InputKey FromKey(Vk vk) => new()
    {
        Type = InputType.Keyboard,
        Key = vk,
        MouseButton = MouseButton.None,
        WheelDirection = WheelDirection.None,
    };

    public static InputKey FromMouse(MouseButton button) => new()
    {
        Type = InputType.MouseButton,
        Key = Vk.None,
        MouseButton = button,
        WheelDirection = WheelDirection.None,
    };

    public static InputKey FromWheel(WheelDirection direction) => new()
    {
        Type = InputType.MouseWheel,
        Key = Vk.None,
        MouseButton = MouseButton.None,
        WheelDirection = direction,
    };

    /// <summary>
    /// Parse a stored/display string. Accepts both the Windows labels and the macOS labels
    /// so a profile exported from the Mac build can be imported directly.
    /// </summary>
    public static InputKey Parse(string? text)
    {
        if (string.IsNullOrWhiteSpace(text) || text == "Unknown") return Empty;

        var t = text.Trim();

        switch (t)
        {
            case "Mouse Middle" or "마우스 휠 클릭": return FromMouse(MouseButton.Middle);
            case "Mouse Left" or "마우스 좌클릭": return FromMouse(MouseButton.Left);
            case "Mouse Right" or "마우스 우클릭": return FromMouse(MouseButton.Right);
            case "XButton1" or "Mouse Button 4": return FromMouse(MouseButton.XButton1);
            case "XButton2" or "Mouse Button 5": return FromMouse(MouseButton.XButton2);
            case "Wheel Up" or "휠 올리기": return FromWheel(WheelDirection.Up);
            case "Wheel Down" or "휠 내리기": return FromWheel(WheelDirection.Down);
        }

        // macOS-only labels that have no Windows counterpart.
        if (t is "Command" or "LeftCommand" or "RightCommand" or "Function")
            return Empty;

        var vk = VkExtensions.FromDisplayString(t);
        return vk == Vk.None ? Empty : FromKey(vk);
    }

    public bool IsEmpty => Type switch
    {
        InputType.None => true,
        InputType.Keyboard => Key == Vk.None,
        InputType.MouseButton => MouseButton == MouseButton.None,
        InputType.MouseWheel => WheelDirection == WheelDirection.None,
        _ => true,
    };

    public string DisplayString => Type switch
    {
        InputType.MouseButton => MouseButton switch
        {
            MouseButton.Left => "Mouse Left",
            MouseButton.Right => "Mouse Right",
            MouseButton.Middle => "Mouse Middle",
            MouseButton.XButton1 => "XButton1",
            MouseButton.XButton2 => "XButton2",
            _ => string.Empty,
        },
        InputType.MouseWheel => WheelDirection switch
        {
            WheelDirection.Up => "Wheel Up",
            WheelDirection.Down => "Wheel Down",
            _ => string.Empty,
        },
        InputType.Keyboard => Key.ToDisplayString(),
        _ => string.Empty,
    };

    // ---- JSON shape compatible with the macOS build ----

    public Dictionary<string, object?> ToDictionary() => new()
    {
        ["type"] = (int)Type,
        ["keyCode"] = (int)Key,
        ["mouseButton"] = (int)MouseButton,
        ["wheelDirection"] = (int)WheelDirection,
        ["display"] = DisplayString,
    };

    public static InputKey FromDictionary(IReadOnlyDictionary<string, System.Text.Json.JsonElement> d)
    {
        if (d.Count == 0) return Empty;

        int Get(string key) => d.TryGetValue(key, out var e) && e.ValueKind is System.Text.Json.JsonValueKind.Number
            ? e.GetInt32()
            : 0;

        var type = (InputType)Get("type");

        // Prefer the stored display string: it survives key-space migrations, and the
        // numeric key code may be a macOS code that means something else on Windows.
        if (d.TryGetValue("display", out var disp) && disp.ValueKind == System.Text.Json.JsonValueKind.String)
        {
            var parsed = Parse(disp.GetString());
            if (!parsed.IsEmpty) return parsed;
        }

        return type switch
        {
            InputType.Keyboard => FromKey((Vk)Get("keyCode")),
            InputType.MouseButton => FromMouse((MouseButton)Get("mouseButton")),
            InputType.MouseWheel => FromWheel((WheelDirection)Get("wheelDirection")),
            _ => Empty,
        };
    }

    /// <summary>
    /// Only the field matching <see cref="Type"/> is significant. A keyboard binding must
    /// compare equal regardless of what stale mouse or wheel values it happens to carry,
    /// which the compiler-generated record equality would not give us.
    /// </summary>
    public bool Equals(InputKey? other)
    {
        if (other is null) return false;
        if (ReferenceEquals(this, other)) return true;
        if (Type != other.Type) return false;

        return Type switch
        {
            InputType.Keyboard => Key == other.Key,
            InputType.MouseButton => MouseButton == other.MouseButton,
            InputType.MouseWheel => WheelDirection == other.WheelDirection,
            _ => true,
        };
    }

    public override int GetHashCode() => Type switch
    {
        InputType.Keyboard => HashCode.Combine((int)Type, Key),
        InputType.MouseButton => HashCode.Combine((int)Type, MouseButton),
        InputType.MouseWheel => HashCode.Combine((int)Type, WheelDirection),
        _ => 0,
    };

    public override string ToString() => $"<InputKey: {DisplayString}>";
}
