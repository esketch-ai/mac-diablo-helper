using System.Text;
using System.Text.Json;
using DM_Helper.Core.Models;

namespace DM_Helper.Core.Services;

/// <summary>
/// Profile persistence. Replaces <c>D3KeyConfigService</c>, which stored each profile as a
/// JSON string inside <c>NSUserDefaults</c>. Here each profile is a plain JSON file under
/// <c>%APPDATA%\DM_Helper\profiles</c>, which is easier to back up and to hand-edit.
/// </summary>
public sealed class ConfigStore
{
    private static readonly JsonSerializerOptions WriteOptions = new()
    {
        WriteIndented = true,
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    private readonly string _directory;
    private readonly object _gate = new();

    /// <summary>Raised whenever a profile is written, so the engine can reload it.</summary>
    public event Action<string>? ProfileSaved;

    public ConfigStore(string? directory = null)
    {
        _directory = directory ?? DefaultDirectory();
    }

    public static string DefaultDirectory()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        return Path.Combine(appData, "DM_Helper", "profiles");
    }

    public string ProfileDirectory => _directory;

    private string PathFor(string profileId) => Path.Combine(_directory, $"{Sanitize(profileId)}.json");

    private static string Sanitize(string profileId)
    {
        var invalid = Path.GetInvalidFileNameChars();
        return new string(profileId.Select(c => invalid.Contains(c) ? '_' : c).ToArray());
    }

    /// <summary>Loads a profile, falling back to defaults when it is missing or corrupt.</summary>
    public KeyConfig Load(string profileId)
    {
        try
        {
            var path = PathFor(profileId);
            if (File.Exists(path))
            {
                using var stream = File.OpenRead(path);
                using var doc = JsonDocument.Parse(stream);
                return KeyConfig.FromDictionary(doc.RootElement);
            }
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException)
        {
            // A damaged profile must not stop the app from starting.
        }

        return KeyConfig.DefaultConfig();
    }

    public bool Save(KeyConfig config, string profileId)
    {
        try
        {
            lock (_gate)
            {
                System.IO.Directory.CreateDirectory(_directory);

                var payload = JsonSerializer.Serialize(config.ToDictionary(), WriteOptions);
                var tmp = PathFor(profileId) + ".tmp";

                // Write-then-rename so a crash mid-write cannot truncate a good profile.
                File.WriteAllText(tmp, payload, new UTF8Encoding(false));
                File.Move(tmp, PathFor(profileId), overwrite: true);
            }

            ProfileSaved?.Invoke(profileId);
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or NotSupportedException)
        {
            return false;
        }
    }

    /// <summary>Exports a profile to an arbitrary path (the Save As / share flow).</summary>
    public bool Export(KeyConfig config, string filePath)
    {
        try
        {
            var payload = JsonSerializer.Serialize(config.ToDictionary(), WriteOptions);
            File.WriteAllText(filePath, payload, new UTF8Encoding(false));
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return false;
        }
    }

    public KeyConfig? Import(string filePath)
    {
        try
        {
            using var stream = File.OpenRead(filePath);
            using var doc = JsonDocument.Parse(stream);
            return KeyConfig.FromDictionary(doc.RootElement);
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    /// <summary>Copies a profile onto another slot.</summary>
    public bool Copy(string fromId, string toId)
    {
        var config = Load(fromId);
        return Save(config, toId);
    }

    public bool Delete(string profileId)
    {
        try
        {
            var path = PathFor(profileId);
            if (File.Exists(path)) File.Delete(path);
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return false;
        }
    }

    /// <summary>Profile ids that currently have a file on disk.</summary>
    public IReadOnlyList<string> ExistingProfiles()
    {
        try
        {
            if (!System.IO.Directory.Exists(_directory)) return Array.Empty<string>();
            return System.IO.Directory
                .GetFiles(_directory, "*.json")
                .Select(Path.GetFileNameWithoutExtension)
                .Where(n => n is not null)
                .Select(n => n!)
                .OrderBy(n => n, StringComparer.Ordinal)
                .ToArray();
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return Array.Empty<string>();
        }
    }

    /// <summary>A small JSON key/value store, standing in for the non-profile preferences.</summary>
    public static class Prefs
    {
        private static string FilePath => Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "DM_Helper", "prefs.json");

        private static Dictionary<string, string> LoadAll()
        {
            try
            {
                var path = FilePath;
                if (!System.IO.File.Exists(path)) return new Dictionary<string, string>();
                var json = System.IO.File.ReadAllText(path);
                return JsonSerializer.Deserialize<Dictionary<string, string>>(json)
                       ?? new Dictionary<string, string>();
            }
            catch (Exception ex) when (ex is IOException or JsonException)
            {
                return new Dictionary<string, string>();
            }
        }

        public static string? Get(string key)
        {
            var all = LoadAll();
            return all.TryGetValue(key, out var v) ? v : null;
        }

        public static int GetInt(string key, int fallback)
            => int.TryParse(Get(key), out var v) ? v : fallback;

        public static bool GetBool(string key, bool fallback)
            => bool.TryParse(Get(key), out var v) ? v : fallback;

        public static void Set(string key, string value)
        {
            try
            {
                var all = LoadAll();
                all[key] = value;

                var path = FilePath;
                System.IO.Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                System.IO.File.WriteAllText(path, JsonSerializer.Serialize(all), new UTF8Encoding(false));
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
            }
        }
    }
}
