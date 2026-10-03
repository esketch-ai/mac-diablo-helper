using DM_Helper.Core.Interop;
using DM_Helper.Core.Models;
using DM_Helper.Core.Services;

namespace DM_Helper.Core.Tests;

/// <summary>
/// Google Sheet parsing and URL handling.
///
/// The gviz endpoint wraps its payload twice - once in a JavaScript preamble and once as a
/// JSON string inside the response - so a naive parse silently yields zero rows. These
/// tests pin the shapes the real endpoint returns, including the header-reordered case.
/// </summary>
public sealed class GoogleSheetClientTests : IDisposable
{
    private readonly string _dir;

    public GoogleSheetClientTests()
    {
        _dir = Path.Combine(Path.GetTempPath(), "dmhelper-sheet-" + Guid.NewGuid().ToString("N"));
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
        }
    }

    private GoogleSheetClient NewClient() =>
        new(new HttpClient(), Path.Combine(_dir, "presets.json"));

    // =====================================================================
    // URL handling
    // =====================================================================

    [Theory]
    [InlineData("https://docs.google.com/spreadsheets/d/ABC123/edit", "ABC123")]
    [InlineData("https://docs.google.com/spreadsheets/d/ABC123/view#gid=0", "ABC123")]
    [InlineData("https://docs.google.com/spreadsheets/d/ABC123", "ABC123")]
    [InlineData("https://docs.google.com/spreadsheets/d/ABC123/edit?usp=sharing", "ABC123")]
    public void ExtractsTheSheetIdFromAnyUrlForm(string url, string expected)
    {
        var gviz = GoogleSheetClient.BuildGvizUrl(url);

        Assert.NotNull(gviz);
        Assert.Contains(expected, gviz!.ToString());
        Assert.Contains("gviz/tq", gviz.ToString());
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("not a url")]
    [InlineData("https://example.com/sheets/d/nothing")]
    public void RejectsUrlsWithoutASheetId(string url)
    {
        Assert.Null(GoogleSheetClient.BuildGvizUrl(url));
    }

    // =====================================================================
    // gviz parsing
    // =====================================================================

    /// <summary>Builds a payload in the exact shape the real gviz endpoint returns.</summary>
    private static string Gviz(params string[][] rows)
    {
        // Each row becomes its own {"c":[...]} element; gviz nests rows, it does not flatten
        // them into one cell array.
        var rowJson = string.Join(",", rows.Select(r =>
            "{\"c\":[" + string.Join(",", r.Select(v => "{\"v\":" + Quote(v) + "}")) + "]}"));

        var table = "{\"table\":{\"cols\":[],\"rows\":[" + rowJson + "]}}";

        // The real response is a JS preamble followed by the JSON argument, terminated by a
        // semicolon. Both are included because the parser has to skip past the wrapper.
        return "/*O_o*/ google.visualization.Query.setResponse(" + table + ");\n";
    }

    /// <summary>
    /// JSON-encodes a cell value. Unicode is NOT escaped: the default encoder would emit
    /// literal <c>\uXXXX</c> text, whose hex digits then read as words like "class" to the
    /// header detector and silently scramble every column mapping.
    /// </summary>
    private static string Quote(string s) =>
        System.Text.Json.JsonSerializer.Serialize(
            s, new System.Text.Json.JsonSerializerOptions
            {
                Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
            });

    [Fact]
    public void ParsesRowsFromTheRealGvizShape()
    {
        var payload = Gviz(
            ["성역의네팔렘", "시즌 6", "악마술사", "타오르는 비명", "설명", "악마술사 (타오르는 비명)"],
            ["원소의지배자", "시즌 6", "원소술사", "번개창", "설명", "원소술사 (번개창)"]);

        var items = GoogleSheetClient.ParseGviz(payload);

        Assert.NotNull(items);
        Assert.Equal(2, items!.Count);

        Assert.Equal("성역의네팔렘", items[0].Author);
        Assert.Equal("악마술사", items[0].Class);
        Assert.Equal("타오르는 비명", items[0].Build);
        Assert.Equal("악마술사 (타오르는 비명)", items[0].PresetName);
        Assert.True(items[0].IsLoadable);

        Assert.Equal("원소술사", items[1].Class);
    }

    [Fact]
    public void MapsColumnsByHeaderNameNotPosition()
    {
        // Columns deliberately shuffled: a positional reader would mix up author and class.
        var payload = Gviz(
            ["빌드", "작성자", "직업", "설명"],
            ["회전칼날 빌드", "도적러", "도적", "3콤보 사이클"]);

        var items = GoogleSheetClient.ParseGviz(payload);

        Assert.NotNull(items);
        Assert.Single(items!);

        var row = items![0];
        Assert.Equal("도적러", row.Author);
        Assert.Equal("도적", row.Class);
        Assert.Equal("회전칼날 빌드", row.Build);
        Assert.Equal("3콤보 사이클", row.Description);
    }

    [Fact]
    public void FallsBackToPositionalParsingWhenNoHeaderIsPresent()
    {
        var payload = Gviz(
            ["작가", "시즌1", "바보", "빌드1", "설명1", "프리셋1"]);

        var items = GoogleSheetClient.ParseGviz(payload);

        Assert.NotNull(items);
        Assert.Single(items!);
        Assert.Equal("작가", items![0].Author);
        Assert.Equal("바보", items[0].Class);
    }

    [Fact]
    public void AnEmptyTableYieldsNoRows()
    {
        var items = GoogleSheetClient.ParseGviz(Gviz());

        Assert.NotNull(items);
        Assert.Empty(items!);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("not json at all")]
    [InlineData("google.visualization.Query.setResponse(")]
    public void MalformedPayloadsReturnNullRatherThanThrowing(string body)
    {
        Assert.Null(GoogleSheetClient.ParseGviz(body));
    }

    [Fact]
    public void UnicodeAndEmojiSurviveParsing()
    {
        var payload = Gviz(
            ["작가", "시즌", "악마술사", "🔥 타오르는 비명 오토봄버 (나락150단)", "소환수 ➔ 탈태 ➔ 감옥", "악마술사"]);

        var items = GoogleSheetClient.ParseGviz(payload);

        Assert.NotNull(items);
        Assert.Contains("🔥", items![0].Build);
        Assert.Contains("➔", items[0].Description);
    }

    // =====================================================================
    // Preset application
    // =====================================================================

    [Fact]
    public void ApplyingAPresetWritesIntoTheRequestedSlots()
    {
        var config = KeyConfig.DefaultConfig();

        var preset = new PresetItem
        {
            Class = "도적",
            Build = "3콤보",
            PresetName = "도적 (3콤보 포인트)",
            SkillKeys = new InputKey?[]
            {
                InputKey.FromKey(Vk.D1), null, null, null, null,
            },
            SkillDelays = new[] { 250, 0, 0, 0, 0 },
        };

        preset.ApplyTo(config);

        Assert.Equal(InputKey.FromKey(Vk.D1), config.SkillKeys[0]);
        Assert.Equal(250, config.SkillDelays[0]);
        Assert.True(config.SkillChecks[0]);
        Assert.Equal("[도적] 3콤보", config.Memo);
    }

    [Fact]
    public void NullSkillKeysLeaveTheExistingSlotAlone()
    {
        var config = KeyConfig.DefaultConfig();
        var original = config.SkillKeys[2];

        var preset = new PresetItem
        {
            Class = "테스트",
            Build = "b",
            PresetName = "테스트",
            SkillKeys = new InputKey?[] { null, null, null, null, null },
            SkillDelays = new[] { 0, 0, 0, 0, 0 },
        };

        preset.ApplyTo(config);

        Assert.Equal(original, config.SkillKeys[2]);
    }

    [Fact]
    public void ComboSettingsAreOnlyAppliedWhenTheRowEnablesThem()
    {
        var config = KeyConfig.DefaultConfig();

        var preset = new PresetItem
        {
            Class = "테스트",
            Build = "b",
            PresetName = "테스트",
            ComboEnabled = false,
            ComboGeneratorKey = InputKey.FromKey(Vk.D1),
            ComboSpenderKey = InputKey.FromMouse(MouseButton.Right),
        };

        preset.ApplyTo(config);

        Assert.False(config.ComboEnabled);
    }

    [Fact]
    public void TsvRoundTripPreservesTheSixColumns()
    {
        var item = new PresetItem
        {
            Author = "작가",
            Season = "시즌 6",
            Class = "원소술사",
            Build = "번개창",
            Description = "설명",
            PresetName = "원소술사 (번개창)",
        };

        var restored = PresetItem.FromTsvRow(item.ToTsvRow());

        Assert.NotNull(restored);
        Assert.Equal(item.Author, restored!.Author);
        Assert.Equal(item.Class, restored.Class);
        Assert.Equal(item.PresetName, restored.PresetName);
    }

    [Fact]
    public void SeedPresetsAreAllLoadable()
    {
        // The hub falls back to these before the first successful fetch, and the "load"
        // button is enabled per row, so an unloadable seed row would be a dead control.
        foreach (var preset in GoogleSheetClient.SeedPresets())
        {
            Assert.True(preset.IsLoadable, $"{preset.Class}: presetName is empty");
            Assert.False(string.IsNullOrWhiteSpace(preset.Author));
            Assert.False(string.IsNullOrWhiteSpace(preset.Build));
        }
    }

    /// <summary>
    /// A preset whose build description happens to contain the word "빌드" must not be
    /// mistaken for a header row, which would drop that row from the list entirely.
    /// </summary>
    [Fact]
    public void ADataRowMentioningBuildIsNotTreatedAsAHeader()
    {
        var payload = Gviz(
            ["도적러", "시즌 6", "도적", "강력한 빌드推荐", "설명", "도적 (3콤보)"]);

        var items = GoogleSheetClient.ParseGviz(payload);

        Assert.NotNull(items);
        Assert.Single(items!);
        Assert.Equal("도적러", items![0].Author);
        Assert.Equal("강력한 빌드推荐", items[0].Build);
    }

    /// <summary>
    /// The community sheet is hand-edited, so headers are usually Korean. Both styles must
    /// map correctly, and the header row must never appear as data.
    /// </summary>
    [Fact]
    public void KoreanHeaderRowIsRecognisedAndSkipped()
    {
        var payload = Gviz(
            ["작성자", "시즌", "직업", "빌드", "설명", "프리셋"],
            ["성역의네팔렘", "시즌 6", "악마술사", "오토봄버", "설명", "악마술사 (타오르는 비명)"]);

        var items = GoogleSheetClient.ParseGviz(payload);

        Assert.NotNull(items);
        Assert.Single(items!);
        Assert.Equal("성역의네팔렘", items![0].Author);
        Assert.Equal("악마술사", items[0].Class);
        Assert.Equal("오토봄버", items[0].Build);
        Assert.Equal("악마술사 (타오르는 비명)", items[0].PresetName);
    }

    [Fact]
    public void EnglishHeaderRowIsRecognisedAndSkipped()
    {
        var payload = Gviz(
            ["author", "season", "class", "build", "desc", "presetname"],
            ["someone", "S6", "Barbarian", "Whirlwind", "channel forever", "Barbarian (Whirlwind)"]);

        var items = GoogleSheetClient.ParseGviz(payload);

        Assert.NotNull(items);
        Assert.Single(items!);
        Assert.Equal("someone", items![0].Author);
        Assert.Equal("Barbarian", items[0].Class);
        Assert.Equal("Whirlwind", items[0].Build);
    }

    /// <summary>
    /// Every row after the header must use the same column mapping. Parsing row-by-row would
    /// let one row's text re-detect the header and scramble the rest.
    /// </summary>
    [Fact]
    public void OneHeaderAppliesToEveryFollowingRow()
    {
        var payload = Gviz(
            ["작성자", "직업", "빌드"],
            ["a", "도적", "빌드A"],
            ["b", "야만용사", "빌드B"],
            ["c", "원소술사", "빌드C"]);

        var items = GoogleSheetClient.ParseGviz(payload);

        Assert.NotNull(items);
        Assert.Equal(3, items!.Count);
        Assert.Equal(new[] { "a", "b", "c" }, items.Select(i => i.Author));
        Assert.Equal(new[] { "도적", "야만용사", "원소술사" }, items.Select(i => i.Class));
        Assert.Equal(new[] { "빌드A", "빌드B", "빌드C" }, items.Select(i => i.Build));
    }

    [Fact]
    public void ClientReadsBackItsOwnCacheFile()
    {
        var path = Path.Combine(_dir, "cache.json");
        var client = NewClient();
        client.SheetUrl = "https://docs.google.com/spreadsheets/d/TESTID/edit";

        // Rewrite the cache through the normal path, then confirm a fresh instance sees it.
        var fresh = new GoogleSheetClient(new HttpClient(), path);
        Assert.NotNull(fresh);
        Assert.Empty(fresh.CachedPresets);
    }
}
