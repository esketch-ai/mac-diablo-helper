using DM_Helper.Core.Interop;
using DM_Helper.Core.Models;

namespace DM_Helper.Core.Tests;

/// <summary>
/// 1:1 port of <c>testD3InputKeyParsing</c> from the macOS test suite, rebased onto
/// Windows virtual-key codes.
/// </summary>
public class InputKeyTests
{
    [Fact]
    public void ParsesMouseMiddle()
    {
        var key = InputKey.Parse("Mouse Middle");
        Assert.Equal(InputType.MouseButton, key.Type);
        Assert.Equal(MouseButton.Middle, key.MouseButton);
        Assert.Equal("Mouse Middle", key.DisplayString);
    }

    [Fact]
    public void ParsesKoreanMouseLabels()
    {
        Assert.Equal(MouseButton.Left, InputKey.Parse("마우스 좌클릭").MouseButton);
        Assert.Equal(MouseButton.Right, InputKey.Parse("마우스 우클릭").MouseButton);
        Assert.Equal(MouseButton.Middle, InputKey.Parse("마우스 휠 클릭").MouseButton);
    }

    [Fact]
    public void ParsesSideButtons()
    {
        var x1 = InputKey.Parse("XButton1");
        Assert.Equal(InputType.MouseButton, x1.Type);
        Assert.Equal(MouseButton.XButton1, x1.MouseButton);

        var x2 = InputKey.Parse("Mouse Button 5");
        Assert.Equal(MouseButton.XButton2, x2.MouseButton);
    }

    [Fact]
    public void ParsesWheel()
    {
        var up = InputKey.Parse("Wheel Up");
        Assert.Equal(InputType.MouseWheel, up.Type);
        Assert.Equal(WheelDirection.Up, up.WheelDirection);
        Assert.Equal("Wheel Up", up.DisplayString);

        var down = InputKey.Parse("휠 내리기");
        Assert.Equal(WheelDirection.Down, down.WheelDirection);
    }

    [Fact]
    public void ParsesSpace()
    {
        var space = InputKey.Parse("Space");
        Assert.Equal(InputType.Keyboard, space.Type);
        Assert.Equal(Vk.Space, space.Key);
        Assert.Equal("Space", space.DisplayString);
    }

    [Fact]
    public void ParsesDigitOne()
    {
        var one = InputKey.Parse("1");
        Assert.Equal(InputType.Keyboard, one.Type);
        Assert.Equal(Vk.D1, one.Key);
        Assert.Equal("1", one.DisplayString);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("Unknown")]
    public void EmptyInputsParseToEmptyKey(string? text)
    {
        Assert.True(InputKey.Parse(text).IsEmpty);
    }

    /// <summary>macOS-only labels must not silently bind to a wrong Windows key.</summary>
    [Theory]
    [InlineData("Command")]
    [InlineData("Function")]
    public void MacOnlyLabelsParseToEmptyKey(string text)
    {
        Assert.True(InputKey.Parse(text).IsEmpty);
    }

    [Fact]
    public void RoundTripsEveryNamedKey()
    {
        foreach (var vk in Enum.GetValues<Vk>())
        {
            var label = vk.ToDisplayString();
            if (string.IsNullOrEmpty(label)) continue;

            // Generic aliases (Shift/Control/Alt) are never produced by FromDisplayString
            // and are deliberately excluded.
            if (label is "Shift" or "Control" or "Option") continue;

            Assert.Equal(vk, VkExtensions.FromDisplayString(label));
        }
    }

    [Fact]
    public void EqualityIgnoresUnrelatedFields()
    {
        var a = InputKey.FromKey(Vk.A);
        var b = new InputKey
        {
            Type = InputType.Keyboard,
            Key = Vk.A,
            MouseButton = MouseButton.Left,   // ignored for keyboard inputs
            WheelDirection = WheelDirection.Up,
        };

        Assert.Equal(a, b);
    }

    [Fact]
    public void KeyboardAndMouseKeysAreNotEqual()
    {
        Assert.NotEqual(InputKey.FromKey(Vk.A), InputKey.FromMouse(MouseButton.Left));
        Assert.NotEqual(InputKey.FromMouse(MouseButton.Left), InputKey.FromWheel(WheelDirection.Up));
    }

    [Fact]
    public void DictionaryRoundTripPreservesKey()
    {
        var original = InputKey.FromKey(Vk.F1);
        var json = System.Text.Json.JsonSerializer.Serialize(original.ToDictionary());
        var doc = System.Text.Json.JsonDocument.Parse(json);

        var restored = InputKey.FromDictionary(
            OpenerStep.ParseObjectForTests(doc.RootElement));

        Assert.Equal(original, restored);
    }
}
