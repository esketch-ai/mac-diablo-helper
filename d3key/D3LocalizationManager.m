//
//  D3LocalizationManager.m
//  DM_Helper
//
//  Created by sunghyuk on 2026. 9. 30.
//  Copyright © 2026 sunghyuk. All rights reserved.
//

#import "D3LocalizationManager.h"

NSString * const kD3LanguageChangedNotification = @"kD3LanguageChangedNotification";
NSString * const kD3SelectedLanguageKey = @"kD3SelectedLanguageKey";

@interface D3LocalizationManager ()
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *translations;
@end

@implementation D3LocalizationManager

+ (instancetype)sharedManager {
    static D3LocalizationManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[D3LocalizationManager alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self initTranslations];
        
        // Load saved language preference
        NSInteger savedMode = [[NSUserDefaults standardUserDefaults] integerForKey:kD3SelectedLanguageKey];
        _languageMode = (D3LanguageMode)savedMode;
    }
    return self;
}

- (void)setLanguageMode:(D3LanguageMode)languageMode {
    if (_languageMode != languageMode) {
        _languageMode = languageMode;
        [[NSUserDefaults standardUserDefaults] setInteger:languageMode forKey:kD3SelectedLanguageKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kD3LanguageChangedNotification object:nil];
    }
}

- (BOOL)isKorean {
    if (_languageMode == D3LanguageModeKorean) {
        return YES;
    } else if (_languageMode == D3LanguageModeEnglish) {
        return NO;
    } else {
        // System preference
        NSArray *langs = [NSLocale preferredLanguages];
        if (langs.count > 0) {
            NSString *first = langs[0];
            return [first hasPrefix:@"ko"];
        }
        return YES; // Default fallback to Korean
    }
}

- (NSString *)currentLanguageCode {
    return self.isKorean ? @"ko" : @"en";
}

- (NSString *)localizedStringForKey:(NSString *)key {
    return [self localizedStringForKey:key default:nil];
}

- (NSString *)localizedStringForKey:(NSString *)key default:(NSString *)defaultVal {
    if (!key) return defaultVal ?: @"";
    
    NSString *code = self.currentLanguageCode;
    NSDictionary *dict = _translations[code];
    NSString *val = dict[key];
    if (val) return val;
    
    // Fallback to Korean, then defaultVal, then key
    NSString *fallback = _translations[@"ko"][key];
    if (fallback) return fallback;
    
    return defaultVal ?: key;
}

- (NSString *)localizedPresetName:(NSString *)presetName {
    if (!presetName) return @"";
    if (self.isKorean) return presetName;
    
    // English mapping for standard Diablo 4 presets
    if ([presetName containsString:@"악마술사"]) {
        return @"Warlock (Fiery Scream)";
    } else if ([presetName containsString:@"원소술사"]) {
        return @"Sorcerer (Lightning Spear / Tal Rasha)";
    } else if ([presetName containsString:@"야만용사"]) {
        return @"Barbarian (Whirlwind Channeling)";
    } else if ([presetName containsString:@"도적"]) {
        return @"Rogue (3 Combo Points)";
    } else if ([presetName containsString:@"강령술사"]) {
        return @"Necromancer (Bone Spear & Corpse Expl.)";
    } else if ([presetName containsString:@"혼령사"]) {
        return @"Spiritborn (Aspect & Overpower)";
    }
    return presetName;
}

- (void)initTranslations {
    NSDictionary *ko = @{
        // Top Bar
        @"profile_label": @"프로필",
        @"preset_popup_default": @"직업 프리셋 적용 ▼",
        @"engine_start": @"▶ 동작 시작",
        @"engine_stop": @"■ 동작 중지",
        @"opener_btn": @"⚡️ 준비 시퀀스",
        @"opener_btn_tooltip": @"설정된 오프너/준비 시퀀스를 지금 1회 즉시 실행합니다.",
        @"sheet_hub_btn": @"🌐 시트 공유",
        @"sheet_hub_tooltip": @"구글 시트 프리셋 공유 센터 (유저별/시즌별/빌드별 공유 & 가져오기)",
        @"guide_btn": @"📖 가이드",
        @"guide_btn_tooltip": @"DM_Helper 전체 사용 설명서 및 직업별 가이드 열기",
        @"status_stopped": @"○ 정지됨",
        @"status_running": @"● 동작 중",
        @"status_opener": @"⚡️ 준비 중...",
        @"memo_label": @"메모",
        @"memo_placeholder": @"프로필 메모 (예: 원소술사 번개창, 야만용사 소용돌이, 도적 3콤보)",
        @"a11y_granted": @"● 권한 허용됨",
        @"a11y_needed": @"▲ 권한 필요",
        @"a11y_btn_settings": @"권한 설정",
        @"a11y_btn_retry": @"새로고침",
        @"btn_reset_defaults": @"기본값",
        @"btn_reset_defaults_tooltip": @"현재 프로필을 기본 설정으로 초기화",
        @"btn_import": @"불러오기",
        @"btn_export": @"저장하기",
        @"lang_label": @"🌐 언어",
        
        // Tabs
        @"tab_helper": @"기본 헬퍼",
        @"tab_rotation": @"로테이션 & 준비 시퀀스",
        @"tab_features": @"단일반복 & 편의기능",
        
        // Tab 1: Basic Helper
        @"box_start_stop": @"시작 / 종료 & 준비 시퀀스 키",
        @"label_start_key": @"시작 키",
        @"label_stop_key": @"종료 키",
        @"label_opener_key": @"준비 키",
        @"btn_opener_enable": @"사용",
        @"btn_opener_enable_tooltip": @"준비 시퀀스(오프너) 자동/수동 실행 활성화 여부",
        @"box_ingame": @"종료 키 (인게임 UI 단축키 시 중단)",
        @"label_inventory": @"소지품 메뉴",
        @"label_skills": @"기술 메뉴",
        @"label_follower": @"추종자 메뉴",
        @"label_map": @"지도",
        @"label_world_map": @"세계지도",
        @"label_portal": @"차원문",
        @"label_chat": @"채팅",
        @"label_whisper": @"귓속말",
        @"box_special": @"특수키 (누르고 있으면 V 기술 멈춤)",
        @"label_special_key": @"특수키 %d",
        @"btn_cooldown_after": @"쿨타임 후",
        @"btn_cooldown_after_tooltip": @"체크 시 특수키 해제 후 남은 주기 소진 후 발송, 체크 해제 시 즉시 1회 발송",
        @"box_skills": @"기술키 (1 ~ 8) - 연타 및 채널링 홀드 설정",
        @"col_skill": @"기술",
        @"col_special_v": @"특수키V",
        @"col_input_key": @"입력 키",
        @"col_mode": @"시전 방식",
        @"col_interval": @"간격(ms)",
        @"mode_spam": @"연타",
        @"mode_hold": @"홀드(누름)",
        @"label_skill_row": @"기술 %d",
        @"unit_ms": @"ms",
        @"skill_note": @"* '홀드'는 헬퍼가 켜진 동안 키를 계속 누르고 있는 채널링 상태를 유지합니다(야만용사 소용돌이 등).\n* '특수키V'를 풀면 특수키를 누르고 있더라도 해당 기술은 멈추지 않습니다.",
        
        // Tab 2: Rotation & Opener
        @"box_opener": @"초기 준비 / 스택 시퀀스 (Opener & Ramp-up)",
        @"btn_opener_autorun": @"시작 시 준비 시퀀스 자동 실행",
        @"label_opener_trigger": @"수동 트리거 키:",
        @"btn_opener_test": @"⚡️ 지금 1회 테스트",
        @"col_step": @"단계",
        @"col_opener_key": @"스킬 키",
        @"col_opener_delay": @"지연 시간",
        @"col_opener_repeat": @"반복 횟수",
        @"col_opener_desc": @"스킬 / 스택 설명 (메모)",
        @"label_step_row": @"%d단계",
        @"opener_repeat_times": @"%d회",
        @"opener_desc_placeholder": @"예: 얼음 갑옷(보호막), 번개창(소환), 화염탄 평타 스택",
        @"opener_note": @"* 원리: 헬퍼를 켤 때(또는 수동 키 입력 시) 사전에 필요한 버프와 스택을 순서대로 쌓은 뒤 자동으로 주 전투 루프로 전환합니다.",
        @"box_combo": @"스킬 연계 콤보 사이클 (Generator -> Spender)",
        @"btn_combo_enable": @"연계 콤보 사이클 활성화 (도적 콤보 포인트, 자원 생성/소모 빌드)",
        @"label_combo_gen": @"생성기 스킬 (A):",
        @"label_combo_spend": @"핵심 소모기 (B):",
        @"label_combo_count": @"연타:",
        @"unit_times": @"회",
        @"label_combo_interval": @"발동 간격:",
        @"combo_note": @"* 원리: 생성기(평타)를 N회 타격해 스택/자원을 쌓고 소모기(핵심기)를 M회 발동하는 사이클을 자동 반복합니다.\n* 예: 도적의 경우 기본 기술 3회로 콤보 포인트를 쌓고 핵심 기술 1회로 소모하는 3:1 사이클을 무한 반복합니다.",
        
        // Tab 3: Single Repeat & Utility
        @"box_single": @"단일반복키 (누르고 있으면 헬퍼 상태와 상관없이 즉시 반복)",
        @"col_single_toggle": @"토글(홀드) 키",
        @"col_single_action": @"반복 실행 키",
        @"col_single_delay": @"간격(ms)",
        @"label_single_row": @"반복키 %d",
        @"box_misc": @"퀘스트키 & 시간조절키",
        @"label_quest_key": @"퀘스트키 (누르고 있으면 모든 기술 멈춤)",
        @"label_speed_mod_key": @"시간조절키",
        @"label_speed_mod_offset": @"조절(+/-)",
        @"btn_speed_mod_toggle": @"신단 토글",
        @"btn_speed_mod_toggle_tooltip": @"체크 시 키를 1회 누르면 가속/감속 유지(신단 버프용), 체크 해제 시 누르고 있는 동안만 적용",
        @"box_antidist": @"방해금지 모드 및 환경 설정",
        @"btn_antidist_enable": @"방해금지 모드 활성화 (기술칸 좌클릭 시 게임 UI 클릭 방지)",
        @"btn_sound_feedback": @"시작 / 종료 시 효과음 재생 (Tink / Pop)",
        @"label_resolution": @"대상 게임 해상도:",
        @"antidist_note": @"* 원리 및 효과: 기술칸에 마우스 왼쪽키(Mouse Left)를 지정했을 때 마우스 커서가 하단 스킬바, 체력/자원 구슬, 미니맵 영역에 있으면 클릭 매크로가 실행되지 않도록 안전하게 건너뜁니다.",
        
        // Google Sheet Hub Window
        @"sheet_win_title": @"DM_Helper - 🌐 구글 시트 프리셋 공유 센터 (Google Sheets Hub)",
        @"sheet_header_title": @"🌐 구글 시트 프리셋 공유 센터",
        @"sheet_header_sub": @"유저별 · 시즌별 · 직업/빌드별 공인 및 유저 커뮤니티 세팅을 원클릭으로 공유하고 가져오기",
        @"btn_open_web": @"🌐 시트 웹 열기",
        @"btn_sheet_settings": @"⚙️ 시트 설정",
        @"filter_season_all": @"시즌: 전체",
        @"filter_class_all": @"직업: 전체",
        @"search_placeholder": @"작성자, 빌드명, 설명 키워드 검색...",
        @"btn_refresh": @"🔄 새로고침",
        @"col_season": @"시즌",
        @"col_class": @"직업",
        @"col_build": @"빌드명",
        @"col_author": @"작성자",
        @"col_opener": @"오프너",
        @"col_upvotes": @"추천도",
        @"label_target_slot": @"적용할 프로필 슬롯:",
        @"slot_format": @"슬롯 %ld",
        @"btn_import_helper": @"📥 내 헬퍼로 가져오기 (적용)",
        @"btn_share_preset": @"📤 현재 내 설정 시트에 공유...",
        @"btn_copy_tsv": @"📋 시트 행 복사",
        @"btn_copy_tsv_tooltip": @"구글 시트에 직접 붙여넣기(Cmd+V) 가능한 TSV 행 복사",
        @"sheet_status_ready": @"준비 완료 (%lu개 프리셋)",
        @"sheet_status_loading": @"구글 시트에서 최신 프리셋 동기화 중...",
        @"sheet_status_copied": @"클립보드에 TSV 행 데이터가 복사되었습니다! 구글 시트에서 Cmd+V 하세요.",
        @"sheet_status_imported": @"프로필 %ld에 '%@' 빌드가 성공적으로 적용되었습니다!",
        
        // Guide Window
        @"guide_win_title": @"DM_Helper - 사용 설명서 & 직업별 가이드",
        @"guide_header_title": @"DM_Helper 완벽 가이드 & 사용 설명서",
        @"guide_header_sub": @"디아블로 3 & 4 macOS 초정밀 네이티브 게이밍 헬퍼 (v1.5)",
        @"guide_tab_0": @"⚡️ 3분 퀵스타트",
        @"guide_tab_1": @"🎮 D4 직업별 프리셋",
        @"guide_tab_2": @"🔄 오프너 & 콤보",
        @"guide_tab_3": @"💎 편의기능",
        @"guide_tab_4": @"🛡 보안 & 문제해결",
        @"btn_open_manual_md": @"📄 전체 매뉴얼 (MANUAL.md) 열기",
        @"btn_close": @"닫기",
        
        // Menu Bar & Context Menus
        @"menu_about": @"DM_Helper에 관하여",
        @"menu_start": @"동작 시작",
        @"menu_stop": @"동작 중지",
        @"menu_opener": @"준비 시퀀스 실행",
        @"menu_sheet": @"구글 시트 프리셋 허브",
        @"menu_guide": @"사용 설명서 (가이드)",
        @"menu_pref": @"설정 창 열기",
        @"menu_language": @"🌐 언어 (Language)",
        @"menu_lang_auto": @"시스템 기본 (System Default)",
        @"menu_lang_ko": @"한국어 (Korean)",
        @"menu_lang_en": @"English (영어)",
        @"menu_quit": @"종료 (Quit)",
        @"ctx_clear_key": @"설정 해제 (없음)",
        
        // Dialogs & Alerts
        @"alert_import_success": @"설정 파일을 성공적으로 불러왔습니다.",
        @"alert_export_success": @"설정이 성공적으로 저장되었습니다.",
        @"alert_error": @"오류",
        @"alert_confirm": @"확인",
        @"alert_cancel": @"취소"
    };
    
    NSDictionary *en = @{
        // Top Bar
        @"profile_label": @"Profile",
        @"preset_popup_default": @"Apply Class Preset ▼",
        @"engine_start": @"▶ Start Helper",
        @"engine_stop": @"■ Stop Helper",
        @"opener_btn": @"⚡️ Opener",
        @"opener_btn_tooltip": @"Execute configured opener sequence immediately once.",
        @"sheet_hub_btn": @"🌐 Sheet Hub",
        @"sheet_hub_tooltip": @"Google Sheets Preset Hub (Share & Import by User/Season/Build)",
        @"guide_btn": @"📖 Guide",
        @"guide_btn_tooltip": @"Open full DM_Helper user manual and class guides",
        @"status_stopped": @"○ Stopped",
        @"status_running": @"● Running",
        @"status_opener": @"⚡️ Opener...",
        @"memo_label": @"Memo",
        @"memo_placeholder": @"Profile memo (e.g., Sorcerer Lightning Spear, Barbarian Whirlwind)",
        @"a11y_granted": @"● Authorized",
        @"a11y_needed": @"▲ Need Access",
        @"a11y_btn_settings": @"Settings",
        @"a11y_btn_retry": @"Retry",
        @"btn_reset_defaults": @"Reset",
        @"btn_reset_defaults_tooltip": @"Reset current profile to defaults",
        @"btn_import": @"Import",
        @"btn_export": @"Export",
        @"lang_label": @"🌐 Language",
        
        // Tabs
        @"tab_helper": @"Basic Helper",
        @"tab_rotation": @"Rotation & Opener",
        @"tab_features": @"Single Repeat & Utility",
        
        // Tab 1: Basic Helper
        @"box_start_stop": @"Start / Stop & Opener Keys",
        @"label_start_key": @"Start Key",
        @"label_stop_key": @"Stop Key",
        @"label_opener_key": @"Opener Key",
        @"btn_opener_enable": @"Enable",
        @"btn_opener_enable_tooltip": @"Enable auto/manual execution of opener sequence",
        @"box_ingame": @"Pause Keys (In-Game UI Shortcuts)",
        @"label_inventory": @"Inventory",
        @"label_skills": @"Skills Menu",
        @"label_follower": @"Follower",
        @"label_map": @"Map",
        @"label_world_map": @"World Map",
        @"label_portal": @"Town Portal",
        @"label_chat": @"Chat",
        @"label_whisper": @"Whisper",
        @"box_special": @"Special Keys (Pause checked skills while holding)",
        @"label_special_key": @"Special %d",
        @"btn_cooldown_after": @"After CD",
        @"btn_cooldown_after_tooltip": @"When checked, remaining cooldown is waited after release; otherwise fires once immediately",
        @"box_skills": @"Skill Keys (1 ~ 8) - Spam & Channeling Hold",
        @"col_skill": @"Skill",
        @"col_special_v": @"Special V",
        @"col_input_key": @"Trigger Key",
        @"col_mode": @"Cast Mode",
        @"col_interval": @"Interval(ms)",
        @"mode_spam": @"Spam",
        @"mode_hold": @"Hold (Channel)",
        @"label_skill_row": @"Skill %d",
        @"unit_ms": @"ms",
        @"skill_note": @"* 'Hold' keeps the key pressed continuously while helper is active (Barbarian Whirlwind, etc.).\n* Unchecking 'Special V' keeps the skill active even when special keys are held.",
        
        // Tab 2: Rotation & Opener
        @"box_opener": @"Opener & Ramp-up Sequence",
        @"btn_opener_autorun": @"Auto-run opener when helper starts",
        @"label_opener_trigger": @"Manual Trigger Key:",
        @"btn_opener_test": @"⚡️ Test Opener Now",
        @"col_step": @"Step",
        @"col_opener_key": @"Skill Key",
        @"col_opener_delay": @"Delay",
        @"col_opener_repeat": @"Repeat",
        @"col_opener_desc": @"Skill / Stack Memo",
        @"label_step_row": @"Step %d",
        @"opener_repeat_times": @"%d times",
        @"opener_desc_placeholder": @"e.g., Ice Armor (Barrier), Lightning Spear, Fire Bolt stack",
        @"opener_note": @"* Concept: Casts necessary buffs and stacks in order upon start, then seamlessly transitions to the main combat loop.",
        @"box_combo": @"Skill Combo Cycle (Generator -> Spender)",
        @"btn_combo_enable": @"Enable Combo Cycle (Rogue Combo Points, Resource Gen/Spend)",
        @"label_combo_gen": @"Generator Skill (A):",
        @"label_combo_spend": @"Core Spender (B):",
        @"label_combo_count": @"Count:",
        @"unit_times": @"times",
        @"label_combo_interval": @"Interval:",
        @"combo_note": @"* Concept: Automatically alternates between attacking N times with generator to build stacks, and M times with spender.\n* Example: Rogue repeats a 3:1 cycle of 3 basic puncture hits to build combo points, followed by 1 twisting blades spend.",
        
        // Tab 3: Single Repeat & Utility
        @"box_single": @"Single Repeat Keys (Instant repeat while held)",
        @"col_single_toggle": @"Hold Key",
        @"col_single_action": @"Action Key",
        @"col_single_delay": @"Interval(ms)",
        @"label_single_row": @"Repeat %d",
        @"box_misc": @"Quest Key & Speed Modifier",
        @"label_quest_key": @"Quest Key (Pause all skills while held)",
        @"label_speed_mod_key": @"Speed Modifier Key",
        @"label_speed_mod_offset": @"Adjust (+/-)",
        @"btn_speed_mod_toggle": @"Pylon Toggle",
        @"btn_speed_mod_toggle_tooltip": @"When checked, pressing once toggles speed modifier (for pylon buffs); otherwise active only while held",
        @"box_antidist": @"Anti-Disturbance & Preferences",
        @"btn_antidist_enable": @"Enable Anti-Disturbance (Skip click if cursor is on game UI)",
        @"btn_sound_feedback": @"Play sound effects on Start / Stop (Tink / Pop)",
        @"label_resolution": @"Game Resolution:",
        @"antidist_note": @"* Concept: When Mouse Left is assigned to a skill, clicks are safely skipped if the cursor hovers over the bottom skillbar, health/resource orbs, or minimap.",
        
        // Google Sheet Hub Window
        @"sheet_win_title": @"DM_Helper - 🌐 Google Sheets Preset Hub",
        @"sheet_header_title": @"🌐 Google Sheets Preset Hub",
        @"sheet_header_sub": @"Share and import official & community builds by user, season, and class in one click",
        @"btn_open_web": @"🌐 Open Sheet",
        @"btn_sheet_settings": @"⚙️ Sheet Settings",
        @"filter_season_all": @"Season: All",
        @"filter_class_all": @"Class: All",
        @"search_placeholder": @"Search author, build, description...",
        @"btn_refresh": @"🔄 Refresh",
        @"col_season": @"Season",
        @"col_class": @"Class",
        @"col_build": @"Build Name",
        @"col_author": @"Author",
        @"col_opener": @"Opener",
        @"col_upvotes": @"Rating",
        @"label_target_slot": @"Target Profile Slot:",
        @"slot_format": @"Slot %ld",
        @"btn_import_helper": @"📥 Import to Helper (Apply)",
        @"btn_share_preset": @"📤 Share My Preset to Sheet...",
        @"btn_copy_tsv": @"📋 Copy Row Data",
        @"btn_copy_tsv_tooltip": @"Copy TSV row data to paste directly (Cmd+V) into Google Sheets",
        @"sheet_status_ready": @"Ready (%lu presets)",
        @"sheet_status_loading": @"Syncing latest presets from Google Sheets...",
        @"sheet_status_copied": @"TSV row data copied to clipboard! Paste with Cmd+V into Google Sheets.",
        @"sheet_status_imported": @"Build '%@' successfully loaded into Profile %ld!",
        
        // Guide Window
        @"guide_win_title": @"DM_Helper - User Manual & Class Guides",
        @"guide_header_title": @"DM_Helper Complete Guide & Manual",
        @"guide_header_sub": @"Diablo 3 & 4 macOS Precision Native Gaming Helper (v1.5)",
        @"guide_tab_0": @"⚡️ 3-Min Quick Start",
        @"guide_tab_1": @"🎮 D4 Class Presets",
        @"guide_tab_2": @"🔄 Opener & Combo",
        @"guide_tab_3": @"💎 Utility Features",
        @"guide_tab_4": @"🛡 Security & FAQ",
        @"btn_open_manual_md": @"📄 Open Full Manual (MANUAL.md)",
        @"btn_close": @"Close",
        
        // Menu Bar & Context Menus
        @"menu_about": @"About DM_Helper",
        @"menu_start": @"Start Helper",
        @"menu_stop": @"Stop Helper",
        @"menu_opener": @"Execute Opener",
        @"menu_sheet": @"Google Sheets Preset Hub",
        @"menu_guide": @"User Guide & Manual",
        @"menu_pref": @"Open Main Window",
        @"menu_language": @"🌐 Language / 언어",
        @"menu_lang_auto": @"System Default (시스템 기본)",
        @"menu_lang_ko": @"한국어 (Korean)",
        @"menu_lang_en": @"English (영어)",
        @"menu_quit": @"Quit DM_Helper",
        @"ctx_clear_key": @"Clear (None)",
        
        // Dialogs & Alerts
        @"alert_import_success": @"Profile settings imported successfully.",
        @"alert_export_success": @"Profile settings exported successfully.",
        @"alert_error": @"Error",
        @"alert_confirm": @"OK",
        @"alert_cancel": @"Cancel"
    };
    
    _translations = @{
        @"ko": ko,
        @"en": en
    };
}

@end
