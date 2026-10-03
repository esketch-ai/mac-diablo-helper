using System.Globalization;

namespace DM_Helper.Core.Services;

public enum LanguageMode
{
    Auto = 0,
    Korean = 1,
    English = 2,
}

/// <summary>
/// Korean/English UI strings - a direct port of <c>D3LocalizationManager</c>.
///
/// The 146-entry table below was extracted from the macOS build so both platforms show
/// identical wording. Language switching raises <see cref="LanguageChanged"/>; the UI is
/// expected to rebuild its labels from scratch so no edit is lost.
/// </summary>
public sealed class Localization
{
    private static Localization? _instance;

    public static Localization Instance => _instance ??= new Localization();

    /// <summary>
    /// Public so tests can exercise a specific mode without touching the saved preference.
    /// Production code should go through <see cref="Instance"/>.
    /// </summary>
    public Localization()
    {
        _mode = (LanguageMode)ConfigStore.Prefs.GetInt(PrefKey, (int)LanguageMode.Auto);
    }

    private const string PrefKey = "SelectedLanguageMode";

    private LanguageMode _mode;

    public LanguageMode Mode
    {
        get => _mode;
        set
        {
            if (_mode == value) return;
            _mode = value;
            ConfigStore.Prefs.Set(PrefKey, ((int)value).ToString(CultureInfo.InvariantCulture));
            LanguageChanged?.Invoke(value);
        }
    }

    /// <summary>Raised after <see cref="Mode"/> changes.</summary>
    public static event Action<LanguageMode>? LanguageChanged;

    /// <summary>True when the UI should render in Korean.</summary>
    public bool IsKorean => _mode switch
    {
        LanguageMode.Korean => true,
        LanguageMode.English => false,
        // Auto: follow the Windows display language, defaulting to Korean.
        _ => IsSystemKorean(),
    };

    public string Code => IsKorean ? "ko" : "en";

    private static bool IsSystemKorean()
    {
        try
        {
            var name = CultureInfo.InstalledUICulture.Name;
            if (!string.IsNullOrEmpty(name)) return name.StartsWith("ko", StringComparison.OrdinalIgnoreCase);
        }
        catch (CultureNotFoundException)
        {
        }

        return true;
    }

    /// <summary>Looks up <paramref name="key"/>, falling back to Korean then to the key.</summary>
    public string T(string key)
    {
        if (string.IsNullOrEmpty(key)) return string.Empty;

        var table = IsKorean ? Ko : En;
        if (table.TryGetValue(key, out var value)) return value;

        return Ko.TryGetValue(key, out var fallback) ? fallback : key;
    }

    /// <summary>English name for a Korean class preset label.</summary>
    public string PresetName(string? koName)
    {
        if (string.IsNullOrEmpty(koName)) return string.Empty;
        if (IsKorean) return koName;

        foreach (var pair in PresetTranslations)
        {
            if (koName.Contains(pair.Ko, StringComparison.Ordinal)) return pair.En;
        }

        return koName;
    }

    /// <summary>Class preset label pairs, indexed to match <c>KeyConfig.PresetNames</c>.</summary>
    public static readonly (string Ko, string En)[] PresetTranslations =
    {
        ("기본 헬퍼 (디아3/4 표준)", "Basic Helper (D3/D4 Standard)"),
        ("악마술사", "Warlock (Fiery Scream)"),
        ("원소술사", "Sorcerer (Lightning Spear / Tal Rasha)"),
        ("강령술사", "Necromancer (Bone Spear & Corpse Expl.)"),
        ("야만용사", "Barbarian (Whirlwind Channeling)"),
        ("도적", "Rogue (3 Combo Points)"),
        ("혼령사", "Spiritborn (Aspect & Overpower)"),
    };

    /// <summary>The KO/EN string table.</summary>
    public static readonly IReadOnlyDictionary<string, (string Ko, string En)> Table = new Dictionary<string, (string, string)>
    {
        ["profile_label"] = ("프로필", "Profile"),
        ["preset_popup_default"] = ("직업 프리셋 적용 ▼", "Apply Class Preset ▼"),
        ["engine_start"] = ("▶ 동작 시작", "▶ Start Helper"),
        ["engine_stop"] = ("■ 동작 중지", "■ Stop Helper"),
        ["opener_btn"] = ("⚡️ 준비 시퀀스", "⚡️ Opener"),
        ["opener_btn_tooltip"] = ("설정된 오프너/준비 시퀀스를 지금 1회 즉시 실행합니다.", "Execute configured opener sequence immediately once."),
        ["sheet_hub_btn"] = ("🌐 시트 공유", "🌐 Sheet Hub"),
        ["sheet_hub_tooltip"] = ("구글 시트 프리셋 공유 센터 (유저별/시즌별/빌드별 공유 & 가져오기)", "Google Sheets Preset Hub (Share & Import by User/Season/Build)"),
        ["guide_btn"] = ("📖 가이드", "📖 Guide"),
        ["guide_btn_tooltip"] = ("DM_Helper 전체 사용 설명서 및 직업별 가이드 열기", "Open full DM_Helper user manual and class guides"),
        ["status_stopped"] = ("○ 정지됨", "○ Stopped"),
        ["status_running"] = ("● 동작 중", "● Running"),
        ["status_opener"] = ("⚡️ 준비 중...", "⚡️ Opener..."),
        ["memo_label"] = ("메모", "Memo"),
        ["memo_placeholder"] = ("프로필 메모 (예: 원소술사 번개창, 야만용사 소용돌이, 도적 3콤보)", "Profile memo (e.g., Sorcerer Lightning Spear, Barbarian Whirlwind)"),
        ["a11y_granted"] = ("● 권한 허용됨", "● Authorized"),
        ["a11y_needed"] = ("▲ 권한 필요", "▲ Need Access"),
        ["a11y_btn_settings"] = ("권한 설정", "Settings"),
        ["a11y_btn_retry"] = ("새로고침", "Retry"),
        ["btn_reset_defaults"] = ("기본값", "Reset"),
        ["btn_reset_defaults_tooltip"] = ("현재 프로필을 기본 설정으로 초기화", "Reset current profile to defaults"),
        ["btn_import"] = ("불러오기", "Import"),
        ["btn_export"] = ("저장하기", "Export"),
        ["lang_label"] = ("🌐 언어", "🌐 Language"),
        ["tab_helper"] = ("기본 헬퍼", "Basic Helper"),
        ["tab_rotation"] = ("로테이션 & 준비 시퀀스", "Rotation & Opener"),
        ["tab_features"] = ("단일반복 & 편의기능", "Single Repeat & Utility"),
        ["box_start_stop"] = ("시작 / 종료 & 준비 시퀀스 키", "Start / Stop & Opener Keys"),
        ["label_start_key"] = ("시작 키", "Start Key"),
        ["label_stop_key"] = ("종료 키", "Stop Key"),
        ["label_opener_key"] = ("준비 키", "Opener Key"),
        ["btn_opener_enable"] = ("사용", "Enable"),
        ["btn_opener_enable_tooltip"] = ("준비 시퀀스(오프너) 자동/수동 실행 활성화 여부", "Enable auto/manual execution of opener sequence"),
        ["box_ingame"] = ("종료 키 (인게임 UI 단축키 시 중단)", "Pause Keys (In-Game UI Shortcuts)"),
        ["label_inventory"] = ("소지품 메뉴", "Inventory"),
        ["label_skills"] = ("기술 메뉴", "Skills Menu"),
        ["label_follower"] = ("추종자 메뉴", "Follower"),
        ["label_map"] = ("지도", "Map"),
        ["label_world_map"] = ("세계지도", "World Map"),
        ["label_portal"] = ("차원문", "Town Portal"),
        ["label_chat"] = ("채팅", "Chat"),
        ["label_whisper"] = ("귓속말", "Whisper"),
        ["box_special"] = ("특수키 (누르고 있으면 V 기술 멈춤)", "Special Keys (Pause checked skills while holding)"),
        ["label_special_key"] = ("특수키 %d", "Special %d"),
        ["btn_cooldown_after"] = ("쿨타임 후", "After CD"),
        ["btn_cooldown_after_tooltip"] = ("체크 시 특수키 해제 후 남은 주기 소진 후 발송, 체크 해제 시 즉시 1회 발송", "When checked, remaining cooldown is waited after release; otherwise fires once immediately"),
        ["box_skills"] = ("기술키 (1 ~ 8) - 연타 및 채널링 홀드 설정", "Skill Keys (1 ~ 8) - Spam & Channeling Hold"),
        ["col_skill"] = ("기술", "Skill"),
        ["col_special_v"] = ("특수키V", "Special V"),
        ["col_input_key"] = ("입력 키", "Trigger Key"),
        ["col_mode"] = ("시전 방식", "Cast Mode"),
        ["col_interval"] = ("간격(ms)", "Interval(ms)"),
        ["mode_spam"] = ("연타", "Spam"),
        ["mode_hold"] = ("홀드(누름)", "Hold (Channel)"),
        ["label_skill_row"] = ("기술 %d", "Skill %d"),
        ["unit_ms"] = ("ms", "ms"),
        ["skill_note"] = ("* '홀드'는 헬퍼가 켜진 동안 키를 계속 누르고 있는 채널링 상태를 유지합니다(야만용사 소용돌이 등).\\n* '특수키V'를 풀면 특수키를 누르고 있더라도 해당 기술은 멈추지 않습니다.", "* 'Hold' keeps the key pressed continuously while helper is active (Barbarian Whirlwind, etc.).\\n* Unchecking 'Special V' keeps the skill active even when special keys are held."),
        ["box_opener"] = ("초기 준비 / 스택 시퀀스 (Opener & Ramp-up)", "Opener & Ramp-up Sequence"),
        ["btn_opener_autorun"] = ("시작 시 준비 시퀀스 자동 실행", "Auto-run opener when helper starts"),
        ["label_opener_trigger"] = ("수동 트리거 키:", "Manual Trigger Key:"),
        ["btn_opener_test"] = ("⚡️ 지금 1회 테스트", "⚡️ Test Opener Now"),
        ["col_step"] = ("단계", "Step"),
        ["col_opener_key"] = ("스킬 키", "Skill Key"),
        ["col_opener_delay"] = ("지연 시간", "Delay"),
        ["col_opener_repeat"] = ("반복 횟수", "Repeat"),
        ["col_opener_desc"] = ("스킬 / 스택 설명 (메모)", "Skill / Stack Memo"),
        ["label_step_row"] = ("%d단계", "Step %d"),
        ["opener_repeat_times"] = ("%d회", "%d times"),
        ["opener_desc_placeholder"] = ("예: 얼음 갑옷(보호막), 번개창(소환), 화염탄 평타 스택", "e.g., Ice Armor (Barrier), Lightning Spear, Fire Bolt stack"),
        ["opener_note"] = ("* 원리: 헬퍼를 켤 때(또는 수동 키 입력 시) 사전에 필요한 버프와 스택을 순서대로 쌓은 뒤 자동으로 주 전투 루프로 전환합니다.", "* Concept: Casts necessary buffs and stacks in order upon start, then seamlessly transitions to the main combat loop."),
        ["box_combo"] = ("스킬 연계 콤보 사이클 (Generator -> Spender)", "Skill Combo Cycle (Generator -> Spender)"),
        ["btn_combo_enable"] = ("연계 콤보 사이클 활성화 (도적 콤보 포인트, 자원 생성/소모 빌드)", "Enable Combo Cycle (Rogue Combo Points, Resource Gen/Spend)"),
        ["label_combo_gen"] = ("생성기 스킬 (A):", "Generator Skill (A):"),
        ["label_combo_spend"] = ("핵심 소모기 (B):", "Core Spender (B):"),
        ["label_combo_count"] = ("연타:", "Count:"),
        ["unit_times"] = ("회", "times"),
        ["label_combo_interval"] = ("발동 간격:", "Interval:"),
        ["combo_note"] = ("* 원리: 생성기(평타)를 N회 타격해 스택/자원을 쌓고 소모기(핵심기)를 M회 발동하는 사이클을 자동 반복합니다.\\n* 예: 도적의 경우 기본 기술 3회로 콤보 포인트를 쌓고 핵심 기술 1회로 소모하는 3:1 사이클을 무한 반복합니다.", "* Concept: Automatically alternates between attacking N times with generator to build stacks, and M times with spender.\\n* Example: Rogue repeats a 3:1 cycle of 3 basic puncture hits to build combo points, followed by 1 twisting blades spend."),
        ["box_single"] = ("단일반복키 (누르고 있으면 헬퍼 상태와 상관없이 즉시 반복)", "Single Repeat Keys (Instant repeat while held)"),
        ["col_single_toggle"] = ("토글(홀드) 키", "Hold Key"),
        ["col_single_action"] = ("반복 실행 키", "Action Key"),
        ["col_single_delay"] = ("간격(ms)", "Interval(ms)"),
        ["label_single_row"] = ("반복키 %d", "Repeat %d"),
        ["box_misc"] = ("퀘스트키 & 시간조절키", "Quest Key & Speed Modifier"),
        ["label_quest_key"] = ("퀘스트키 (누르고 있으면 모든 기술 멈춤)", "Quest Key (Pause all skills while held)"),
        ["label_speed_mod_key"] = ("시간조절키", "Speed Modifier Key"),
        ["label_speed_mod_offset"] = ("조절(+/-)", "Adjust (+/-)"),
        ["btn_speed_mod_toggle"] = ("신단 토글", "Pylon Toggle"),
        ["btn_speed_mod_toggle_tooltip"] = ("체크 시 키를 1회 누르면 가속/감속 유지(신단 버프용), 체크 해제 시 누르고 있는 동안만 적용", "When checked, pressing once toggles speed modifier (for pylon buffs); otherwise active only while held"),
        ["box_antidist"] = ("방해금지 모드 및 환경 설정", "Anti-Disturbance & Preferences"),
        ["btn_antidist_enable"] = ("방해금지 모드 활성화 (기술칸 좌클릭 시 게임 UI 클릭 방지)", "Enable Anti-Disturbance (Skip click if cursor is on game UI)"),
        ["btn_sound_feedback"] = ("시작 / 종료 시 효과음 재생 (Tink / Pop)", "Play sound effects on Start / Stop (Tink / Pop)"),
        ["label_resolution"] = ("대상 게임 해상도:", "Game Resolution:"),
        ["antidist_note"] = ("* 원리 및 효과: 기술칸에 마우스 왼쪽키(Mouse Left)를 지정했을 때 마우스 커서가 하단 스킬바, 체력/자원 구슬, 미니맵 영역에 있으면 클릭 매크로가 실행되지 않도록 안전하게 건너뜁니다.", "* Concept: When Mouse Left is assigned to a skill, clicks are safely skipped if the cursor hovers over the bottom skillbar, health/resource orbs, or minimap."),
        ["sheet_win_title"] = ("DM_Helper - 🌐 구글 시트 프리셋 공유 센터 (Google Sheets Hub)", "DM_Helper - 🌐 Google Sheets Preset Hub"),
        ["sheet_header_title"] = ("🌐 구글 시트 프리셋 공유 센터", "🌐 Google Sheets Preset Hub"),
        ["sheet_header_sub"] = ("유저별 · 시즌별 · 직업/빌드별 공인 및 유저 커뮤니티 세팅을 원클릭으로 공유하고 가져오기", "Share and import official & community builds by user, season, and class in one click"),
        ["btn_open_web"] = ("🌐 시트 웹 열기", "🌐 Open Sheet"),
        ["btn_sheet_settings"] = ("⚙️ 시트 설정", "⚙️ Sheet Settings"),
        ["filter_season_all"] = ("시즌: 전체", "Season: All"),
        ["filter_class_all"] = ("직업: 전체", "Class: All"),
        ["search_placeholder"] = ("작성자, 빌드명, 설명 키워드 검색...", "Search author, build, description..."),
        ["btn_refresh"] = ("🔄 새로고침", "🔄 Refresh"),
        ["col_season"] = ("시즌", "Season"),
        ["col_class"] = ("직업", "Class"),
        ["col_build"] = ("빌드명", "Build Name"),
        ["col_author"] = ("작성자", "Author"),
        ["col_opener"] = ("오프너", "Opener"),
        ["col_upvotes"] = ("추천도", "Rating"),
        ["label_target_slot"] = ("적용할 프로필 슬롯:", "Target Profile Slot:"),
        ["slot_format"] = ("슬롯 %ld", "Slot %ld"),
        ["btn_import_helper"] = ("📥 내 헬퍼로 가져오기 (적용)", "📥 Import to Helper (Apply)"),
        ["btn_share_preset"] = ("📤 현재 내 설정 시트에 공유...", "📤 Share My Preset to Sheet..."),
        ["btn_copy_tsv"] = ("📋 시트 행 복사", "📋 Copy Row Data"),
        ["btn_copy_tsv_tooltip"] = ("구글 시트에 직접 붙여넣기(Cmd+V) 가능한 TSV 행 복사", "Copy TSV row data to paste directly (Cmd+V) into Google Sheets"),
        ["sheet_status_ready"] = ("준비 완료 (%lu개 프리셋)", "Ready (%lu presets)"),
        ["sheet_status_loading"] = ("구글 시트에서 최신 프리셋 동기화 중...", "Syncing latest presets from Google Sheets..."),
        ["sheet_status_copied"] = ("클립보드에 TSV 행 데이터가 복사되었습니다! 구글 시트에서 Cmd+V 하세요.", "TSV row data copied to clipboard! Paste with Cmd+V into Google Sheets."),
        ["sheet_status_imported"] = ("프로필 %ld에 '%@' 빌드가 성공적으로 적용되었습니다!", "Build '%@' successfully loaded into Profile %ld!"),
        ["guide_win_title"] = ("DM_Helper - 사용 설명서 & 직업별 가이드", "DM_Helper - User Manual & Class Guides"),
        ["guide_header_title"] = ("DM_Helper 완벽 가이드 & 사용 설명서", "DM_Helper Complete Guide & Manual"),
        ["guide_header_sub"] = ("디아블로 3 & 4 macOS 초정밀 네이티브 게이밍 헬퍼 (v1.5)", "Diablo 3 & 4 macOS Precision Native Gaming Helper (v1.5)"),
        ["guide_tab_0"] = ("⚡️ 3분 퀵스타트", "⚡️ 3-Min Quick Start"),
        ["guide_tab_1"] = ("🎮 D4 직업별 프리셋", "🎮 D4 Class Presets"),
        ["guide_tab_2"] = ("🔄 오프너 & 콤보", "🔄 Opener & Combo"),
        ["guide_tab_3"] = ("💎 편의기능", "💎 Utility Features"),
        ["guide_tab_4"] = ("🛡 보안 & 문제해결", "🛡 Security & FAQ"),
        ["btn_open_manual_md"] = ("📄 전체 매뉴얼 (MANUAL.md) 열기", "📄 Open Full Manual (MANUAL.md)"),
        ["btn_close"] = ("닫기", "Close"),
        ["menu_about"] = ("DM_Helper에 관하여", "About DM_Helper"),
        ["menu_start"] = ("동작 시작", "Start Helper"),
        ["menu_stop"] = ("동작 중지", "Stop Helper"),
        ["menu_opener"] = ("준비 시퀀스 실행", "Execute Opener"),
        ["menu_sheet"] = ("구글 시트 프리셋 허브", "Google Sheets Preset Hub"),
        ["menu_guide"] = ("사용 설명서 (가이드)", "User Guide & Manual"),
        ["menu_pref"] = ("설정 창 열기", "Open Main Window"),
        ["menu_language"] = ("🌐 언어 (Language)", "🌐 Language / 언어"),
        ["menu_lang_auto"] = ("시스템 기본 (System Default)", "System Default (시스템 기본)"),
        ["menu_lang_ko"] = ("한국어 (Korean)", "한국어 (Korean)"),
        ["menu_lang_en"] = ("English (영어)", "English (영어)"),
        ["menu_quit"] = ("종료 (Quit)", "Quit DM_Helper"),
        ["ctx_clear_key"] = ("설정 해제 (없음)", "Clear (None)"),
        ["alert_import_success"] = ("설정 파일을 성공적으로 불러왔습니다.", "Profile settings imported successfully."),
        ["alert_export_success"] = ("설정이 성공적으로 저장되었습니다.", "Profile settings exported successfully."),
        ["alert_error"] = ("오류", "Error"),
        ["alert_confirm"] = ("확인", "OK"),

        // ---- Windows-only entries.
        // The macOS dictionary has no equivalent for these: it carried them as hardcoded
        // AppKit strings, and the Windows layout surfaces a few labels it did not need.
        // Authored here so the table stays the single source of truth for UI copy.
        ["box_options"] = ("편의기능", "Quality of life"),
        ["box_single_repeat"] = ("단일반복키 (독립 반복)", "Single-repeat keys"),
        ["hint_deadzone"] = ("커서가 스킬바나 미니맵 위에 있을 때 좌클릭 기술 발송을 막습니다.", "Suppresses a left-click skill when the cursor sits over the action bar or minimap."),
        ["hint_quest"] = ("NPC 대화 중 누르고 있으면 모든 스킬이 멈춥니다.", "Holding it during dialogue pauses every skill."),
        ["hint_speed"] = ("신단 획득 시 누르면 전체 주기가 조절됩니다. 음수는 빠르게, 양수는 느리게.", "Press after a time gift to shift the whole rotation. Negative is faster, positive is slower."),
        ["hint_start_stop"] = ("시작/종료 키를 같게 두면 토글로 동작합니다. 창이 활성화된 상태에서는 키가 전송되지 않습니다.", "Sharing one key for start and stop makes it a toggle. No keys are sent while this app has focus."),
        ["hint_stopped"] = ("게임을 창 활성화한 뒤 시작 키를 누르세요.", "Bring the game to the foreground and press the start key."),
        ["hint_opener"] = ("준비 시퀀스를 실행하고 있습니다.", "Running the opener sequence."),
        ["hint_running"] = ("동작 중입니다. 종료 키 또는 시작 키를 다시 누르세요.", "Running. Press the stop key again to halt."),
        ["label_anti_disturbance"] = ("방해금지 데드존", "Anti-disturbance deadzone"),
        ["label_sound"] = ("시작/종료 효과음", "Start/stop sound"),
        ["label_speed_key"] = ("시간조절키", "Speed modifier"),
        ["label_speed_offset"] = ("주기 보정(ms)", "Interval offset (ms)"),
        ["label_speed_toggle"] = ("토글 모드 (신단 버프용)", "Toggle mode (time gift)"),
        ["speed_toggle"] = ("토글", "Toggle"),
        ["speed_hold"] = ("홀드", "Hold"),
    };

    private static readonly Dictionary<string, string> Ko = Table.ToDictionary(
        p => p.Key, p => p.Value.Ko, StringComparer.Ordinal);

    private static readonly Dictionary<string, string> En = Table.ToDictionary(
        p => p.Key, p => p.Value.En, StringComparer.Ordinal);
}
