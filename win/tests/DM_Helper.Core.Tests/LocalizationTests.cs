using DM_Helper.Core.Services;

namespace DM_Helper.Core.Tests;

/// <summary>
/// Guards the localization table.
///
/// Two failure modes are worth catching automatically. A key used by the UI but missing
/// from the dictionary renders as the raw key string ("label_speed_key") in both
/// languages, which is easy to miss by eye. And a one-sided entry silently falls back to
/// Korean when the user has chosen English, which reads as a half-finished translation.
/// </summary>
public class LocalizationTests
{
    /// <summary>
    /// Every key the UI actually asks for. If a key is added here but not to
    /// <see cref="Localization.Table"/>, this test fails rather than shipping a raw key to
    /// the user.
    /// </summary>
    private static readonly string[] UiKeys =
    {
        // Top bar
        "profile_label", "opener_btn", "memo_label", "memo_placeholder",
        "engine_start", "engine_stop",

        // Tabs
        "tab_helper", "tab_rotation", "tab_features",

        // Tab 1
        "box_start_stop", "label_start_key", "label_stop_key", "label_opener_key",
        "hint_start_stop",
        "box_ingame", "label_inventory", "label_skills", "label_follower", "label_map",
        "label_world_map", "label_portal", "label_chat", "label_whisper",
        "box_skills",

        // Tab 2
        "box_opener", "btn_opener_enable", "label_opener_trigger", "btn_opener_test",
        "box_combo", "btn_combo_enable", "label_combo_gen", "label_combo_spend",
        "label_combo_interval",

        // Tab 3
        "box_single_repeat", "box_special",
        "label_quest_key", "hint_quest",
        "label_speed_key", "label_speed_toggle", "label_speed_offset", "hint_speed",
        "speed_toggle", "speed_hold",
        "box_options", "label_anti_disturbance", "label_sound", "label_resolution",
        "hint_deadzone",

        // Status hints
        "hint_stopped", "hint_opener", "hint_running",

        // Tray
        "status_stopped", "status_running", "status_opener",
        "menu_start", "menu_stop", "menu_opener", "menu_pref", "menu_guide", "menu_quit",
    };

    [Fact]
    public void EveryKeyUsedByTheUiExists()
    {
        var missing = UiKeys.Where(k => !Localization.Table.ContainsKey(k)).ToArray();

        Assert.True(missing.Length == 0,
            $"UI가 참조하지만 사전에 없는 키: {string.Join(", ", missing)}");
    }

    [Fact]
    public void EveryKeyHasBothLanguages()
    {
        var incomplete = Localization.Table
            .Where(p => string.IsNullOrWhiteSpace(p.Value.Ko) || string.IsNullOrWhiteSpace(p.Value.En))
            .Select(p => p.Key)
            .ToArray();

        Assert.True(incomplete.Length == 0,
            $"한쪽 언어만 있는 키: {string.Join(", ", incomplete)}");
    }

    [Fact]
    public void NoEntryHasWhitespacePadding()
    {
        // A leading or trailing space in an XAML Content string is invisible in the table
        // but shows up as a misaligned label.
        var padded = Localization.Table
            .Where(p => p.Value.Ko != p.Value.Ko.Trim() || p.Value.En != p.Value.En.Trim())
            .Select(p => p.Key)
            .ToArray();

        Assert.True(padded.Length == 0, $"앞뒤 공백이 있는 키: {string.Join(", ", padded)}");
    }

    [Fact]
    public void LookupFallsBackToKoreanThenToTheKey()
    {
        var l10n = new Localization();

        l10n.Mode = LanguageMode.Korean;
        var ko = l10n.T("engine_start");
        Assert.NotEmpty(ko);
        Assert.NotEqual("engine_start", ko);

        l10n.Mode = LanguageMode.English;
        var en = l10n.T("engine_start");
        Assert.NotEmpty(en);
        Assert.NotEqual("engine_start", en);

        // An unknown key returns itself, which is what makes the missing-key test above
        // the real safety net.
        Assert.Equal("no_such_key_at_all", l10n.T("no_such_key_at_all"));
        Assert.Equal(string.Empty, l10n.T(string.Empty));
    }

    /// <summary>
    /// Keys whose English text deliberately carries Hangul, because they name the language
    /// options themselves ("Korean", "English"). Showing "Korean (한국어)" in an English UI
    /// helps a bilingual user find the right row; a blanket check would flag these.
    /// </summary>
    private static readonly HashSet<string> BilingualKeys = new(StringComparer.Ordinal)
    {
        "menu_language",
        "menu_lang_auto",
        "menu_lang_ko",
        "menu_lang_en",
    };

    [Fact]
    public void EnglishModeNeverReturnsKoreanForAKnownKey()
    {
        // Unlisted Korean text in the English table is always a translation bug.
        var hangul = new System.Text.RegularExpressions.Regex(@"[\uAC00-\uD7A3]");

        var offenders = Localization.Table
            .Where(p => !BilingualKeys.Contains(p.Key) && hangul.IsMatch(p.Value.En))
            .Select(p => $"{p.Key}='{p.Value.En}'")
            .ToArray();

        Assert.True(offenders.Length == 0,
            $"영문 테이블에 한글이 남아있음: {string.Join(", ", offenders)}");
    }

    [Fact]
    public void BilingualKeysExistAndAreActuallyBilingual()
    {
        // Guards the allow-list above: a key that no longer has Hangul in its English text
        // should be removed from the exemption rather than left to rot.
        var hangul = new System.Text.RegularExpressions.Regex(@"[\uAC00-\uD7A3]");

        foreach (var key in BilingualKeys)
        {
            Assert.True(Localization.Table.ContainsKey(key), $"사전에 없는 키: {key}");
            Assert.True(hangul.IsMatch(Localization.Table[key].En),
                $"{key}의 영문 항목에 한글이 없어 예외 목록에서 제거해야 합니다");
        }
    }

    [Fact]
    public void ClassPresetNamesTranslateToEnglish()
    {
        var l10n = new Localization { Mode = LanguageMode.English };

        Assert.Equal("Warlock (Fiery Scream)", l10n.PresetName("악마술사 (타오르는 비명)"));
        Assert.Equal("Sorcerer (Lightning Spear / Tal Rasha)", l10n.PresetName("원소술사 (번개창)"));
        Assert.Equal("Necromancer (Bone Spear & Corpse Expl.)", l10n.PresetName("강령술사"));
        Assert.Equal("Barbarian (Whirlwind Channeling)", l10n.PresetName("야만용사"));
        Assert.Equal("Rogue (3 Combo Points)", l10n.PresetName("도적"));
        Assert.Equal("Spiritborn (Aspect & Overpower)", l10n.PresetName("혼령사"));
    }

    [Fact]
    public void KoreanModeReturnsPresetNamesUnchanged()
    {
        var l10n = new Localization { Mode = LanguageMode.Korean };
        Assert.Equal("악마술사 (타오르는 비명)", l10n.PresetName("악마술사 (타오르는 비명)"));
    }

    [Fact]
    public void UnknownPresetNameIsReturnedAsIs()
    {
        var l10n = new Localization { Mode = LanguageMode.English };
        Assert.Equal("가변 클래스", l10n.PresetName("가변 클래스"));
        Assert.Equal(string.Empty, l10n.PresetName(string.Empty));
    }
}
