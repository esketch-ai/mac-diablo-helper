using System.Text.Json;

namespace DM_Helper.Core.Models;

/// <summary>
/// One community preset row from the shared Google Sheet.
///
/// Port of <c>D3PresetItem</c>. The wire format is unchanged so the same sheet serves both
/// the macOS and Windows builds.
/// </summary>
public sealed record PresetItem
{
    public string Author { get; init; } = "";
    public string Season { get; init; } = "";
    public string Class { get; init; } = "";
    public string Build { get; init; } = "";
    public string Description { get; init; } = "";

    /// <summary>Key that identifies a local preset this row maps onto.</summary>
    public string PresetName { get; init; } = "";

    /// <summary>Skill slots, index 0-4 correspond to skill slots 1-5.</summary>
    public InputKey?[] SkillKeys { get; init; } = new InputKey?[5];

    public int[] SkillDelays { get; init; } = new int[5];

    public bool ComboEnabled { get; init; }
    public InputKey ComboGeneratorKey { get; init; } = InputKey.Empty;
    public int ComboGeneratorCount { get; init; } = 3;
    public InputKey ComboSpenderKey { get; init; } = InputKey.Empty;
    public int ComboSpenderCount { get; init; } = 1;
    public int ComboInterval { get; init; } = 150;

    public bool OpenerEnabled { get; init; }
    public OpenerStep[] OpenerSteps { get; init; } = Array.Empty<OpenerStep>();

    public string Memo => $"[{Class}] {Build}".Trim();

    /// <summary>
    /// True when the row names a class preset we know about, which is what makes the
    /// "load into my slots" button offer a destination.
    /// </summary>
    public bool IsLoadable => !PresetName.IsNullOrWhiteSpace();

    /// <summary>Applies this preset's skill slots and combo settings onto a profile.</summary>
    public KeyConfig ApplyTo(KeyConfig config)
    {
        for (var i = 0; i < 5 && i < SkillKeys.Length; i++)
        {
            if (SkillKeys[i] is { IsEmpty: false } key)
            {
                config.SkillKeys[i] = key;
                config.SkillDelays[i] = SkillDelays[i];
                config.SkillChecks[i] = true;
            }
        }

        if (ComboEnabled)
        {
            config.ComboEnabled = true;
            config.ComboGeneratorKey = ComboGeneratorKey;
            config.ComboGeneratorCount = ComboGeneratorCount;
            config.ComboSpenderKey = ComboSpenderKey;
            config.ComboSpenderCount = ComboSpenderCount;
            config.ComboInterval = ComboInterval;
        }

        if (OpenerEnabled && OpenerSteps.Length > 0)
        {
            config.OpenerEnabled = true;
            for (var i = 0; i < OpenerSteps.Length && i < config.OpenerSteps.Length; i++)
                config.OpenerSteps[i] = OpenerSteps[i];
        }

        config.Memo = Memo;
        return config;
    }

    /// <summary>Builds a TSV row, matching what the macOS build copied to the pasteboard.</summary>
    public string ToTsvRow() => string.Join("\t", new[]
    {
        Author, Season, Class, Build, Description, PresetName,
    });

    public static PresetItem? FromTsvRow(string row)
    {
        var cells = row.Split('\t');
        if (cells.Length < 1) return null;

        return new PresetItem
        {
            Author = cells.ElementAtOrDefault(0) ?? "",
            Season = cells.ElementAtOrDefault(1) ?? "",
            Class = cells.ElementAtOrDefault(2) ?? "",
            Build = cells.ElementAtOrDefault(3) ?? "",
            Description = cells.ElementAtOrDefault(4) ?? "",
            PresetName = cells.ElementAtOrDefault(5) ?? "",
        };
    }

    public Dictionary<string, object?> ToDictionary() => new()
    {
        ["author"] = Author,
        ["season"] = Season,
        ["class"] = Class,
        ["build"] = Build,
        ["desc"] = Description,
        ["presetName"] = PresetName,
    };

    public static PresetItem FromDictionary(JsonElement e)
    {
        if (e.ValueKind != JsonValueKind.Object) return new PresetItem();

        string Str(string k) => e.TryGetProperty(k, out var v) && v.ValueKind == JsonValueKind.String
            ? v.GetString() ?? ""
            : "";

        return new PresetItem
        {
            Author = Str("author"),
            Season = Str("season"),
            Class = Str("class"),
            Build = Str("build"),
            Description = Str("desc"),
            PresetName = Str("presetName"),
        };
    }
}

internal static class StringExtensions
{
    internal static bool IsNullOrWhiteSpace(this string? s) => string.IsNullOrWhiteSpace(s);
}
