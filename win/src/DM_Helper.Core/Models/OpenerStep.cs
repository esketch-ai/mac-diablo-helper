using System.Text.Json;
using System.Text.Json.Serialization;
using DM_Helper.Core.Interop;

namespace DM_Helper.Core.Models;

/// <summary>
/// One stage of the opener / ramp-up sequence: press a key N times, waiting
/// <see cref="DelayMs"/> between presses, then move to the next stage.
/// </summary>
public sealed record OpenerStep
{
    public InputKey Key { get; init; } = InputKey.Empty;
    public int DelayMs { get; init; } = 150;
    public int RepeatCount { get; init; } = 1;
    public string Description { get; init; } = "";

    [JsonIgnore]
    public bool IsEmpty => Key.IsEmpty;

    public static OpenerStep Create(InputKey key, int delayMs, int repeatCount, string description) =>
        new()
        {
            Key = key ?? InputKey.Empty,
            DelayMs = delayMs < 10 ? 150 : delayMs,
            RepeatCount = repeatCount < 1 ? 1 : repeatCount,
            Description = description ?? "",
        };

    public static OpenerStep Default => new()
    {
        Key = InputKey.Empty,
        DelayMs = 150,
        RepeatCount = 1,
        Description = "",
    };

    public Dictionary<string, object?> ToDictionary() => new()
    {
        ["key"] = Key.ToDictionary(),
        ["delayMs"] = DelayMs,
        ["repeatCount"] = RepeatCount,
        ["description"] = Description,
    };

    public static OpenerStep FromDictionary(JsonElement e)
    {
        if (e.ValueKind != JsonValueKind.Object) return Default;

        var key = e.TryGetProperty("key", out var k)
            ? InputKey.FromDictionary(ParseObject(k))
            : InputKey.Empty;

        return new OpenerStep
        {
            Key = key,
            DelayMs = e.TryGetProperty("delayMs", out var d) ? d.GetInt32() : 150,
            RepeatCount = e.TryGetProperty("repeatCount", out var r) ? r.GetInt32() : 1,
            Description = e.TryGetProperty("description", out var s) ? s.GetString() ?? "" : "",
        };
    }

    internal static IReadOnlyDictionary<string, JsonElement> ParseObject(JsonElement e) =>
        JsonObjectHelper.Flatten(e);

    /// <summary>Test-only accessor for the shared object flattener.</summary>
    public static IReadOnlyDictionary<string, JsonElement> ParseObjectForTests(JsonElement e) =>
        JsonObjectHelper.Flatten(e);
}

/// <summary>Shared JSON-object flattening helper for the dictionary-shaped model objects.</summary>
internal static class JsonObjectHelper
{
    internal static IReadOnlyDictionary<string, JsonElement> Flatten(JsonElement e)
    {
        var dict = new Dictionary<string, JsonElement>();
        if (e.ValueKind != JsonValueKind.Object) return dict;
        foreach (var p in e.EnumerateObject()) dict[p.Name] = p.Value;
        return dict;
    }
}
