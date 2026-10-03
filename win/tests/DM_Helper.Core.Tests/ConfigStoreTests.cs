using System.Text.Json;
using DM_Helper.Core.Interop;
using DM_Helper.Core.Models;
using DM_Helper.Core.Services;

namespace DM_Helper.Core.Tests;

/// <summary>
/// Profile persistence. These paths matter more than they look: a profile that fails to
/// round-trip silently resets a user's carefully tuned opener timings.
/// </summary>
public sealed class ConfigStoreTests : IDisposable
{
    private readonly string _dir;

    public ConfigStoreTests()
    {
        _dir = Path.Combine(Path.GetTempPath(), "dmhelper-tests-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_dir);
    }

    public void Dispose()
    {
        try
        {
            if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true);
        }
        catch (IOException)
        {
            // A leftover temp directory is not worth failing a test run over.
        }
    }

    private ConfigStore NewStore() => new(_dir);

    [Fact]
    public void MissingProfileFallsBackToDefaults()
    {
        var config = NewStore().Load("1");

        Assert.Equal(Vk.Oem4, config.StartInputKey.Key);
        Assert.Equal(1000, config.SkillDelay(0));
    }

    [Fact]
    public void SavedProfileReloadsIdentically()
    {
        var store = NewStore();

        var original = KeyConfig.ForPreset(KeyConfig.PresetKind.Warlock);
        original.Memo = "재접근 테스트";
        original.SkillDelays[4] = 137;
        original.SkillHolds[4] = true;
        original.ComboEnabled = true;
        original.ComboGeneratorKey = InputKey.FromKey(Vk.D5);
        original.SingleRepeatDelays[0] = 42;

        Assert.True(store.Save(original, "3"));

        var loaded = store.Load("3");

        Assert.Equal("재접근 테스트", loaded.Memo);
        Assert.Equal(137, loaded.SkillDelays[4]);
        Assert.True(loaded.SkillHolds[4]);
        Assert.True(loaded.ComboEnabled);
        Assert.Equal(InputKey.FromKey(Vk.D5), loaded.ComboGeneratorKey);
        Assert.Equal(42, loaded.SingleRepeatDelays[0]);
        Assert.Equal(original.StartInputKey, loaded.StartInputKey);
    }

    [Fact]
    public void CorruptFileFallsBackToDefaultsInsteadOfThrowing()
    {
        File.WriteAllText(Path.Combine(_dir, "4.json"), "{ this is not json");

        var config = NewStore().Load("4");

        Assert.Equal(Vk.Oem4, config.StartInputKey.Key);
    }

    [Fact]
    public void EmptyFileFallsBackToDefaults()
    {
        File.WriteAllText(Path.Combine(_dir, "5.json"), string.Empty);
        Assert.Equal(Vk.Oem4, NewStore().Load("5").StartInputKey.Key);
    }

    [Fact]
    public void JsonWithUnknownExtraKeysIsAccepted()
    {
        // Forward compatibility: a profile written by a newer build must still load.
        // keyCode 49 is VK_1 on Windows, but the display string is what wins so the value
        // does not depend on the numeric code space.
        File.WriteAllText(Path.Combine(_dir, "6.json"), """
            {
              "memo": "from a future version",
              "someKeyWeDoNotKnow": 12345,
              "skillKey1": { "type": 1, "keyCode": 49, "mouseButton": -1, "wheelDirection": 0, "display": "1" }
            }
            """);

        var config = NewStore().Load("6");

        Assert.Equal("from a future version", config.Memo);
        Assert.Equal(Vk.D1, config.SkillKey(0).Key);
    }

    [Fact]
    public void ProfilesAreIsolatedFromEachOther()
    {
        var store = NewStore();

        store.Save(KeyConfig.DefaultConfig(), "1");
        store.Save(KeyConfig.ForPreset(KeyConfig.PresetKind.Rogue), "2");

        Assert.False(store.Load("1").ComboEnabled);
        Assert.True(store.Load("2").ComboEnabled);
    }

    [Fact]
    public void SaveLeavesNoTemporaryFileBehind()
    {
        // The write-then-rename path must clean up its .tmp, or a crash mid-save would leave
        // stray files the user never asked for.
        var store = NewStore();
        store.Save(KeyConfig.DefaultConfig(), "1");

        var strays = Directory.GetFiles(_dir, "*.tmp");
        Assert.Empty(strays);
    }

    [Fact]
    public void OverwriteReplacesRatherThanAppends()
    {
        var store = NewStore();

        var first = KeyConfig.DefaultConfig();
        first.Memo = "v1";
        store.Save(first, "1");

        var second = KeyConfig.DefaultConfig();
        second.Memo = "v2";
        store.Save(second, "1");

        Assert.Equal("v2", store.Load("1").Memo);

        // A stale append would leave "v1" in the file, which would then parse as garbage
        // and silently reset the profile.
        var raw = File.ReadAllText(Path.Combine(_dir, "1.json"));
        Assert.DoesNotContain("v1", raw);
        using var doc = JsonDocument.Parse(raw);
        Assert.NotEqual(JsonValueKind.Undefined, doc.RootElement.ValueKind);
    }

    [Fact]
    public void ExportAndImportRoundTripThroughAnArbitraryPath()
    {
        var store = NewStore();
        var path = Path.Combine(_dir, "exported.dhp");

        var original = KeyConfig.ForPreset(KeyConfig.PresetKind.Spiritborn);
        original.Memo = "exported";

        Assert.True(store.Export(original, path));

        var imported = store.Import(path);
        Assert.NotNull(imported);
        Assert.Equal("exported", imported!.Memo);
        Assert.True(imported.OpenerEnabled);
    }

    [Fact]
    public void ImportOfGarbageReturnsNull()
    {
        var path = Path.Combine(_dir, "bad.dhp");
        File.WriteAllText(path, "nonsense");

        Assert.Null(NewStore().Import(path));
    }

    [Fact]
    public void ImportOfMissingFileReturnsNull()
    {
        Assert.Null(NewStore().Import(Path.Combine(_dir, "does-not-exist.dhp")));
    }

    [Fact]
    public void CopyDuplicatesAProfile()
    {
        var store = NewStore();

        var source = KeyConfig.ForPreset(KeyConfig.PresetKind.Barbarian);
        store.Save(source, "1");

        Assert.True(store.Copy("1", "2"));

        var copy = store.Load("2");
        Assert.True(copy.SkillHold(4));
        Assert.Equal(source.Memo, copy.Memo);
    }

    [Fact]
    public void DeleteRemovesTheProfileFile()
    {
        var store = NewStore();
        store.Save(KeyConfig.DefaultConfig(), "1");

        Assert.True(store.Delete("1"));
        Assert.False(File.Exists(Path.Combine(_dir, "1.json")));
    }

    [Fact]
    public void ExistingProfilesListsWhatIsOnDisk()
    {
        var store = NewStore();
        store.Save(KeyConfig.DefaultConfig(), "1");
        store.Save(KeyConfig.DefaultConfig(), "2");

        var ids = store.ExistingProfiles();
        Assert.Contains("1", ids);
        Assert.Contains("2", ids);
    }

    [Fact]
    public void ProfileIdWithPathSeparatorsCannotEscapeTheDirectory()
    {
        // The profile id reaches this class from a UI control. Without sanitising, a value
        // like "..\\..\\startup\\evil" would write outside the profiles folder.
        var store = NewStore();

        store.Save(KeyConfig.DefaultConfig(), "../../escaped");

        foreach (var file in Directory.GetFiles(_dir, "*.json", SearchOption.AllDirectories))
        {
            Assert.StartsWith(Path.GetFullPath(_dir), Path.GetFullPath(file));
        }
    }

    [Fact]
    public void EveryPresetSurvivesAWriteAndRead()
    {
        var store = NewStore();

        foreach (var kind in Enum.GetValues<KeyConfig.PresetKind>())
        {
            var id = $"preset-{kind}";
            Assert.True(store.Save(KeyConfig.ForPreset(kind), id), $"save failed for {kind}");

            var loaded = store.Load(id);
            Assert.Equal(KeyConfig.ForPreset(kind).Memo, loaded.Memo);
        }
    }
}
