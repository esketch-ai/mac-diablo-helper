using System.Net;
using System.Text.Json;
using DM_Helper.Core.Models;

namespace DM_Helper.Core.Services;

/// <summary>
/// Reads and writes community presets on a shared Google Sheet.
///
/// Port of <c>D3GoogleSheetService.m</c>: the same gviz endpoint is queried for reads and
/// the same Apps Script Web App is POSTed to for writes, so one sheet serves both builds.
/// Results are cached to disk so the hub opens instantly and still works offline.
/// </summary>
public sealed class GoogleSheetClient
{
    private const string DefaultSheetUrl =
        "https://docs.google.com/spreadsheets/d/1X5u2U3sR8t8_DMHelper_DiabloCommunity_Presets/edit";

    private const string PrefSheetUrl = "GoogleSheet_SheetUrl";
    private const string PrefWebAppUrl = "GoogleSheet_WebAppUrl";
    private const string PrefLastAuthor = "GoogleSheet_LastAuthor";

    private readonly HttpClient _http;
    private readonly string _cachePath;
    private readonly object _gate = new();
    private List<PresetItem> _cache = new();

    public string SheetUrl { get; set; } = DefaultSheetUrl;
    public string WebAppUrl { get; set; } = "";
    public string LastAuthor { get; set; } = "";

    public event Action? PresetsChanged;

    public GoogleSheetClient(HttpClient? http = null, string? cachePath = null)
    {
        _http = http ?? new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
        _cachePath = cachePath ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "DM_Helper", "presets.json");

        SheetUrl = ConfigStore.Prefs.Get(PrefSheetUrl) ?? DefaultSheetUrl;
        WebAppUrl = ConfigStore.Prefs.Get(PrefWebAppUrl) ?? "";
        LastAuthor = ConfigStore.Prefs.Get(PrefLastAuthor) ?? "";

        LoadCache();
    }

    public IReadOnlyList<PresetItem> CachedPresets
    {
        get
        {
            lock (_gate) return _cache.ToArray();
        }
    }

    // =====================================================================
    // Reads
    // =====================================================================

    /// <summary>
    /// Builds the gviz JSON endpoint from a normal sheet URL, mirroring
    /// <c>gvizUrlFromSheetUrl:</c> on macOS.
    /// </summary>
    public static Uri? BuildGvizUrl(string sheetUrl)
    {
        if (string.IsNullOrWhiteSpace(sheetUrl)) return null;

        // Accept either /edit, /view, or a bare id.
        var id = ExtractSheetId(sheetUrl);
        if (id is null) return null;

        return new Uri($"https://docs.google.com/spreadsheets/d/{id}/gviz/tq?tqx=out:json");
    }

    private static string? ExtractSheetId(string url)
    {
        var marker = "/spreadsheets/d/";
        var idx = url.IndexOf(marker, StringComparison.OrdinalIgnoreCase);
        if (idx < 0) return null;

        var start = idx + marker.Length;
        var end = url.IndexOf('/', start);
        if (end < 0) end = url.Length;

        var id = url[start..end];
        return string.IsNullOrWhiteSpace(id) ? null : id;
    }

    /// <summary>Fetches the preset table. Returns false and leaves the cache intact on failure.</summary>
    public async Task<bool> RefreshAsync(CancellationToken ct = default)
    {
        var uri = BuildGvizUrl(SheetUrl);
        if (uri is null) return false;

        try
        {
            using var resp = await _http.GetAsync(uri, ct).ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode) return false;

            var body = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            var parsed = ParseGviz(body);
            if (parsed is null) return false;

            lock (_gate)
            {
                _cache = parsed;
                SaveCache();
            }

            PresetsChanged?.Invoke();
            return true;
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
        {
            // Offline or malformed response: keep showing the cached rows.
            return false;
        }
    }

    /// <summary>
    /// Parses the gviz payload. The endpoint wraps a JSON array inside a
    /// <c>/*O_o*/ google.visualization.Query.setResponse({...})</c> preamble, and the
    /// table body is a string that itself has to be parsed a second time.
    /// </summary>
    internal static List<PresetItem>? ParseGviz(string body)
    {
        if (string.IsNullOrWhiteSpace(body)) return null;

        var open = body.IndexOf("google.visualization.Query.setResponse", StringComparison.Ordinal);
        if (open < 0) return null;

        // Skip past the function name to its opening paren, then to the matching close.
        // Slicing from the paren itself (as an earlier version did) left the leading '('
        // in the JSON text, so every parse threw and the hub silently showed no presets.
        open = body.IndexOf('(', open);
        var close = body.LastIndexOf(')');
        if (open < 0 || close <= open) return null;

        var json = body[(open + 1)..close];

        // The table arrives as an embedded JSON string in some responses; unwrap it once.
        if (json.Length >= 2 && json[0] == '"')
        {
            try
            {
                json = JsonSerializer.Deserialize<string>(json) ?? json;
            }
            catch (JsonException)
            {
                return null;
            }
        }

        JsonElement envelope;
        try
        {
            envelope = JsonSerializer.Deserialize<JsonElement>(json);
        }
        catch (JsonException)
        {
            return null;
        }

        if (envelope.ValueKind != JsonValueKind.Object) return null;

        if (!envelope.TryGetProperty("table", out var table) ||
            table.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        if (!table.TryGetProperty("rows", out var rows) || rows.ValueKind != JsonValueKind.Array)
            return new List<PresetItem>();

        var items = new List<PresetItem>(rows.GetArrayLength());

        // The header is discovered from the first row that looks like one, then reused for
        // every subsequent row. Parsing per row instead would let a data row containing the
        // word "class" shift every column mapping after it.
        ColumnMap? header = null;

        foreach (var row in rows.EnumerateArray())
        {
            if (!row.TryGetProperty("c", out var cells) || cells.ValueKind != JsonValueKind.Array)
                continue;

            var values = new List<string>(cells.GetArrayLength());
            foreach (var cell in cells.EnumerateArray())
            {
                values.Add(cell.ValueKind == JsonValueKind.Object &&
                           cell.TryGetProperty("v", out var v)
                    ? v.ToString()
                    : "");
            }

            // A row that looks like a header is structure, not data. Skipping it is what
            // stops "직업" from appearing in the list as if it were a preset.
            var asHeader = TryReadHeader(values);
            if (asHeader is not null)
            {
                header ??= asHeader;
                continue;
            }

            if (TryBuildFromRow(values, header, out var item)) items.Add(item);
        }

        return items;
    }

    /// <summary>
    /// Reads a header row once, so every data row is mapped by column name instead of by
    /// position. The header is detected by matching known labels rather than by assuming
    /// the first row is one, because the sheet may have been created without one.
    /// </summary>
    private sealed class ColumnMap
    {
        private readonly List<string> _header;

        public ColumnMap(List<string> header)
        {
            _header = header;
            Author = Find("author", "작성자");
            Season = Find("season", "시즌");
            Class = Find("class", "직업");
            Build = Find("build", "빌드");
            Description = Find("desc", "설명");
            PresetName = Find("presetname", "프리셋");
        }

        public int? Author { get; }
        public int? Season { get; }
        public int? Class { get; }
        public int? Build { get; }
        public int? Description { get; }
        public int? PresetName { get; }

        public bool IsUsable => Class is not null || Build is not null;

        private int? Find(params string[] names)
        {
            foreach (var n in names)
            {
                for (var i = 0; i < _header.Count; i++)
                {
                    if (_header[i].Contains(n, StringComparison.OrdinalIgnoreCase)) return i;
                }
            }

            return null;
        }
    }

    /// <summary>
    /// Decides whether a row is a header. Requires a class label and a build label in the
    /// same row, which is a strong enough signal to avoid mistaking data for structure:
    /// a preset row names a class (도적, Warlock) but never contains the word "class" or
    /// "직업" as a field.
    ///
    /// Both English and Korean labels are matched because the shared sheet is edited by hand
    /// and either header style is common.
    /// </summary>
    private static ColumnMap? TryReadHeader(List<string> values)
    {
        bool Has(params string[] needles) =>
            values.Any(v => needles.Any(n => v.Contains(n, StringComparison.OrdinalIgnoreCase)));

        if (!Has("class", "직업") || !Has("build", "빌드")) return null;

        var map = new ColumnMap(values);
        return map.IsUsable ? map : null;
    }

    /// <summary>Maps one data row into a preset, by name when a header exists, else by position.</summary>
    private static bool TryBuildFromRow(List<string> values, ColumnMap? map, out PresetItem item)
    {
        item = new PresetItem();

        if (map is not null)
        {
            string At(int? col) =>
                col is null ? "" : values.ElementAtOrDefault(col.Value) ?? "";

            item = new PresetItem
            {
                Author = At(map.Author),
                Season = At(map.Season),
                Class = At(map.Class),
                Build = At(map.Build),
                Description = At(map.Description),
                PresetName = At(map.PresetName),
            };

            return !string.IsNullOrWhiteSpace(item.Class) || !string.IsNullOrWhiteSpace(item.Build);
        }

        // Positional fallback: author, season, class, build, desc, preset.
        item = new PresetItem
        {
            Author = values.ElementAtOrDefault(0) ?? "",
            Season = values.ElementAtOrDefault(1) ?? "",
            Class = values.ElementAtOrDefault(2) ?? "",
            Build = values.ElementAtOrDefault(3) ?? "",
            Description = values.ElementAtOrDefault(4) ?? "",
            PresetName = values.ElementAtOrDefault(5) ?? "",
        };

        return !string.IsNullOrWhiteSpace(item.Class) || !string.IsNullOrWhiteSpace(item.Build);
    }

    // =====================================================================
    // Writes
    // =====================================================================

    /// <summary>
    /// Appends a row through the Apps Script Web App. Returns the HTTP status so the UI can
    /// distinguish "posted" from "rejected".
    /// </summary>
    public async Task<HttpStatusCode> PublishAsync(PresetItem item, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(WebAppUrl))
            throw new InvalidOperationException("Apps Script Web App URL 이 설정되지 않았습니다.");

        using var content = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["author"] = string.IsNullOrWhiteSpace(item.Author) ? LastAuthor : item.Author,
            ["season"] = item.Season,
            ["class"] = item.Class,
            ["build"] = item.Build,
            ["desc"] = item.Description,
            ["presetName"] = item.PresetName,
        });

        using var resp = await _http.PostAsync(WebAppUrl, content, ct).ConfigureAwait(false);
        if (resp.IsSuccessStatusCode)
        {
            LastAuthor = string.IsNullOrWhiteSpace(item.Author) ? LastAuthor : item.Author;
            ConfigStore.Prefs.Set(PrefLastAuthor, LastAuthor);
        }

        return resp.StatusCode;
    }

    // =====================================================================
    // Cache
    // =====================================================================

    private void LoadCache()
    {
        try
        {
            if (!File.Exists(_cachePath)) return;

            var json = File.ReadAllText(_cachePath);
            var arr = JsonSerializer.Deserialize<List<Dictionary<string, JsonElement>>>(json);
            if (arr is null) return;

            var items = new List<PresetItem>(arr.Count);
            foreach (var d in arr)
            {
                using var doc = JsonSerializer.SerializeToDocument(d);
                items.Add(PresetItem.FromDictionary(doc.RootElement));
            }

            _cache = items;
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException)
        {
        }
    }

    private void SaveCache()
    {
        try
        {
            var dir = Path.GetDirectoryName(_cachePath)!;
            System.IO.Directory.CreateDirectory(dir);
            File.WriteAllText(_cachePath, JsonSerializer.Serialize(_cache.Select(i => i.ToDictionary())));
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
        }
    }

    public void SetSheetUrl(string url)
    {
        SheetUrl = url;
        ConfigStore.Prefs.Set(PrefSheetUrl, url);
    }

    public void SetWebAppUrl(string url)
    {
        WebAppUrl = url;
        ConfigStore.Prefs.Set(PrefWebAppUrl, url);
    }

    public void SetLastAuthor(string author)
    {
        LastAuthor = author;
        ConfigStore.Prefs.Set(PrefLastAuthor, author);
    }

    /// <summary>Seed rows so the hub is useful before the first successful fetch.</summary>
    public static IReadOnlyList<PresetItem> SeedPresets() => new[]
    {
        new PresetItem
        {
            Author = "성역의네팔렘", Season = "시즌 6 (증오의 그릇)", Class = "악마술사",
            Build = "🔥 타오르는 비명 오토봄버 (나락150단)",
            Description = "소환수 활성화 ➔ 탈태 지배력 버프 ➔ 감옥 CC ➔ 타오르는 비명(우클릭 120ms) 무한 폭격 빌드",
            PresetName = "악마술사 (타오르는 비명)",
        },
        new PresetItem
        {
            Author = "원소의지배자", Season = "시즌 6 (증오의 그릇)", Class = "원소술사",
            Build = "🔮 번개창 & 탈라샤 4원소 폭풍",
            Description = "얼음갑옷 + 순간이동 + 번개창 + 평타 3회로 4원소 탈라샤 스택 적재 후 본 공격 순환",
            PresetName = "원소술사 (번개창/탈라샤)",
        },
        new PresetItem
        {
            Author = "휠윈드장인", Season = "시즌 6 (증오의 그릇)", Class = "야만용사",
            Build = "⚔️ 무한 소용돌이 3함성 채널링",
            Description = "집결/도전/전장 3함성 순차 시전 ➔ 우클릭(소용돌이) [홀드(누름)] 모드로 무한 지속 회전",
            PresetName = "야만용사 (소용돌이)",
        },
        new PresetItem
        {
            Author = "어둠의암살자", Season = "시즌 6 (증오의 그릇)", Class = "도적",
            Build = "🏹 3:1 연계 콤보 회전칼날",
            Description = "암흑주입 진입 ➔ 구멍뚫기(생성기) 3회 ↔ 회전칼날(소모기) 1회 칼교대 자동 사이클",
            PresetName = "도적 (3콤보 포인트)",
        },
        new PresetItem
        {
            Author = "시체조종사", Season = "시즌 6 (증오의 그릇)", Class = "강령술사",
            Build = "💀 시폭 & 뼈창 초고속 연타 폭딜",
            Description = "골렘 ➔ 노화 저주 ➔ 시체 촉수 오프너 후 뼈창/시폭 초고속 연타",
            PresetName = "강령술사 (시폭/뼈창)",
        },
    };
}
