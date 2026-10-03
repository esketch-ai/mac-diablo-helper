using System.Text.Json;
using DM_Helper.Core.Interop;

namespace DM_Helper.Core.Models;

/// <summary>
/// The complete macro profile. Mirrors <c>D3KeyConfig</c> from the macOS build field for
/// field, including the JSON key names, so profiles round-trip between the two platforms.
/// </summary>
public sealed class KeyConfig
{
    public string Memo { get; set; } = "";

    // ---- 1. Start / stop ----
    public InputKey StartInputKey { get; set; } = InputKey.Empty;
    public InputKey StopInputKey { get; set; } = InputKey.Empty;

    // ---- 2. In-game keys that pause the helper ----
    public InputKey InventoryKey { get; set; } = InputKey.Empty;
    public InputKey SkillsMenuKey { get; set; } = InputKey.Empty;
    public InputKey FollowerKey { get; set; } = InputKey.Empty;
    public InputKey MapKey { get; set; } = InputKey.Empty;
    public InputKey WorldMapKey { get; set; } = InputKey.Empty;
    public InputKey PortalKey { get; set; } = InputKey.Empty;
    public InputKey ChatKey { get; set; } = InputKey.Empty;
    public InputKey WhisperKey { get; set; } = InputKey.Empty;

    // ---- 3. Skill slots 1-8 ----
    public InputKey[] SkillKeys { get; set; } = CreateSlots();
    public int[] SkillDelays { get; set; } = new int[8];
    public bool[] SkillChecks { get; set; } = CreateAll(true);
    public bool[] SkillHolds { get; set; } = CreateAll(false);

    // ---- 4. Special keys 1-3 ----
    public InputKey[] SpecialKeys { get; set; } = CreateSlots(3);
    public bool[] SpecialKeyCooldowns { get; set; } = CreateAll(false, 3);

    // ---- 5. Single-repeat keys 1-3 ----
    public InputKey[] SingleRepeatToggles { get; set; } = CreateSlots(3);
    public InputKey[] SingleRepeatActions { get; set; } = CreateSlots(3);
    public int[] SingleRepeatDelays { get; set; } = new int[3];

    // ---- 6. Quest key & speed modifier ----
    public InputKey QuestKey { get; set; } = InputKey.Empty;
    public InputKey SpeedModKey { get; set; } = InputKey.Empty;
    public int SpeedModOffset { get; set; }
    public bool SpeedModToggleMode { get; set; }

    // ---- 7. Feedback / quality of life ----
    public bool SoundFeedbackEnabled { get; set; }
    public bool AntiDisturbanceEnabled { get; set; } = true;
    public string SelectedResolution { get; set; } = DeadzoneFilterOptions.AutoDetect;

    // ---- 8. Opener & ramp-up ----
    public bool OpenerEnabled { get; set; }
    public InputKey OpenerTriggerKey { get; set; } = InputKey.Empty;
    public OpenerStep[] OpenerSteps { get; set; } = CreateOpenerSteps();

    // ---- 9. Generator-to-spender combo cycle ----
    public bool ComboEnabled { get; set; }
    public InputKey ComboGeneratorKey { get; set; } = InputKey.Empty;
    public int ComboGeneratorCount { get; set; } = 3;
    public InputKey ComboSpenderKey { get; set; } = InputKey.Empty;
    public int ComboSpenderCount { get; set; } = 1;
    public int ComboInterval { get; set; } = 150;

    private static InputKey[] CreateSlots(int count = 8)
    {
        var a = new InputKey[count];
        for (var i = 0; i < count; i++) a[i] = InputKey.Empty;
        return a;
    }

    private static bool[] CreateAll(bool value, int count = 8)
    {
        var a = new bool[count];
        Array.Fill(a, value);
        return a;
    }

    private static OpenerStep[] CreateOpenerSteps()
    {
        var a = new OpenerStep[5];
        for (var i = 0; i < a.Length; i++) a[i] = OpenerStep.Default;
        return a;
    }

    // =====================================================================
    // Indexed accessors (0-based in C#, 1-based in ObjC)
    // =====================================================================

    public InputKey SkillKey(int index0) => Slot(SkillKeys, index0);
    public int SkillDelay(int index0) => Slot(SkillDelays, index0);
    public bool SkillCheck(int index0) => Slot(SkillChecks, index0);
    public bool SkillHold(int index0) => Slot(SkillHolds, index0);
    public InputKey SpecialKey(int index0) => Slot(SpecialKeys, index0);
    public bool SpecialKeyCooldown(int index0) => Slot(SpecialKeyCooldowns, index0);
    public InputKey SingleRepeatToggle(int index0) => Slot(SingleRepeatToggles, index0);
    public InputKey SingleRepeatAction(int index0) => Slot(SingleRepeatActions, index0);
    public int SingleRepeatDelay(int index0) => Slot(SingleRepeatDelays, index0);
    public OpenerStep OpenerStepAt(int index0) => Slot(OpenerSteps, index0);

    private static T Slot<T>(T[] arr, int index0) =>
        index0 >= 0 && index0 < arr.Length ? arr[index0] : default!;

    // =====================================================================
    // Matching
    // =====================================================================

    public bool IsStartKey(InputKey key)
    {
        if (key.IsEmpty) return false;
        // Left click as start key would fire on every combat click.
        if (key.Type == InputType.MouseButton && key.MouseButton == MouseButton.Left) return false;
        return !StartInputKey.IsEmpty && StartInputKey == key;
    }

    public bool IsStopKey(InputKey key)
    {
        if (key.IsEmpty) return false;
        if (key.Type == InputType.MouseButton && key.MouseButton == MouseButton.Left) return false;

        if (!StopInputKey.IsEmpty && StopInputKey == key) return true;

        // When no explicit stop key is set, fall back to '[' - matching the macOS build.
        if (StopInputKey.IsEmpty && key.Type == InputType.Keyboard && key.Key == Vk.Oem4) return true;

        foreach (var k in InGameKeys)
            if (!k.IsEmpty && k == key) return true;

        return false;
    }

    private IEnumerable<InputKey> InGameKeys
    {
        get
        {
            yield return InventoryKey;
            yield return SkillsMenuKey;
            yield return FollowerKey;
            yield return MapKey;
            yield return WorldMapKey;
            yield return PortalKey;
            yield return ChatKey;
            yield return WhisperKey;
        }
    }

    // =====================================================================
    // Sanitize - mirrors -sanitize, with macOS key codes swapped for Windows ones
    // =====================================================================

    public void Sanitize()
    {
        StartInputKey = SanitizeShortcut(StartInputKey, InputKey.FromKey(Vk.Oem4));
        StopInputKey = SanitizeShortcut(StopInputKey, InputKey.FromKey(Vk.Oem4));

        // Opener and single-repeat toggles clear to empty when unsafe - unlike the start
        // key, having no binding at all is a valid state for them.
        if (IsForbiddenShortcut(OpenerTriggerKey)) OpenerTriggerKey = InputKey.Empty;

        for (var i = 0; i < SingleRepeatToggles.Length; i++)
            if (IsForbiddenShortcut(SingleRepeatToggles[i])) SingleRepeatToggles[i] = InputKey.Empty;

        // A single-repeat *action* is commonly a left click (the loot-macro default), so
        // left mouse must stay legal here - only reserved modifier keys are rejected.
        for (var i = 0; i < SingleRepeatActions.Length; i++)
            if (IsReservedModifierKey(SingleRepeatActions[i])) SingleRepeatActions[i] = InputKey.Empty;

        // Guarantee at least 5 opener stages.
        while (OpenerSteps.Length < 5)
        {
            var grown = new OpenerStep[5];
            Array.Copy(OpenerSteps, grown, OpenerSteps.Length);
            for (var i = OpenerSteps.Length; i < 5; i++) grown[i] = OpenerStep.Default;
            OpenerSteps = grown;
        }

        if (ComboGeneratorCount == 0) ComboGeneratorCount = 3;
        if (ComboSpenderCount == 0) ComboSpenderCount = 1;
        if (ComboInterval == 0) ComboInterval = 150;
    }

    /// <summary>
    /// Start and stop fall back to '[' when unset or unsafe. An empty start key would
    /// leave the helper with no way to begin, so it must never survive sanitizing.
    /// </summary>
    private static InputKey SanitizeShortcut(InputKey key, InputKey fallback) =>
        key.IsEmpty || IsForbiddenShortcut(key) ? fallback : key;

    /// <summary>True when the binding is unusable as a toggle/hotkey.</summary>
    private static bool IsForbiddenShortcut(InputKey key)
    {
        if (key.IsEmpty) return false;
        if (key.Type == InputType.MouseButton && key.MouseButton == MouseButton.Left) return true;
        return IsReservedModifierKey(key);
    }

    /// <summary>True for keys that must never be bound, regardless of their role.</summary>
    private static bool IsReservedModifierKey(InputKey key) =>
        !key.IsEmpty && key.Type == InputType.Keyboard && key.Key.IsForbiddenAsShortcut();

    // =====================================================================
    // Serialization - byte-compatible with the macOS JSON layout
    // =====================================================================

    public Dictionary<string, object?> ToDictionary()
    {
        var d = new Dictionary<string, object?>
        {
            ["memo"] = Memo ?? "",
            ["startInputKey"] = StartInputKey.ToDictionary(),
            ["stopInputKey"] = StopInputKey.ToDictionary(),
            ["inventoryKey"] = InventoryKey.ToDictionary(),
            ["skillsMenuKey"] = SkillsMenuKey.ToDictionary(),
            ["followerKey"] = FollowerKey.ToDictionary(),
            ["mapKey"] = MapKey.ToDictionary(),
            ["worldMapKey"] = WorldMapKey.ToDictionary(),
            ["portalKey"] = PortalKey.ToDictionary(),
            ["chatKey"] = ChatKey.ToDictionary(),
            ["whisperKey"] = WhisperKey.ToDictionary(),
        };

        for (var i = 0; i < 8; i++)
        {
            var n = i + 1;
            d[$"skillKey{n}"] = SkillKey(i).ToDictionary();
            d[$"skillDelay{n}"] = SkillDelay(i);
            d[$"skillCheck{n}"] = SkillCheck(i);
            d[$"skillHold{n}"] = SkillHold(i);
        }

        for (var i = 0; i < 3; i++)
        {
            var n = i + 1;
            d[$"specialKey{n}"] = SpecialKey(i).ToDictionary();
            d[$"specialCooldown{n}"] = SpecialKeyCooldown(i);
            d[$"singleToggle{n}"] = SingleRepeatToggle(i).ToDictionary();
            d[$"singleAction{n}"] = SingleRepeatAction(i).ToDictionary();
            d[$"singleDelay{n}"] = SingleRepeatDelay(i);
        }

        d["questKey"] = QuestKey.ToDictionary();
        d["speedModKey"] = SpeedModKey.ToDictionary();
        d["speedModOffset"] = SpeedModOffset;
        d["speedModToggleMode"] = SpeedModToggleMode;
        d["soundFeedbackEnabled"] = SoundFeedbackEnabled;
        d["antiDisturbanceEnabled"] = AntiDisturbanceEnabled;
        d["selectedResolution"] = SelectedResolution ?? DeadzoneFilterOptions.AutoDetect;

        d["openerEnabled"] = OpenerEnabled;
        d["openerTriggerKey"] = OpenerTriggerKey.ToDictionary();
        d["openerSteps"] = OpenerSteps.Select(s => s.ToDictionary()).ToList();

        d["comboEnabled"] = ComboEnabled;
        d["comboGeneratorKey"] = ComboGeneratorKey.ToDictionary();
        d["comboGeneratorCount"] = ComboGeneratorCount;
        d["comboSpenderKey"] = ComboSpenderKey.ToDictionary();
        d["comboSpenderCount"] = ComboSpenderCount;
        d["comboInterval"] = ComboInterval;

        return d;
    }

    public static KeyConfig FromDictionary(JsonElement root)
    {
        var c = new KeyConfig();
        if (root.ValueKind != JsonValueKind.Object) return DefaultConfig();

        InputKey Key(string name) => root.TryGetProperty(name, out var e)
            ? InputKey.FromDictionary(JsonObjectHelper.Flatten(e))
            : InputKey.Empty;

        c.Memo = Str(root, "memo") ?? "";
        c.StartInputKey = Key("startInputKey");
        c.StopInputKey = Key("stopInputKey");
        c.InventoryKey = Key("inventoryKey");
        c.SkillsMenuKey = Key("skillsMenuKey");
        c.FollowerKey = Key("followerKey");
        c.MapKey = Key("mapKey");
        c.WorldMapKey = Key("worldMapKey");
        c.PortalKey = Key("portalKey");
        c.ChatKey = Key("chatKey");
        c.WhisperKey = Key("whisperKey");

        for (var i = 0; i < 8; i++)
        {
            var n = i + 1;
            c.SkillKeys[i] = Key($"skillKey{n}");
            c.SkillDelays[i] = Int(root, $"skillDelay{n}");
            c.SkillChecks[i] = Bool(root, $"skillCheck{n}", true);
            c.SkillHolds[i] = Bool(root, $"skillHold{n}");
        }

        for (var i = 0; i < 3; i++)
        {
            var n = i + 1;
            c.SpecialKeys[i] = Key($"specialKey{n}");
            c.SpecialKeyCooldowns[i] = Bool(root, $"specialCooldown{n}");
            c.SingleRepeatToggles[i] = Key($"singleToggle{n}");
            c.SingleRepeatActions[i] = Key($"singleAction{n}");
            c.SingleRepeatDelays[i] = Int(root, $"singleDelay{n}");
        }

        c.QuestKey = Key("questKey");
        c.SpeedModKey = Key("speedModKey");
        c.SpeedModOffset = Int(root, "speedModOffset");
        c.SpeedModToggleMode = Bool(root, "speedModToggleMode");
        c.SoundFeedbackEnabled = Bool(root, "soundFeedbackEnabled");
        c.AntiDisturbanceEnabled = Bool(root, "antiDisturbanceEnabled", true);
        c.SelectedResolution = Str(root, "selectedResolution") ?? DeadzoneFilterOptions.AutoDetect;

        c.OpenerEnabled = Bool(root, "openerEnabled");
        c.OpenerTriggerKey = Key("openerTriggerKey");
        if (root.TryGetProperty("openerSteps", out var steps) && steps.ValueKind == JsonValueKind.Array)
        {
            var parsed = steps.EnumerateArray().Select(OpenerStep.FromDictionary).ToArray();
            if (parsed.Length > 0) c.OpenerSteps = parsed;
        }

        c.ComboEnabled = Bool(root, "comboEnabled");
        c.ComboGeneratorKey = Key("comboGeneratorKey");
        c.ComboGeneratorCount = Int(root, "comboGeneratorCount", 3);
        c.ComboSpenderKey = Key("comboSpenderKey");
        c.ComboSpenderCount = Int(root, "comboSpenderCount", 1);
        c.ComboInterval = Int(root, "comboInterval", 150);

        c.Sanitize();
        return c;
    }

    private static string? Str(JsonElement root, string name) =>
        root.TryGetProperty(name, out var e) && e.ValueKind == JsonValueKind.String ? e.GetString() : null;

    private static int Int(JsonElement root, string name, int fallback = 0) =>
        root.TryGetProperty(name, out var e) && e.ValueKind == JsonValueKind.Number ? e.GetInt32() : fallback;

    private static bool Bool(JsonElement root, string name, bool fallback = false) =>
        root.TryGetProperty(name, out var e) && e.ValueKind is JsonValueKind.True or JsonValueKind.False
            ? e.GetBoolean()
            : fallback;

    // =====================================================================
    // Defaults & presets
    // =====================================================================

    public const string AutoResolution = DeadzoneFilterOptions.AutoDetect;

    public static KeyConfig DefaultConfig()
    {
        var c = new KeyConfig
        {
            Memo = "기본 설정",
            StartInputKey = InputKey.FromKey(Vk.Oem4),   // [
            StopInputKey = InputKey.FromKey(Vk.Oem4),    // [

            // D4-friendly defaults. WASD / interaction / skill keys stay unbound so the
            // macro never fights the player for movement or abilities.
            InventoryKey = InputKey.FromKey(Vk.I),
            SkillsMenuKey = InputKey.Empty,
            FollowerKey = InputKey.Empty,
            MapKey = InputKey.FromKey(Vk.M),
            WorldMapKey = InputKey.Empty,
            PortalKey = InputKey.FromKey(Vk.T),
            ChatKey = InputKey.FromKey(Vk.Enter),
            WhisperKey = InputKey.Empty,

            // Grave = loot, Tab = gambling, per the DHelper reference behaviour.
            SingleRepeatToggles = new[]
            {
                InputKey.FromKey(Vk.Oem3), InputKey.FromKey(Vk.Tab), InputKey.Empty,
            },
            SingleRepeatActions = new[]
            {
                InputKey.FromMouse(MouseButton.Left), InputKey.FromMouse(MouseButton.Right), InputKey.Empty,
            },
            SingleRepeatDelays = new[] { 50, 60, 0 },

            SpeedModToggleMode = true,
            SoundFeedbackEnabled = true,
        };

        // Skill slots: 1-4 at 1000ms.
        for (var i = 0; i < 4; i++)
        {
            c.SkillKeys[i] = InputKey.FromKey((Vk)((int)Vk.D0 + i + 1));
            c.SkillDelays[i] = 1000;
            c.SkillChecks[i] = true;
        }

        c.Sanitize();
        return c;
    }

    public static readonly (string Ko, string En)[] PresetNames =
    {
        ("기본 헬퍼 (디아3/4 표준)", "Basic Helper (D3/D4 Standard)"),
        ("악마술사 (타오르는 비명 & 탈태 오프너)", "Warlock (Blazing Scream & Metamorphosis Opener)"),
        ("원소술사 (보호막 & 번개창/탈라샤)", "Sorcerer (Barrier & Teleport/Shatter)"),
        ("강령술사 (골렘/저주 & 시폭/뼈창)", "Necromancer (Golem/Curse & Bone Storm)"),
        ("야만용사 (3함성 & 소용돌이 홀드)", "Barbarian (3 Ancients & Whirlwind Hold)"),
        ("도적 (3콤보 포인트 연타)", "Rogue (3-Point Combo Spam)"),
        ("혼령사 (태세 버프 & 제압 사이클)", "Spiritborn (Boon Buff & Suppression Cycle)"),
    };

    public enum PresetKind
    {
        Standard,
        Warlock,
        Sorcerer,
        Necromancer,
        Barbarian,
        Rogue,
        Spiritborn,
    }

    public static KeyConfig ForPreset(PresetKind kind)
    {
        var c = DefaultConfig();
        c.OpenerTriggerKey = InputKey.FromKey(Vk.F1);

        var k1 = InputKey.FromKey(Vk.D1);
        var k2 = InputKey.FromKey(Vk.D2);
        var k3 = InputKey.FromKey(Vk.D3);
        var k4 = InputKey.FromKey(Vk.D4);
        var rmb = InputKey.FromMouse(MouseButton.Right);

        void SetOpener(params OpenerStep[] steps)
        {
            for (var i = 0; i < steps.Length && i < 5; i++) c.OpenerSteps[i] = steps[i];
        }

        void SetSkill(int slot0, InputKey key, int delay)
        {
            c.SkillKeys[slot0] = key;
            c.SkillDelays[slot0] = delay;
            c.SkillChecks[slot0] = true;
        }

        switch (kind)
        {
            case PresetKind.Warlock:
                c.Memo = "[악마술사] 타오르는 비명(Blazing Scream) & 탈태/인장 오프너 & 화염 폭딜";
                c.OpenerEnabled = true;
                SetOpener(
                    OpenerStep.Create(k4, 150, 1, "아보디안 지배 (시너지 소환)"),
                    OpenerStep.Create(k3, 150, 1, "탈태 (악마 형상/지배력 확보)"),
                    OpenerStep.Create(k2, 150, 1, "어둠의 감옥 (군중 제어/디버프)"),
                    OpenerStep.Create(k1, 120, 1, "인장 기술 (이동/화염 버프)"));
                SetSkill(0, k1, 5000);
                SetSkill(1, k2, 3000);
                SetSkill(2, k3, 6000);
                SetSkill(3, k4, 1500);
                SetSkill(4, rmb, 120); // Blazing Scream, the primary damage button
                break;

            case PresetKind.Sorcerer:
                c.Memo = "[원소술사] 4원소 탈라샤/구현 스택 오프너 & 번개창/연쇄번개";
                c.OpenerEnabled = true;
                SetOpener(
                    OpenerStep.Create(k1, 120, 1, "얼음 갑옷 (보호막)"),
                    OpenerStep.Create(k2, 150, 1, "순간이동 (진입)"),
                    OpenerStep.Create(k3, 200, 1, "번개창 (구현 소환)"),
                    OpenerStep.Create(k4, 150, 3, "화염탄 (4원소 스택 누적)"));
                SetSkill(0, k1, 6000);
                SetSkill(1, k2, 4000);
                SetSkill(2, k3, 2500);
                SetSkill(3, k4, 250);
                SetSkill(4, rmb, 150);
                break;

            case PresetKind.Necromancer:
                c.Memo = "[강령술사] 골렘/저주/촉수 오프너 & 시폭/뼈창 폭딜";
                c.OpenerEnabled = true;
                SetOpener(
                    OpenerStep.Create(k4, 150, 1, "골렘 활성화 (지속 방어막)"),
                    OpenerStep.Create(k3, 150, 1, "노화 저주 (사망 폭발)"),
                    OpenerStep.Create(k2, 150, 1, "사체 촉수 (군중 제어)"));
                SetSkill(0, k1, 5000);
                SetSkill(1, k2, 3000);
                SetSkill(2, k3, 4000);
                SetSkill(3, k4, 200);
                SetSkill(4, rmb, 200);
                break;

            case PresetKind.Barbarian:
                c.Memo = "[야만용사] 3함성 분노 폭발 & 소용돌이 지속 회전(홀드)";
                c.OpenerEnabled = true;
                SetOpener(
                    OpenerStep.Create(k4, 150, 1, "집결의 함성 (분노 생성)"),
                    OpenerStep.Create(k3, 150, 1, "전장의 함성 (피해 증가)"),
                    OpenerStep.Create(k2, 150, 1, "도전의 함성 (에너자 지속)"));
                SetSkill(0, k1, 30000);
                SetSkill(1, k2, 30000);
                SetSkill(2, k3, 30000);
                SetSkill(3, k4, 30000);
                // Channel: hold right mouse instead of spamming it.
                c.SkillKeys[4] = rmb;
                c.SkillDelays[4] = 0;
                c.SkillHolds[4] = true;
                break;

            case PresetKind.Rogue:
                c.Memo = "[도적] 3연계 점수(구멍 뚫기 3회) → 회전 칼날 1회 교대";
                c.OpenerEnabled = true;
                SetOpener(
                    OpenerStep.Create(k4, 150, 1, "암흑 주입 (은신 진입)"),
                    OpenerStep.Create(k3, 150, 1, "그림자 걸음 (회피 이동)"));
                SetSkill(0, k1, 2500);
                SetSkill(1, k2, 2500);
                SetSkill(2, k3, 2500);
                SetSkill(3, k4, 4000);
                // 3:1 generator-to-spender rotation.
                c.ComboEnabled = true;
                c.ComboGeneratorKey = k1;
                c.ComboGeneratorCount = 3;
                c.ComboSpenderKey = rmb;
                c.ComboSpenderCount = 1;
                c.ComboInterval = 150;
                break;

            case PresetKind.Spiritborn:
                c.Memo = "[혼령사] 태세 버프 & 결의 스택 제압 사이클";
                c.OpenerEnabled = true;
                SetOpener(
                    OpenerStep.Create(k4, 150, 1, "태세 (신속 버프)"),
                    OpenerStep.Create(k3, 150, 1, "결의 축적 (공격 스택)"));
                SetSkill(0, k1, 8000);
                SetSkill(1, k2, 3000);
                SetSkill(2, k3, 4000);
                SetSkill(3, k4, 6000);
                SetSkill(4, rmb, 200);
                break;

            case PresetKind.Standard:
            default:
                return DefaultConfig();
        }

        c.Sanitize();
        return c;
    }
}

/// <summary>Resolution presets for the anti-disturbance deadzone filter.</summary>
public static class DeadzoneFilterOptions
{
    public const string AutoDetect = "자동 감지 (현재 디스플레이)";

    public static readonly (string Label, int Width, int Height)[] Options =
    {
        (AutoDetect, 0, 0),
        ("1920 x 1080 (FHD)", 1920, 1080),
        ("2560 x 1440 (QHD)", 2560, 1440),
        ("3440 x 1440 (UltraWide)", 3440, 1440),
        ("3840 x 2160 (4K UHD)", 3840, 2160),
        ("2560 x 1600 (노트북 16:10)", 2560, 1600),
        ("1920 x 1200 (노트북 16:10)", 1920, 1200),
    };

    public static (int Width, int Height)? Resolve(string? label)
    {
        foreach (var o in Options)
        {
            if (o.Label == label)
                return o.Width == 0 ? null : (o.Width, o.Height);
        }
        return null;
    }
}
