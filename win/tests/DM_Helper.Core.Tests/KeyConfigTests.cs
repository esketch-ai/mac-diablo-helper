using System.Text.Json;
using DM_Helper.Core.Interop;
using DM_Helper.Core.Models;

namespace DM_Helper.Core.Tests;

/// <summary>
/// 1:1 port of <c>testD3KeyConfigSerialization</c>, <c>testD3KeyConfigMatching</c> and the
/// preset coverage from the macOS test suite.
/// </summary>
public class KeyConfigTests
{
    private static KeyConfig SampleConfig()
    {
        var c = KeyConfig.DefaultConfig();
        c.Memo = "테스트용 프로필";
        c.SkillKeys[4] = InputKey.FromMouse(MouseButton.Right);
        c.SkillDelays[4] = 66;
        c.SkillChecks[4] = false;
        c.SkillHolds[4] = true;
        c.SingleRepeatToggles[0] = InputKey.FromKey(Vk.Oem3);
        c.SingleRepeatDelays[0] = 111;
        return c;
    }

    [Fact]
    public void DictionarySerializationRoundTrips()
    {
        var config = SampleConfig();
        var json = JsonSerializer.Serialize(config.ToDictionary());
        using var doc = JsonDocument.Parse(json);
        var restored = KeyConfig.FromDictionary(doc.RootElement);

        Assert.Equal("테스트용 프로필", restored.Memo);
        Assert.Equal(config.StartInputKey, restored.StartInputKey);
        Assert.Equal(config.SkillKeys[4], restored.SkillKeys[4]);
        Assert.Equal(66, restored.SkillDelays[4]);
        Assert.False(restored.SkillChecks[4]);
        Assert.True(restored.SkillHolds[4]);
        Assert.Equal(config.SingleRepeatToggles[0], restored.SingleRepeatToggles[0]);
        Assert.Equal(111, restored.SingleRepeatDelays[0]);
    }

    [Fact]
    public void OpenerStepsRoundTrip()
    {
        var config = KeyConfig.ForPreset(KeyConfig.PresetKind.Warlock);
        var json = JsonSerializer.Serialize(config.ToDictionary());
        using var doc = JsonDocument.Parse(json);
        var restored = KeyConfig.FromDictionary(doc.RootElement);

        Assert.True(restored.OpenerEnabled);
        Assert.Equal(4, restored.OpenerSteps.Count(s => !s.IsEmpty));
        Assert.Equal(config.OpenerSteps[0].Description, restored.OpenerSteps[0].Description);
        Assert.Equal(config.OpenerSteps[3].RepeatCount, restored.OpenerSteps[3].RepeatCount);
    }

    [Fact]
    public void ComboSettingsRoundTrip()
    {
        var config = KeyConfig.ForPreset(KeyConfig.PresetKind.Rogue);
        var json = JsonSerializer.Serialize(config.ToDictionary());
        using var doc = JsonDocument.Parse(json);
        var restored = KeyConfig.FromDictionary(doc.RootElement);

        Assert.True(restored.ComboEnabled);
        Assert.Equal(3, restored.ComboGeneratorCount);
        Assert.Equal(1, restored.ComboSpenderCount);
        Assert.Equal(150, restored.ComboInterval);
        Assert.Equal(InputKey.FromMouse(MouseButton.Right), restored.ComboSpenderKey);
    }

    [Fact]
    public void StartKeyMatching()
    {
        var config = KeyConfig.DefaultConfig();
        var start = InputKey.FromKey(Vk.Oem4);

        Assert.True(config.IsStartKey(start));
        Assert.False(config.IsStartKey(InputKey.FromMouse(MouseButton.Left)));
    }

    [Fact]
    public void SingleRepeatKeyNeverCollidesWithStartKey()
    {
        var config = KeyConfig.DefaultConfig();
        var grave = config.SingleRepeatToggles[0];

        Assert.False(config.IsStartKey(grave));
        Assert.NotEqual(grave, config.StartInputKey);
    }

    [Fact]
    public void InGameKeysActAsStopKeys()
    {
        var config = KeyConfig.DefaultConfig();

        Assert.True(config.IsStopKey(config.InventoryKey));
        Assert.True(config.IsStopKey(config.MapKey));
        Assert.True(config.IsStopKey(config.PortalKey));
        Assert.True(config.IsStopKey(config.ChatKey));
    }

    [Fact]
    public void LeftClickIsNeverAStopKey()
    {
        var config = KeyConfig.DefaultConfig();
        Assert.False(config.IsStopKey(InputKey.FromMouse(MouseButton.Left)));
        Assert.False(config.IsStopKey(InputKey.FromMouse(MouseButton.Left)));
    }

    [Fact]
    public void EmptyStopKeyFallsBackToLeftBracket()
    {
        var config = KeyConfig.DefaultConfig();
        config.StopInputKey = InputKey.Empty;
        Assert.True(config.IsStopKey(InputKey.FromKey(Vk.Oem4)));
    }

    /// <summary>
    /// The loot and gamble macros default to mouse-button actions. Sanitize must not treat
    /// a left-click action as illegal - that would silently disable item pickup.
    /// </summary>
    [Fact]
    public void DefaultProfileBindsLootAndGambleKeys()
    {
        var config = KeyConfig.DefaultConfig();

        Assert.Equal(Vk.Oem3, config.SingleRepeatToggles[0].Key);
        Assert.Equal(MouseButton.Left, config.SingleRepeatActions[0].MouseButton);
        Assert.Equal(50, config.SingleRepeatDelays[0]);

        Assert.Equal(Vk.Tab, config.SingleRepeatToggles[1].Key);
        Assert.Equal(MouseButton.Right, config.SingleRepeatActions[1].MouseButton);
        Assert.Equal(60, config.SingleRepeatDelays[1]);
    }

    /// <summary>Left click stays legal as a repeat *action*, but never as a toggle.</summary>
    [Fact]
    public void LeftClickIsLegalAsActionButNotAsToggle()
    {
        var config = KeyConfig.DefaultConfig();

        config.SingleRepeatActions[0] = InputKey.FromMouse(MouseButton.Left);
        config.SingleRepeatToggles[0] = InputKey.FromMouse(MouseButton.Left);
        config.Sanitize();

        Assert.Equal(MouseButton.Left, config.SingleRepeatActions[0].MouseButton);
        Assert.True(config.SingleRepeatToggles[0].IsEmpty);
    }

    /// <summary>
    /// An empty start key must fall back to '[', otherwise the helper has no way to begin
    /// and the user is locked out of the macro entirely.
    /// </summary>
    [Fact]
    public void EmptyStartKeyFallsBackToLeftBracket()
    {
        var config = new KeyConfig { StartInputKey = InputKey.Empty };
        config.Sanitize();

        Assert.Equal(Vk.Oem4, config.StartInputKey.Key);
        Assert.True(config.IsStartKey(InputKey.FromKey(Vk.Oem4)));
    }

    [Fact]
    public void EmptyStopKeyFallsBackToLeftBracketOnSanitize()
    {
        var config = new KeyConfig { StopInputKey = InputKey.Empty };
        config.Sanitize();
        Assert.Equal(Vk.Oem4, config.StopInputKey.Key);
    }

    [Fact]
    public void DefaultProfileLeavesCombatKeysUnbound()
    {
        var config = KeyConfig.DefaultConfig();
        Assert.True(config.SkillsMenuKey.IsEmpty);
        Assert.True(config.FollowerKey.IsEmpty);
        Assert.True(config.WorldMapKey.IsEmpty);
        Assert.True(config.WhisperKey.IsEmpty);
    }

    [Fact]
    public void WindowsKeyIsRejectedAsShortcut()
    {
        var config = KeyConfig.DefaultConfig();
        config.StartInputKey = InputKey.FromKey(Vk.LeftWin);
        config.Sanitize();

        Assert.Equal(Vk.Oem4, config.StartInputKey.Key);
    }

    [Fact]
    public void LeftClickIsRejectedAsSingleRepeatToggle()
    {
        var config = KeyConfig.DefaultConfig();
        config.SingleRepeatToggles[0] = InputKey.FromMouse(MouseButton.Left);
        config.Sanitize();

        Assert.True(config.SingleRepeatToggles[0].IsEmpty);
    }

    [Fact]
    public void SanitizeGuaranteesFiveOpenerStages()
    {
        var config = new KeyConfig();
        config.Sanitize();
        Assert.Equal(5, config.OpenerSteps.Length);
    }

    [Fact]
    public void SanitizeRepairsZeroComboCounts()
    {
        var config = new KeyConfig
        {
            ComboGeneratorCount = 0,
            ComboSpenderCount = 0,
            ComboInterval = 0,
        };
        config.Sanitize();

        Assert.Equal(3, config.ComboGeneratorCount);
        Assert.Equal(1, config.ComboSpenderCount);
        Assert.Equal(150, config.ComboInterval);
    }

    [Fact]
    public void MissingSkillCheckDefaultsToEnabled()
    {
        var config = KeyConfig.FromDictionary(JsonDocument.Parse("""{"memo":"x"}""").RootElement);
        Assert.True(config.SkillChecks[0]);
        Assert.True(config.SkillChecks[7]);
    }

    [Fact]
    public void EmptyDictionaryYieldsDefaults()
    {
        var config = KeyConfig.FromDictionary(JsonDocument.Parse("{}").RootElement);
        Assert.Equal(Vk.Oem4, config.StartInputKey.Key);
    }
}
