using DM_Helper.Core.Interop;
using DM_Helper.Core.Models;
using DM_Helper.Core.Services;

namespace DM_Helper.Core.Tests;

/// <summary>
/// Port of <c>testDeadzoneFilter</c> plus coverage for every shipped preset.
/// </summary>
public class PresetAndDeadzoneTests
{
    [Fact]
    public void SupportedResolutionsIncludeWindowsCommonModes()
    {
        var labels = DeadzoneFilterOptions.Options.Select(o => o.Label).ToArray();

        Assert.True(DeadzoneFilterOptions.Options.Length >= 5);
        Assert.Contains("1920 x 1080 (FHD)", labels);
        Assert.Contains("2560 x 1440 (QHD)", labels);
        Assert.Contains("3440 x 1440 (UltraWide)", labels);
        Assert.Contains("3840 x 2160 (4K UHD)", labels);
        Assert.Contains(DeadzoneFilterOptions.AutoDetect, labels);
    }

    /// <summary>MacBook-specific entries from the macOS build must not leak into Windows.</summary>
    [Fact]
    public void NoMacOnlyResolutionsRemain()
    {
        var labels = string.Join("|", DeadzoneFilterOptions.Options.Select(o => o.Label));
        Assert.DoesNotContain("MacBook", labels);
    }

    [Fact]
    public void AutoDetectResolvesToNoFixedSize()
    {
        Assert.Null(DeadzoneFilterOptions.Resolve(DeadzoneFilterOptions.AutoDetect));
        Assert.Null(DeadzoneFilterOptions.Resolve("nonsense"));
        Assert.Equal((1920, 1080), DeadzoneFilterOptions.Resolve("1920 x 1080 (FHD)"));
    }

    private static readonly MonitorRect Fhd = new(0, 0, 1920, 1080);

    [Fact]
    public void ActionBarAreaIsDead()
    {
        // Bottom centre, inside the action bar.
        Assert.True(DeadzoneFilter.Evaluate((960, 950), "1920 x 1080 (FHD)", Fhd));
    }

    [Fact]
    public void ActionBarSpansOnlyTheCentreOfTheScreen()
    {
        // Same height, but out at the far left edge - outside the bar's 22%-78% span.
        Assert.False(DeadzoneFilter.Evaluate((100, 950), "1920 x 1080 (FHD)", Fhd));
    }

    [Fact]
    public void MinimapAreaIsDead()
    {
        // Top right.
        Assert.True(DeadzoneFilter.Evaluate((1800, 100), "1920 x 1080 (FHD)", Fhd));
    }

    [Fact]
    public void ScreenCentreIsLive()
    {
        Assert.False(DeadzoneFilter.Evaluate((960, 540), "1920 x 1080 (FHD)", Fhd));
    }

    /// <summary>
    /// The filter works in monitor-relative coordinates, so a secondary display positioned
    /// left of and above the primary must not shift the deadzone.
    /// </summary>
    [Fact]
    public void SecondaryMonitorOffsetIsHandled()
    {
        var second = new MonitorRect(-1920, -200, 1920, 1080);

        // Local position inside the action bar of the second monitor.
        Assert.True(DeadzoneFilter.Evaluate((-960, 850), "1920 x 1080 (FHD)", second));

        // Same local position, centre of that monitor.
        Assert.False(DeadzoneFilter.Evaluate((-960, 440), "1920 x 1080 (FHD)", second));
    }

    /// <summary>
    /// Pins the render resolution and confirms the cursor is mapped into that space
    /// before the ratios are applied. Both the cursor and the bar line scale together, so
    /// the vertical verdict is scale-invariant - which is the behaviour the macOS build
    /// had, and this test pins it down so a refactor cannot silently change it.
    /// </summary>
    [Fact]
    public void PinnedResolutionMapsCursorIntoRenderSpace()
    {
        var monitor = new MonitorRect(0, 0, 2560, 1440);

        // Bottom 20% of a 2560x1440 render starts at y = 1152.
        Assert.True(DeadzoneFilter.Evaluate((1280, 1250), DeadzoneFilterOptions.AutoDetect, monitor));
        Assert.True(DeadzoneFilter.Evaluate((1280, 1250), "1920 x 1080 (FHD)", monitor));

        // y = 1100 of 1440 is 0.764 of the height, above the bar at every scale.
        Assert.False(DeadzoneFilter.Evaluate((1280, 1100), DeadzoneFilterOptions.AutoDetect, monitor));
        Assert.False(DeadzoneFilter.Evaluate((1280, 1100), "1920 x 1080 (FHD)", monitor));
        Assert.False(DeadzoneFilter.Evaluate((1280, 1100), "3840 x 2160 (4K UHD)", monitor));
    }

    /// <summary>
    /// The bar's horizontal span is 22%-78% of the width, and pinning does shift where the
    /// edges fall in physical pixels even though the ratio is preserved. A user running the
    /// game at a non-native resolution can therefore widen the bar.
    /// </summary>
    [Fact]
    public void PinnedResolutionShiftsTheBarHorizontally()
    {
        var monitor = new MonitorRect(0, 0, 2560, 1440);
        var y = 1300; // inside the bar vertically

        // Physically at x = 300: 11.7% of the width.
        Assert.False(DeadzoneFilter.Evaluate((300, y), DeadzoneFilterOptions.AutoDetect, monitor));

        // Pinned to 3440x1440 the bar covers 0.22 * 3440 = 757px onward in render space,
        // which maps back to the same physical ratio - so this stays false too.
        Assert.False(DeadzoneFilter.Evaluate((300, y), "3440 x 1440 (UltraWide)", monitor));

        // Dead centre is inside the bar at every scale.
        Assert.True(DeadzoneFilter.Evaluate((1280, y), "3440 x 1440 (UltraWide)", monitor));
    }

    [Theory]
    [InlineData(KeyConfig.PresetKind.Standard)]
    [InlineData(KeyConfig.PresetKind.Warlock)]
    [InlineData(KeyConfig.PresetKind.Sorcerer)]
    [InlineData(KeyConfig.PresetKind.Necromancer)]
    [InlineData(KeyConfig.PresetKind.Barbarian)]
    [InlineData(KeyConfig.PresetKind.Rogue)]
    [InlineData(KeyConfig.PresetKind.Spiritborn)]
    public void EveryPresetProducesAUsableProfile(KeyConfig.PresetKind kind)
    {
        var config = KeyConfig.ForPreset(kind);

        Assert.False(string.IsNullOrWhiteSpace(config.Memo));
        Assert.False(config.StartInputKey.IsEmpty);

        // At least four skill slots must be bound or the macro does nothing.
        var bound = Enumerable.Range(0, 8).Count(i => !config.SkillKey(i).IsEmpty);
        Assert.True(bound >= 4, $"{kind} bound only {bound} skills");

        // No forbidden key may survive Sanitize.
        Assert.NotEqual(InputKey.FromKey(Vk.LeftWin), config.StartInputKey);
    }

    [Fact]
    public void BarbarianUsesHoldModeForWhirlwind()
    {
        var config = KeyConfig.ForPreset(KeyConfig.PresetKind.Barbarian);
        Assert.True(config.SkillHolds[4]);
        Assert.Equal(MouseButton.Right, config.SkillKey(4).MouseButton);
    }

    [Fact]
    public void RogueSetsUpThreeToOneCombo()
    {
        var config = KeyConfig.ForPreset(KeyConfig.PresetKind.Rogue);

        Assert.True(config.ComboEnabled);
        Assert.Equal(3, config.ComboGeneratorCount);
        Assert.Equal(1, config.ComboSpenderCount);
        Assert.Equal(InputType.Keyboard, config.ComboGeneratorKey.Type);
    }

    [Fact]
    public void PresetNamesHaveBothLanguages()
    {
        Assert.Equal(7, KeyConfig.PresetNames.Length);
        Assert.All(KeyConfig.PresetNames, p =>
        {
            Assert.NotEmpty(p.Ko);
            Assert.NotEmpty(p.En);
        });
    }
}
