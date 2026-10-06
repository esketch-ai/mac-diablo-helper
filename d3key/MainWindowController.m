//
//  MainWindowController.m
//  d3key
//
//  Created by sunghyuk-imac on 2016. 3. 2..
//  Updated for Diablo 4 Class Helper Evolution.
//

#import "MainWindowController.h"
#import <Carbon/Carbon.h>
#import "D3EventTapService.h"
#import "D3KeyConfigService.h"
#import "D3HelperEngine.h"
#import "D3KeyTextField.h"
#import "D3DeadzoneFilter.h"
#import "D3LocalizationManager.h"
#import "const.h"

@interface MainWindowController ()
{
    NSSegmentedControl *_configIdSegment;
    NSPopUpButton *_presetPopUp;
    NSButton *_engineToggleBtn;
    NSButton *_openerRunBtn;
    NSButton *_cloudPresetBtn;
    NSTextField *_engineStatusLabel;
    NSTextField *_accessibilityStatusLabel;
    NSButton *_openSettingsBtn;
    NSButton *_retryA11yBtn;
    NSButton *_resetDefaultsBtn;
    NSTextField *_memoField;
    
    // 탭 1: 기본 헬퍼
    // 시작 / 종료 & 준비 시퀀스 키
    D3KeyTextField *_startKeyField;
    D3KeyTextField *_stopKeyField;
    D3KeyTextField *_mainOpenerTriggerKeyField;
    NSButton *_mainOpenerCheckBtn;
    
    // 인게임 종료 키 (8개)
    D3KeyTextField *_inventoryKeyField;
    D3KeyTextField *_skillsMenuKeyField;
    D3KeyTextField *_followerKeyField;
    D3KeyTextField *_mapKeyField;
    D3KeyTextField *_worldMapKeyField;
    D3KeyTextField *_portalKeyField;
    D3KeyTextField *_chatKeyField;
    D3KeyTextField *_whisperKeyField;
    
    // 기술키 8개 슬롯 (V 체크, 키, 시전 모드: 연타/홀드, 딜레이)
    NSButton *_skillCheckButtons[8];
    D3KeyTextField *_skillKeyFields[8];
    NSPopUpButton *_skillModePopUps[8];
    NSTextField *_skillDelayFields[8];
    
    // 특수키 3개
    D3KeyTextField *_specialKeyFields[3];
    NSButton *_specialKeyCheckButtons[3];
    
    // 탭 2: 디아4 오프너 & 콤보 연계
    NSButton *_openerCheckBtn;
    D3KeyTextField *_openerTriggerKeyField;
    NSButton *_openerTestBtn;
    
    D3KeyTextField *_openerKeyFields[5];
    NSTextField *_openerDelayFields[5];
    NSPopUpButton *_openerRepeatPopUps[5];
    NSTextField *_openerDescFields[5];
    
    NSButton *_comboCheckBtn;
    D3KeyTextField *_comboGenKeyField;
    NSTextField *_comboGenCountField;
    D3KeyTextField *_comboSpendKeyField;
    NSTextField *_comboSpendCountField;
    NSTextField *_comboIntervalField;
    
    // 탭 3: 단일반복키 3개 & 편의기능
    D3KeyTextField *_singleToggleFields[3];
    D3KeyTextField *_singleActionFields[3];
    NSTextField *_singleDelayFields[3];
    
    D3KeyTextField *_questKeyField;
    D3KeyTextField *_speedModKeyField;
    NSTextField *_speedModOffsetField;
    NSButton *_speedModToggleBtn;
    
    NSButton *_antiDisturbanceButton;
    NSButton *_soundFeedbackBtn;
    NSPopUpButton *_resolutionPopUp;
    
    // 도움말 및 가이드 윈도우
    NSButton *_helpBtn;
    NSWindow *_helpWindow;
    NSSegmentedControl *_helpCategorySegment;
    NSTextView *_helpTextView;
    
    BOOL _isUpdatingUI;
}

- (void)loadConfig:(NSString *)configId;
- (void)setFieldValues:(D3KeyConfig *)config;
- (D3KeyConfig *)getFieldValues;
- (void)save;

@end

static const NSUInteger kOpenerRepeatOptions[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30};
static const NSUInteger kOpenerRepeatOptionsCount = sizeof(kOpenerRepeatOptions) / sizeof(kOpenerRepeatOptions[0]);

static NSInteger openerIndexForRepeatCount(NSUInteger repeatCount) {
    NSInteger closestIndex = 0;
    NSInteger minDiff = NSIntegerMax;
    for (NSUInteger i = 0; i < kOpenerRepeatOptionsCount; i++) {
        if (kOpenerRepeatOptions[i] == repeatCount) {
            return (NSInteger)i;
        }
        NSInteger diff = labs((NSInteger)kOpenerRepeatOptions[i] - (NSInteger)repeatCount);
        if (diff < minDiff) {
            minDiff = diff;
            closestIndex = (NSInteger)i;
        }
    }
    return closestIndex;
}

static NSUInteger openerRepeatCountForIndex(NSInteger index) {
    if (index >= 0 && (NSUInteger)index < kOpenerRepeatOptionsCount) {
        return kOpenerRepeatOptions[index];
    }
    return 1;
}

@implementation MainWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.window.title = @"DM_Helper";
    self.window.styleMask |= NSWindowStyleMaskMiniaturizable;
    [self.window setContentSize:NSMakeSize(900, 710)];
    self.window.minSize = NSMakeSize(900, 710);
    [self.window center];
    
    [D3HelperEngine sharedEngine].delegate = self;
    
    [self buildDHelperUI];
    
    [self loadConfig:@"1"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateAccessibilityStatusUI) name:kD3AccessibilityStatusChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controlTextDidChange:) name:NSControlTextDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(engineStateChangedNotification:) name:kD3EngineStateChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(engineOpenerNotification:) name:@"kD3EngineOpenerStateChangedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languageDidChangeNotification:) name:kD3LanguageChangedNotification object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(systemThemeChanged:) name:@"AppleInterfaceThemeChangedNotification" object:nil];
    
    [self updateAccessibilityStatusUI];
    [self updateEngineUIState:[[D3HelperEngine sharedEngine] isRunning]];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark UI Construction (3 Tabs + Preset Bar)

- (void)buildDHelperUI {
    NSView *root = self.window.contentView;
    [root.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    // -------------------------------------------------------------
    // 1. Top Bar: Preset Segments, Class Presets PopUp, Start/Stop, Status, Language
    // -------------------------------------------------------------
    NSTextField *presetLabel = [self labelWithText:D3Loc(@"profile_label") frame:NSMakeRect(16, 670, 36, 20) bold:YES];
    [root addSubview:presetLabel];
    
    _configIdSegment = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(54, 668, 126, 25)];
    _configIdSegment.segmentCount = 5;
    for (int i = 0; i < 5; i++) {
        [_configIdSegment setLabel:[NSString stringWithFormat:@"%d", i + 1] forSegment:i];
        [_configIdSegment setWidth:23 forSegment:i];
    }
    _configIdSegment.selectedSegment = 0;
    _configIdSegment.target = self;
    _configIdSegment.action = @selector(selectConfigIdSegemnt:);
    [root addSubview:_configIdSegment];
    
    // 원터치 직업 프리셋 적용 드롭다운
    _presetPopUp = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(184, 667, 156, 26) pullsDown:NO];
    [_presetPopUp addItemWithTitle:D3Loc(@"preset_popup_default")];
    for (NSString *name in [D3KeyConfig availablePresetNames]) {
        [_presetPopUp addItemWithTitle:[[D3LocalizationManager sharedManager] localizedPresetName:name]];
    }
    _presetPopUp.target = self;
    _presetPopUp.action = @selector(presetSelected:);
    [root addSubview:_presetPopUp];
    
    // 동작 시작 / 중지 버튼
    _engineToggleBtn = [[NSButton alloc] initWithFrame:NSMakeRect(344, 666, 94, 28)];
    _engineToggleBtn.title = D3Loc(@"engine_start");
    _engineToggleBtn.bezelStyle = NSBezelStyleRounded;
    _engineToggleBtn.font = [NSFont boldSystemFontOfSize:12];
    _engineToggleBtn.target = self;
    _engineToggleBtn.action = @selector(toggleEngineAction:);
    [root addSubview:_engineToggleBtn];
    
    // 준비 시퀀스 수동 실행 버튼
    _openerRunBtn = [[NSButton alloc] initWithFrame:NSMakeRect(442, 666, 90, 28)];
    _openerRunBtn.title = D3Loc(@"opener_btn");
    _openerRunBtn.bezelStyle = NSBezelStyleRounded;
    _openerRunBtn.font = [NSFont systemFontOfSize:12];
    _openerRunBtn.toolTip = D3Loc(@"opener_btn_tooltip");
    _openerRunBtn.target = self;
    _openerRunBtn.action = @selector(runOpenerTest:);
    [root addSubview:_openerRunBtn];
    
    // 구글 시트 프리셋 공유 센터 버튼
    _cloudPresetBtn = [[NSButton alloc] initWithFrame:NSMakeRect(536, 666, 88, 28)];
    _cloudPresetBtn.title = D3Loc(@"sheet_hub_btn");
    _cloudPresetBtn.bezelStyle = NSBezelStyleRounded;
    _cloudPresetBtn.font = [NSFont boldSystemFontOfSize:12];
    _cloudPresetBtn.toolTip = D3Loc(@"sheet_hub_tooltip");
    _cloudPresetBtn.target = self;
    _cloudPresetBtn.action = @selector(showPresetShareWindow:);
    [root addSubview:_cloudPresetBtn];
    
    // 도움말 & 가이드 버튼
    _helpBtn = [[NSButton alloc] initWithFrame:NSMakeRect(628, 666, 75, 28)];
    _helpBtn.title = D3Loc(@"guide_btn");
    _helpBtn.bezelStyle = NSBezelStyleRounded;
    _helpBtn.font = [NSFont systemFontOfSize:12];
    _helpBtn.toolTip = D3Loc(@"guide_btn_tooltip");
    _helpBtn.target = self;
    _helpBtn.action = @selector(showHelpWindow:);
    [root addSubview:_helpBtn];
    
    // 언어 선택 팝업 (한국어 / English / Auto)
    NSPopUpButton *langPopUp = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(707, 667, 86, 26) pullsDown:NO];
    [langPopUp addItemWithTitle:@"🌐 KO"];
    [langPopUp addItemWithTitle:@"🌐 EN"];
    [langPopUp addItemWithTitle:@"🌐 Auto"];
    D3LanguageMode curMode = [D3LocalizationManager sharedManager].languageMode;
    if (curMode == D3LanguageModeKorean) {
        [langPopUp selectItemAtIndex:0];
    } else if (curMode == D3LanguageModeEnglish) {
        [langPopUp selectItemAtIndex:1];
    } else {
        [langPopUp selectItemAtIndex:2];
    }
    langPopUp.target = self;
    langPopUp.action = @selector(languageSelectedAction:);
    [root addSubview:langPopUp];
    
    // 동작 상태 뱃지
    _engineStatusLabel = [self labelWithText:D3Loc(@"status_stopped") frame:NSMakeRect(798, 670, 95, 20) bold:YES];
    _engineStatusLabel.textColor = [NSColor secondaryLabelColor];
    [root addSubview:_engineStatusLabel];
    
    // -------------------------------------------------------------
    // Row 2: 메모 필드 및 시스템 상태/도구
    // -------------------------------------------------------------
    NSTextField *memoLabel = [self labelWithText:D3Loc(@"memo_label") frame:NSMakeRect(20, 637, 35, 20) bold:NO];
    [root addSubview:memoLabel];
    
    _memoField = [[NSTextField alloc] initWithFrame:NSMakeRect(65, 636, 440, 22)];
    _memoField.delegate = self;
    _memoField.placeholderString = D3Loc(@"memo_placeholder");
    [root addSubview:_memoField];
    
    _accessibilityStatusLabel = [self labelWithText:@"" frame:NSMakeRect(515, 637, 110, 20) bold:YES];
    [root addSubview:_accessibilityStatusLabel];
    
    _openSettingsBtn = [[NSButton alloc] initWithFrame:NSMakeRect(630, 635, 75, 24)];
    _openSettingsBtn.title = D3Loc(@"a11y_btn_settings");
    _openSettingsBtn.bezelStyle = NSBezelStyleRounded;
    _openSettingsBtn.target = self;
    _openSettingsBtn.action = @selector(openAccessibilitySettings:);
    [root addSubview:_openSettingsBtn];
    
    _retryA11yBtn = [[NSButton alloc] initWithFrame:NSMakeRect(710, 635, 65, 24)];
    _retryA11yBtn.title = D3Loc(@"a11y_btn_retry");
    _retryA11yBtn.bezelStyle = NSBezelStyleRounded;
    _retryA11yBtn.target = self;
    _retryA11yBtn.action = @selector(retryAccessibility:);
    [root addSubview:_retryA11yBtn];
    
    _resetDefaultsBtn = [[NSButton alloc] initWithFrame:NSMakeRect(630, 635, 75, 24)];
    _resetDefaultsBtn.title = D3Loc(@"btn_reset_defaults");
    _resetDefaultsBtn.bezelStyle = NSBezelStyleRounded;
    _resetDefaultsBtn.toolTip = D3Loc(@"btn_reset_defaults_tooltip");
    _resetDefaultsBtn.target = self;
    _resetDefaultsBtn.action = @selector(resetToDefaultsAction:);
    [root addSubview:_resetDefaultsBtn];
    
    NSButton *importBtn = [[NSButton alloc] initWithFrame:NSMakeRect(710, 635, 75, 24)];
    importBtn.title = D3Loc(@"btn_import");
    importBtn.bezelStyle = NSBezelStyleRounded;
    importBtn.target = self;
    importBtn.action = @selector(importConfigFile:);
    [root addSubview:importBtn];
    
    NSButton *exportBtn = [[NSButton alloc] initWithFrame:NSMakeRect(790, 635, 75, 24)];
    exportBtn.title = D3Loc(@"btn_export");
    exportBtn.bezelStyle = NSBezelStyleRounded;
    exportBtn.target = self;
    exportBtn.action = @selector(exportConfigFile:);
    [root addSubview:exportBtn];
    
    // -------------------------------------------------------------
    // 2. 3-Tab View: [기본 헬퍼] & [로테이션 & 준비 시퀀스] & [단일반복 & 편의]
    // -------------------------------------------------------------
    NSTabView *tabView = [[NSTabView alloc] initWithFrame:NSMakeRect(15, 10, 870, 615)];
    
    // =============================================================
    // TAB 1: 기본 헬퍼
    // =============================================================
    NSTabViewItem *helperTab = [[NSTabViewItem alloc] initWithIdentifier:@"helperTab"];
    helperTab.label = D3Loc(@"tab_helper");
    NSView *helperView = [[NSView alloc] initWithFrame:tabView.contentRect];
    helperTab.view = helperView;
    
    CGFloat leftX = 10;
    CGFloat leftW = 350;
    
    // [시작 / 종료 & 준비 시퀀스 키] 그룹박스
    NSBox *startStopBox = [[NSBox alloc] initWithFrame:NSMakeRect(leftX, 435, leftW, 130)];
    startStopBox.title = D3Loc(@"box_start_stop");
    [helperView addSubview:startStopBox];
    
    [startStopBox.contentView addSubview:[self labelWithText:D3Loc(@"label_start_key") frame:NSMakeRect(15, 75, 65, 20) bold:NO]];
    _startKeyField = [[D3KeyTextField alloc] initWithFrame:NSMakeRect(85, 73, 235, 24)];
    _startKeyField.alignment = NSTextAlignmentCenter;
    _startKeyField.allowMouseLeft = NO;
    _startKeyField.delegate = self;
    [startStopBox.contentView addSubview:_startKeyField];
    
    [startStopBox.contentView addSubview:[self labelWithText:D3Loc(@"label_stop_key") frame:NSMakeRect(15, 44, 65, 20) bold:NO]];
    _stopKeyField = [[D3KeyTextField alloc] initWithFrame:NSMakeRect(85, 42, 235, 24)];
    _stopKeyField.alignment = NSTextAlignmentCenter;
    _stopKeyField.allowMouseLeft = NO;
    _stopKeyField.delegate = self;
    [startStopBox.contentView addSubview:_stopKeyField];
    
    [startStopBox.contentView addSubview:[self labelWithText:D3Loc(@"label_opener_key") frame:NSMakeRect(15, 13, 65, 20) bold:NO]];
    _mainOpenerTriggerKeyField = [[D3KeyTextField alloc] initWithFrame:NSMakeRect(85, 11, 155, 24)];
    _mainOpenerTriggerKeyField.alignment = NSTextAlignmentCenter;
    _mainOpenerTriggerKeyField.allowMouseLeft = NO;
    _mainOpenerTriggerKeyField.delegate = self;
    [startStopBox.contentView addSubview:_mainOpenerTriggerKeyField];
    
    _mainOpenerCheckBtn = [NSButton checkboxWithTitle:D3Loc(@"btn_opener_enable") target:self action:@selector(checkboxClicked:)];
    _mainOpenerCheckBtn.frame = NSMakeRect(248, 11, 72, 24);
    _mainOpenerCheckBtn.toolTip = D3Loc(@"btn_opener_enable_tooltip");
    [startStopBox.contentView addSubview:_mainOpenerCheckBtn];
    
    // [인게임 UI 종료 키] 그룹박스
    NSBox *inGameBox = [[NSBox alloc] initWithFrame:NSMakeRect(leftX, 170, leftW, 255)];
    inGameBox.title = D3Loc(@"box_ingame");
    [helperView addSubview:inGameBox];
    
    NSArray *inGameLabels = @[
        D3Loc(@"label_inventory"),
        D3Loc(@"label_skills"),
        D3Loc(@"label_follower"),
        D3Loc(@"label_map"),
        D3Loc(@"label_world_map"),
        D3Loc(@"label_portal"),
        D3Loc(@"label_chat"),
        D3Loc(@"label_whisper")
    ];
    NSMutableArray *inGameFields = [NSMutableArray array];
    for (int i = 0; i < 8; i++) {
        CGFloat y = 196 - (i * 26);
        [inGameBox.contentView addSubview:[self labelWithText:inGameLabels[i] frame:NSMakeRect(15, y, 95, 20) bold:NO]];
        D3KeyTextField *field = [[D3KeyTextField alloc] initWithFrame:NSMakeRect(115, y, 205, 22)];
        field.alignment = NSTextAlignmentCenter;
        field.allowMouseLeft = NO;
        field.delegate = self;
        [inGameBox.contentView addSubview:field];
        [inGameFields addObject:field];
    }
    _inventoryKeyField = inGameFields[0];
    _skillsMenuKeyField = inGameFields[1];
    _followerKeyField = inGameFields[2];
    _mapKeyField = inGameFields[3];
    _worldMapKeyField = inGameFields[4];
    _portalKeyField = inGameFields[5];
    _chatKeyField = inGameFields[6];
    _whisperKeyField = inGameFields[7];
    
    // [특수키] 그룹박스
    NSBox *specBox = [[NSBox alloc] initWithFrame:NSMakeRect(leftX, 10, leftW, 155)];
    specBox.title = D3Loc(@"box_special");
    [helperView addSubview:specBox];
    
    for (int i = 0; i < 3; i++) {
        CGFloat y = 92 - (i * 36);
        [specBox.contentView addSubview:[self labelWithText:D3LocFormat(@"label_special_key", i + 1) frame:NSMakeRect(15, y, 65, 20) bold:NO]];
        _specialKeyFields[i] = [[D3KeyTextField alloc] initWithFrame:NSMakeRect(85, y, 140, 24)];
        _specialKeyFields[i].alignment = NSTextAlignmentCenter;
        _specialKeyFields[i].allowMouseLeft = NO;
        _specialKeyFields[i].delegate = self;
        [specBox.contentView addSubview:_specialKeyFields[i]];
        
        _specialKeyCheckButtons[i] = [NSButton checkboxWithTitle:D3Loc(@"btn_cooldown_after") target:self action:@selector(checkboxClicked:)];
        _specialKeyCheckButtons[i].frame = NSMakeRect(235, y, 95, 24);
        _specialKeyCheckButtons[i].toolTip = D3Loc(@"btn_cooldown_after_tooltip");
        [specBox.contentView addSubview:_specialKeyCheckButtons[i]];
    }
    
    // [기술키 1 ~ 8 슬롯] 그룹박스
    CGFloat rightX = 370;
    CGFloat rightW = 480;
    NSBox *skillBox = [[NSBox alloc] initWithFrame:NSMakeRect(rightX, 10, rightW, 555)];
    skillBox.title = D3Loc(@"box_skills");
    [helperView addSubview:skillBox];
    
    [skillBox.contentView addSubview:[self labelWithText:D3Loc(@"col_skill") frame:NSMakeRect(15, 495, 45, 18) bold:YES]];
    [skillBox.contentView addSubview:[self labelWithText:D3Loc(@"col_special_v") frame:NSMakeRect(68, 495, 60, 18) bold:YES]];
    [skillBox.contentView addSubview:[self labelWithText:D3Loc(@"col_input_key") frame:NSMakeRect(145, 495, 65, 18) bold:YES]];
    [skillBox.contentView addSubview:[self labelWithText:D3Loc(@"col_mode") frame:NSMakeRect(255, 495, 65, 18) bold:YES]];
    [skillBox.contentView addSubview:[self labelWithText:D3Loc(@"col_interval") frame:NSMakeRect(360, 495, 75, 18) bold:YES]];
    
    for (int i = 0; i < 8; i++) {
        CGFloat y = 460 - (i * 48);
        [skillBox.contentView addSubview:[self labelWithText:D3LocFormat(@"label_skill_row", i + 1) frame:NSMakeRect(15, y, 48, 20) bold:NO]];
        
        _skillCheckButtons[i] = [NSButton checkboxWithTitle:@"" target:self action:@selector(checkboxClicked:)];
        _skillCheckButtons[i].frame = NSMakeRect(80, y, 22, 22);
        _skillCheckButtons[i].state = NSControlStateValueOn;
        [skillBox.contentView addSubview:_skillCheckButtons[i]];
        
        _skillKeyFields[i] = [[D3KeyTextField alloc] initWithFrame:NSMakeRect(125, y, 105, 24)];
        _skillKeyFields[i].alignment = NSTextAlignmentCenter;
        _skillKeyFields[i].delegate = self;
        [skillBox.contentView addSubview:_skillKeyFields[i]];
        
        _skillModePopUps[i] = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(240, y - 1, 95, 26) pullsDown:NO];
        [_skillModePopUps[i] addItemWithTitle:D3Loc(@"mode_spam")];
        [_skillModePopUps[i] addItemWithTitle:D3Loc(@"mode_hold")];
        _skillModePopUps[i].tag = i;
        _skillModePopUps[i].target = self;
        _skillModePopUps[i].action = @selector(skillModeChanged:);
        [skillBox.contentView addSubview:_skillModePopUps[i]];
        
        _skillDelayFields[i] = [[NSTextField alloc] initWithFrame:NSMakeRect(345, y, 70, 24)];
        _skillDelayFields[i].alignment = NSTextAlignmentRight;
        _skillDelayFields[i].delegate = self;
        [skillBox.contentView addSubview:_skillDelayFields[i]];
        
        [skillBox.contentView addSubview:[self labelWithText:D3Loc(@"unit_ms") frame:NSMakeRect(420, y, 25, 20) bold:NO]];
    }
    
    NSTextField *skillNote = [self labelWithText:D3Loc(@"skill_note") frame:NSMakeRect(15, 8, 450, 36) bold:NO];
    skillNote.textColor = [NSColor secondaryLabelColor];
    skillNote.font = [NSFont systemFontOfSize:11];
    [skillBox.contentView addSubview:skillNote];
    
    [tabView addTabViewItem:helperTab];
    
    // =============================================================
    // TAB 2: 로테이션 & 준비 시퀀스 (D4 고도화)
    // =============================================================
    NSTabViewItem *rotationTab = [[NSTabViewItem alloc] initWithIdentifier:@"rotationTab"];
    rotationTab.label = D3Loc(@"tab_rotation");
    NSView *rotationView = [[NSView alloc] initWithFrame:tabView.contentRect];
    rotationTab.view = rotationView;
    
    // [초기 준비 / 스택 시퀀스] 그룹박스
    NSBox *openerBox = [[NSBox alloc] initWithFrame:NSMakeRect(15, 250, 835, 315)];
    openerBox.title = D3Loc(@"box_opener");
    [rotationView addSubview:openerBox];
    
    _openerCheckBtn = [NSButton checkboxWithTitle:D3Loc(@"btn_opener_autorun") target:self action:@selector(checkboxClicked:)];
    _openerCheckBtn.frame = NSMakeRect(15, 260, 270, 24);
    _openerCheckBtn.font = [NSFont boldSystemFontOfSize:12];
    [openerBox.contentView addSubview:_openerCheckBtn];
    
    [openerBox.contentView addSubview:[self labelWithText:D3Loc(@"label_opener_trigger") frame:NSMakeRect(295, 262, 110, 20) bold:NO]];
    _openerTriggerKeyField = [[D3KeyTextField alloc] initWithFrame:NSMakeRect(410, 260, 110, 24)];
    _openerTriggerKeyField.alignment = NSTextAlignmentCenter;
    _openerTriggerKeyField.allowMouseLeft = NO;
    _openerTriggerKeyField.delegate = self;
    [openerBox.contentView addSubview:_openerTriggerKeyField];
    
    _openerTestBtn = [[NSButton alloc] initWithFrame:NSMakeRect(530, 258, 150, 26)];
    _openerTestBtn.title = D3Loc(@"btn_opener_test");
    _openerTestBtn.bezelStyle = NSBezelStyleRounded;
    _openerTestBtn.target = self;
    _openerTestBtn.action = @selector(runOpenerTest:);
    [openerBox.contentView addSubview:_openerTestBtn];
    
    [openerBox.contentView addSubview:[self labelWithText:D3Loc(@"col_step") frame:NSMakeRect(20, 228, 50, 18) bold:YES]];
    [openerBox.contentView addSubview:[self labelWithText:D3Loc(@"col_opener_key") frame:NSMakeRect(85, 228, 70, 18) bold:YES]];
    [openerBox.contentView addSubview:[self labelWithText:D3Loc(@"col_opener_delay") frame:NSMakeRect(195, 228, 70, 18) bold:YES]];
    [openerBox.contentView addSubview:[self labelWithText:D3Loc(@"col_opener_repeat") frame:NSMakeRect(300, 228, 75, 18) bold:YES]];
    [openerBox.contentView addSubview:[self labelWithText:D3Loc(@"col_opener_desc") frame:NSMakeRect(410, 228, 200, 18) bold:YES]];
    
    for (int i = 0; i < 5; i++) {
        CGFloat y = 195 - (i * 36);
        [openerBox.contentView addSubview:[self labelWithText:D3LocFormat(@"label_step_row", i + 1) frame:NSMakeRect(15, y, 55, 20) bold:NO]];
        
        _openerKeyFields[i] = [[D3KeyTextField alloc] initWithFrame:NSMakeRect(75, y, 95, 24)];
        _openerKeyFields[i].alignment = NSTextAlignmentCenter;
        _openerKeyFields[i].delegate = self;
        [openerBox.contentView addSubview:_openerKeyFields[i]];
        
        _openerDelayFields[i] = [[NSTextField alloc] initWithFrame:NSMakeRect(190, y, 65, 24)];
        _openerDelayFields[i].alignment = NSTextAlignmentRight;
        _openerDelayFields[i].delegate = self;
        [openerBox.contentView addSubview:_openerDelayFields[i]];
        [openerBox.contentView addSubview:[self labelWithText:D3Loc(@"unit_ms") frame:NSMakeRect(260, y, 25, 20) bold:NO]];
        
        _openerRepeatPopUps[i] = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(295, y - 1, 85, 26) pullsDown:NO];
        for (NSUInteger optIdx = 0; optIdx < kOpenerRepeatOptionsCount; optIdx++) {
            [_openerRepeatPopUps[i] addItemWithTitle:D3LocFormat(@"opener_repeat_times", (int)kOpenerRepeatOptions[optIdx])];
        }
        _openerRepeatPopUps[i].target = self;
        _openerRepeatPopUps[i].action = @selector(checkboxClicked:);
        [openerBox.contentView addSubview:_openerRepeatPopUps[i]];
        
        _openerDescFields[i] = [[NSTextField alloc] initWithFrame:NSMakeRect(395, y, 415, 24)];
        _openerDescFields[i].placeholderString = D3Loc(@"opener_desc_placeholder");
        _openerDescFields[i].delegate = self;
        [openerBox.contentView addSubview:_openerDescFields[i]];
    }
    
    NSTextField *openerNote = [self labelWithText:D3Loc(@"opener_note") frame:NSMakeRect(15, 8, 800, 18) bold:NO];
    openerNote.textColor = [NSColor secondaryLabelColor];
    openerNote.font = [NSFont systemFontOfSize:11];
    [openerBox.contentView addSubview:openerNote];
    
    // [연계 콤보 사이클 (Generator -> Spender)] 그룹박스
    NSBox *comboBox = [[NSBox alloc] initWithFrame:NSMakeRect(15, 10, 835, 225)];
    comboBox.title = D3Loc(@"box_combo");
    [rotationView addSubview:comboBox];
    
    _comboCheckBtn = [NSButton checkboxWithTitle:D3Loc(@"btn_combo_enable") target:self action:@selector(checkboxClicked:)];
    _comboCheckBtn.frame = NSMakeRect(15, 168, 620, 24);
    _comboCheckBtn.font = [NSFont boldSystemFontOfSize:12];
    [comboBox.contentView addSubview:_comboCheckBtn];
    
    // 생성기 & 소모기 행
    CGFloat comboY1 = 125;
    [comboBox.contentView addSubview:[self labelWithText:D3Loc(@"label_combo_gen") frame:NSMakeRect(15, comboY1, 115, 20) bold:NO]];
    _comboGenKeyField = [[D3KeyTextField alloc] initWithFrame:NSMakeRect(135, comboY1, 95, 24)];
    _comboGenKeyField.alignment = NSTextAlignmentCenter;
    _comboGenKeyField.allowMouseLeft = NO;
    _comboGenKeyField.delegate = self;
    [comboBox.contentView addSubview:_comboGenKeyField];
    
    [comboBox.contentView addSubview:[self labelWithText:D3Loc(@"label_combo_count") frame:NSMakeRect(240, comboY1, 45, 20) bold:NO]];
    _comboGenCountField = [[NSTextField alloc] initWithFrame:NSMakeRect(290, comboY1, 45, 24)];
    _comboGenCountField.alignment = NSTextAlignmentCenter;
    _comboGenCountField.delegate = self;
    [comboBox.contentView addSubview:_comboGenCountField];
    [comboBox.contentView addSubview:[self labelWithText:D3Loc(@"unit_times") frame:NSMakeRect(340, comboY1, 30, 20) bold:NO]];
    
    [comboBox.contentView addSubview:[self labelWithText:D3Loc(@"label_combo_spend") frame:NSMakeRect(385, comboY1, 115, 20) bold:NO]];
    _comboSpendKeyField = [[D3KeyTextField alloc] initWithFrame:NSMakeRect(505, comboY1, 95, 24)];
    _comboSpendKeyField.alignment = NSTextAlignmentCenter;
    _comboSpendKeyField.allowMouseLeft = NO;
    _comboSpendKeyField.delegate = self;
    [comboBox.contentView addSubview:_comboSpendKeyField];
    
    [comboBox.contentView addSubview:[self labelWithText:D3Loc(@"label_combo_count") frame:NSMakeRect(610, comboY1, 45, 20) bold:NO]];
    _comboSpendCountField = [[NSTextField alloc] initWithFrame:NSMakeRect(660, comboY1, 45, 24)];
    _comboSpendCountField.alignment = NSTextAlignmentCenter;
    _comboSpendCountField.delegate = self;
    [comboBox.contentView addSubview:_comboSpendCountField];
    [comboBox.contentView addSubview:[self labelWithText:D3Loc(@"unit_times") frame:NSMakeRect(710, comboY1, 30, 20) bold:NO]];
    
    // 발동 간격 행
    CGFloat comboY2 = 80;
    [comboBox.contentView addSubview:[self labelWithText:D3Loc(@"label_combo_interval") frame:NSMakeRect(15, comboY2, 75, 20) bold:NO]];
    _comboIntervalField = [[NSTextField alloc] initWithFrame:NSMakeRect(95, comboY2, 60, 24)];
    _comboIntervalField.alignment = NSTextAlignmentRight;
    _comboIntervalField.delegate = self;
    [comboBox.contentView addSubview:_comboIntervalField];
    [comboBox.contentView addSubview:[self labelWithText:D3Loc(@"unit_ms") frame:NSMakeRect(160, comboY2, 25, 20) bold:NO]];
    
    NSTextField *comboNote = [self labelWithText:D3Loc(@"combo_note") frame:NSMakeRect(15, 12, 800, 48) bold:NO];
    comboNote.textColor = [NSColor secondaryLabelColor];
    comboNote.font = [NSFont systemFontOfSize:11];
    [comboBox.contentView addSubview:comboNote];
    
    [tabView addTabViewItem:rotationTab];
    
    // =============================================================
    // TAB 3: 단일반복 & 편의기능
    // =============================================================
    NSTabViewItem *featureTab = [[NSTabViewItem alloc] initWithIdentifier:@"featureTab"];
    featureTab.label = D3Loc(@"tab_features");
    NSView *featureView = [[NSView alloc] initWithFrame:tabView.contentRect];
    featureTab.view = featureView;
    
    // [단일반복키] 그룹박스
    NSBox *singleBox = [[NSBox alloc] initWithFrame:NSMakeRect(15, 375, 835, 190)];
    singleBox.title = D3Loc(@"box_single");
    [featureView addSubview:singleBox];
    
    [singleBox.contentView addSubview:[self labelWithText:D3Loc(@"col_single_toggle") frame:NSMakeRect(135, 135, 110, 18) bold:YES]];
    [singleBox.contentView addSubview:[self labelWithText:D3Loc(@"col_single_action") frame:NSMakeRect(320, 135, 110, 18) bold:YES]];
    [singleBox.contentView addSubview:[self labelWithText:D3Loc(@"col_single_delay") frame:NSMakeRect(495, 135, 80, 18) bold:YES]];
    
    for (int i = 0; i < 3; i++) {
        CGFloat y = 98 - (i * 38);
        [singleBox.contentView addSubview:[self labelWithText:D3LocFormat(@"label_single_row", i + 1) frame:NSMakeRect(20, y, 80, 20) bold:NO]];
        
        _singleToggleFields[i] = [[D3KeyTextField alloc] initWithFrame:NSMakeRect(115, y, 140, 24)];
        _singleToggleFields[i].alignment = NSTextAlignmentCenter;
        _singleToggleFields[i].allowMouseLeft = NO;
        _singleToggleFields[i].delegate = self;
        [singleBox.contentView addSubview:_singleToggleFields[i]];
        
        _singleActionFields[i] = [[D3KeyTextField alloc] initWithFrame:NSMakeRect(295, y, 140, 24)];
        _singleActionFields[i].alignment = NSTextAlignmentCenter;
        _singleActionFields[i].allowMouseLeft = YES;
        _singleActionFields[i].delegate = self;
        [singleBox.contentView addSubview:_singleActionFields[i]];
        
        _singleDelayFields[i] = [[NSTextField alloc] initWithFrame:NSMakeRect(480, y, 80, 24)];
        _singleDelayFields[i].alignment = NSTextAlignmentRight;
        _singleDelayFields[i].delegate = self;
        [singleBox.contentView addSubview:_singleDelayFields[i]];
        
        [singleBox.contentView addSubview:[self labelWithText:D3Loc(@"unit_ms") frame:NSMakeRect(565, y, 25, 20) bold:NO]];
    }
    
    // [퀘스트키 & 시간조절키] 그룹박스
    NSBox *miscBox = [[NSBox alloc] initWithFrame:NSMakeRect(15, 235, 835, 130)];
    miscBox.title = D3Loc(@"box_misc");
    [featureView addSubview:miscBox];
    
    [miscBox.contentView addSubview:[self labelWithText:D3Loc(@"label_quest_key") frame:NSMakeRect(20, 68, 260, 18) bold:NO]];
    _questKeyField = [[D3KeyTextField alloc] initWithFrame:NSMakeRect(290, 65, 180, 24)];
    _questKeyField.alignment = NSTextAlignmentCenter;
    _questKeyField.allowMouseLeft = NO;
    _questKeyField.delegate = self;
    [miscBox.contentView addSubview:_questKeyField];
    
    [miscBox.contentView addSubview:[self labelWithText:D3Loc(@"label_speed_mod_key") frame:NSMakeRect(20, 22, 90, 20) bold:NO]];
    _speedModKeyField = [[D3KeyTextField alloc] initWithFrame:NSMakeRect(115, 20, 110, 24)];
    _speedModKeyField.alignment = NSTextAlignmentCenter;
    _speedModKeyField.allowMouseLeft = NO;
    _speedModKeyField.delegate = self;
    [miscBox.contentView addSubview:_speedModKeyField];
    
    [miscBox.contentView addSubview:[self labelWithText:D3Loc(@"label_speed_mod_offset") frame:NSMakeRect(240, 22, 65, 20) bold:NO]];
    _speedModOffsetField = [[NSTextField alloc] initWithFrame:NSMakeRect(310, 20, 65, 24)];
    _speedModOffsetField.alignment = NSTextAlignmentRight;
    _speedModOffsetField.delegate = self;
    [miscBox.contentView addSubview:_speedModOffsetField];
    [miscBox.contentView addSubview:[self labelWithText:D3Loc(@"unit_ms") frame:NSMakeRect(380, 22, 25, 20) bold:NO]];
    
    _speedModToggleBtn = [NSButton checkboxWithTitle:D3Loc(@"btn_speed_mod_toggle") target:self action:@selector(checkboxClicked:)];
    _speedModToggleBtn.frame = NSMakeRect(415, 22, 100, 20);
    _speedModToggleBtn.toolTip = D3Loc(@"btn_speed_mod_toggle_tooltip");
    [miscBox.contentView addSubview:_speedModToggleBtn];
    
    // [방해금지 모드 및 사운드 설정]
    NSBox *antiDistBox = [[NSBox alloc] initWithFrame:NSMakeRect(15, 10, 835, 215)];
    antiDistBox.title = D3Loc(@"box_antidist");
    [featureView addSubview:antiDistBox];
    
    _antiDisturbanceButton = [NSButton checkboxWithTitle:D3Loc(@"btn_antidist_enable") target:self action:@selector(checkboxClicked:)];
    _antiDisturbanceButton.frame = NSMakeRect(20, 150, 550, 24);
    _antiDisturbanceButton.font = [NSFont boldSystemFontOfSize:12];
    [antiDistBox.contentView addSubview:_antiDisturbanceButton];
    
    _soundFeedbackBtn = [NSButton checkboxWithTitle:D3Loc(@"btn_sound_feedback") target:self action:@selector(checkboxClicked:)];
    _soundFeedbackBtn.frame = NSMakeRect(20, 122, 450, 24);
    _soundFeedbackBtn.font = [NSFont boldSystemFontOfSize:12];
    [antiDistBox.contentView addSubview:_soundFeedbackBtn];
    
    [antiDistBox.contentView addSubview:[self labelWithText:D3Loc(@"label_resolution") frame:NSMakeRect(20, 92, 130, 20) bold:NO]];
    _resolutionPopUp = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(155, 88, 260, 26) pullsDown:NO];
    for (NSString *res in [D3DeadzoneFilter supportedResolutions]) {
        [_resolutionPopUp addItemWithTitle:res];
    }
    _resolutionPopUp.target = self;
    _resolutionPopUp.action = @selector(resolutionChanged:);
    [antiDistBox.contentView addSubview:_resolutionPopUp];
    
    NSTextField *antiNote = [self labelWithText:D3Loc(@"antidist_note") frame:NSMakeRect(20, 15, 790, 60) bold:NO];
    antiNote.textColor = [NSColor secondaryLabelColor];
    antiNote.font = [NSFont systemFontOfSize:11];
    [antiDistBox.contentView addSubview:antiNote];
    
    [tabView addTabViewItem:featureTab];
    [root addSubview:tabView];
}

- (NSTextField *)labelWithText:(NSString *)text frame:(NSRect)frame bold:(BOOL)bold {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = text;
    label.editable = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.selectable = NO;
    label.font = bold ? [NSFont boldSystemFontOfSize:12] : [NSFont systemFontOfSize:12];
    return label;
}

#pragma mark Configuration Load / Set / Get

- (void)loadConfig:(NSString *)configId {
    _isUpdatingUI = YES;
    D3KeyConfig *config = [[D3KeyConfigService sharedService] loadConfig:configId];
    [self setFieldValues:config];
    _isUpdatingUI = NO;
    
    [[D3HelperEngine sharedEngine] updateConfig:config];
    [self updateEngineUIState:[[D3HelperEngine sharedEngine] isRunning]];
}

- (void)setFieldValues:(D3KeyConfig *)config {
    if (!config) return;
    [config sanitize];
    
    _memoField.stringValue = config.memo ?: @"";
    
    // 시작 / 종료 키
    [_startKeyField setInputKey:config.startInputKey];
    [_stopKeyField setInputKey:config.stopInputKey];
    
    // 인게임 종료 키
    [_inventoryKeyField setInputKey:config.inventoryKey];
    [_skillsMenuKeyField setInputKey:config.skillsMenuKey];
    [_followerKeyField setInputKey:config.followerKey];
    [_mapKeyField setInputKey:config.mapKey];
    [_worldMapKeyField setInputKey:config.worldMapKey];
    [_portalKeyField setInputKey:config.portalKey];
    [_chatKeyField setInputKey:config.chatKey];
    [_whisperKeyField setInputKey:config.whisperKey];
    
    // 기술 1 ~ 8
    for (int i = 0; i < 8; i++) {
        NSInteger slot = i + 1;
        [_skillKeyFields[i] setInputKey:[config skillInputKeyAtIndex:slot]];
        _skillCheckButtons[i].state = [config skillCheckAtIndex:slot] ? NSControlStateValueOn : NSControlStateValueOff;
        
        BOOL isHold = [config skillHoldAtIndex:slot];
        [_skillModePopUps[i] selectItemAtIndex:isHold ? 1 : 0];
        _skillDelayFields[i].enabled = !isHold;
        
        NSUInteger delay = [config skillDelayAtIndex:slot];
        _skillDelayFields[i].stringValue = (delay > 0) ? [NSString stringWithFormat:@"%lu", (unsigned long)delay] : @"";
    }
    
    // 특수키 1 ~ 3
    for (int i = 0; i < 3; i++) {
        NSInteger slot = i + 1;
        [_specialKeyFields[i] setInputKey:[config specialKeyAtIndex:slot]];
        _specialKeyCheckButtons[i].state = [config specialKeyCooldownAtIndex:slot] ? NSControlStateValueOn : NSControlStateValueOff;
    }
    
    // 오프너 시퀀스
    _openerCheckBtn.state = config.openerEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    _mainOpenerCheckBtn.state = config.openerEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [_openerTriggerKeyField setInputKey:config.openerTriggerKey];
    [_mainOpenerTriggerKeyField setInputKey:config.openerTriggerKey];
    for (int i = 0; i < 5; i++) {
        D3OpenerStep *step = [config openerStepAtIndex:(i + 1)];
        [_openerKeyFields[i] setInputKey:step.inputKey];
        _openerDelayFields[i].stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)step.delayMs];
        
        NSInteger repIndex = openerIndexForRepeatCount(step.repeatCount);
        [_openerRepeatPopUps[i] selectItemAtIndex:repIndex];
        _openerDescFields[i].stringValue = step.stepDescription ?: @"";
    }
    
    // 연계 콤보 사이클
    _comboCheckBtn.state = config.comboEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [_comboGenKeyField setInputKey:config.comboGeneratorKey];
    _comboGenCountField.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)config.comboGeneratorCount];
    [_comboSpendKeyField setInputKey:config.comboSpenderKey];
    _comboSpendCountField.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)config.comboSpenderCount];
    _comboIntervalField.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)config.comboInterval];
    
    // 단일반복키 1 ~ 3
    for (int i = 0; i < 3; i++) {
        NSInteger slot = i + 1;
        [_singleToggleFields[i] setInputKey:[config singleRepeatToggleAtIndex:slot]];
        [_singleActionFields[i] setInputKey:[config singleRepeatActionAtIndex:slot]];
        NSUInteger delay = [config singleRepeatDelayAtIndex:slot];
        _singleDelayFields[i].stringValue = (delay > 0) ? [NSString stringWithFormat:@"%lu", (unsigned long)delay] : @"";
    }
    
    // 퀘스트키 & 시간조절키
    [_questKeyField setInputKey:config.questKey];
    [_speedModKeyField setInputKey:config.speedModKey];
    _speedModOffsetField.stringValue = [NSString stringWithFormat:@"%ld", (long)config.speedModOffset];
    _speedModToggleBtn.state = config.speedModToggleMode ? NSControlStateValueOn : NSControlStateValueOff;
    
    // 방해금지 모드 및 사운드
    _antiDisturbanceButton.state = config.antiDisturbanceEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    _soundFeedbackBtn.state = config.soundFeedbackEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    if (config.selectedResolution.length > 0) {
        [_resolutionPopUp selectItemWithTitle:config.selectedResolution];
    }
}

- (NSUInteger)parseDelayString:(NSString *)str defaultVal:(NSUInteger)def {
    NSInteger val = [str integerValue];
    if (val <= 0) return def;
    return (NSUInteger)val;
}

- (D3KeyConfig *)getFieldValues {
    D3KeyConfig *config = [[D3KeyConfig alloc] init];
    config.memo = _memoField.stringValue ?: @"";
    
    // 시작/종료키
    config.startInputKey = _startKeyField.inputKey ?: [D3InputKey emptyKey];
    config.stopInputKey = _stopKeyField.inputKey ?: [D3InputKey emptyKey];
    
    // 인게임 종료키
    config.inventoryKey = _inventoryKeyField.inputKey ?: [D3InputKey emptyKey];
    config.skillsMenuKey = _skillsMenuKeyField.inputKey ?: [D3InputKey emptyKey];
    config.followerKey = _followerKeyField.inputKey ?: [D3InputKey emptyKey];
    config.mapKey = _mapKeyField.inputKey ?: [D3InputKey emptyKey];
    config.worldMapKey = _worldMapKeyField.inputKey ?: [D3InputKey emptyKey];
    config.portalKey = _portalKeyField.inputKey ?: [D3InputKey emptyKey];
    config.chatKey = _chatKeyField.inputKey ?: [D3InputKey emptyKey];
    config.whisperKey = _whisperKeyField.inputKey ?: [D3InputKey emptyKey];
    
    // 기술 1 ~ 8
    config.skillInputKey1 = _skillKeyFields[0].inputKey;
    config.skillDelay1 = [self parseDelayString:_skillDelayFields[0].stringValue defaultVal:1000];
    config.skillCheck1 = (_skillCheckButtons[0].state == NSControlStateValueOn);
    config.skillHold1 = (_skillModePopUps[0].indexOfSelectedItem == 1);
    
    config.skillInputKey2 = _skillKeyFields[1].inputKey;
    config.skillDelay2 = [self parseDelayString:_skillDelayFields[1].stringValue defaultVal:1000];
    config.skillCheck2 = (_skillCheckButtons[1].state == NSControlStateValueOn);
    config.skillHold2 = (_skillModePopUps[1].indexOfSelectedItem == 1);
    
    config.skillInputKey3 = _skillKeyFields[2].inputKey;
    config.skillDelay3 = [self parseDelayString:_skillDelayFields[2].stringValue defaultVal:1000];
    config.skillCheck3 = (_skillCheckButtons[2].state == NSControlStateValueOn);
    config.skillHold3 = (_skillModePopUps[2].indexOfSelectedItem == 1);
    
    config.skillInputKey4 = _skillKeyFields[3].inputKey;
    config.skillDelay4 = [self parseDelayString:_skillDelayFields[3].stringValue defaultVal:1000];
    config.skillCheck4 = (_skillCheckButtons[3].state == NSControlStateValueOn);
    config.skillHold4 = (_skillModePopUps[3].indexOfSelectedItem == 1);
    
    config.skillInputKey5 = _skillKeyFields[4].inputKey;
    config.skillDelay5 = [_skillDelayFields[4].stringValue integerValue];
    config.skillCheck5 = (_skillCheckButtons[4].state == NSControlStateValueOn);
    config.skillHold5 = (_skillModePopUps[4].indexOfSelectedItem == 1);
    
    config.skillInputKey6 = _skillKeyFields[5].inputKey;
    config.skillDelay6 = [_skillDelayFields[5].stringValue integerValue];
    config.skillCheck6 = (_skillCheckButtons[5].state == NSControlStateValueOn);
    config.skillHold6 = (_skillModePopUps[5].indexOfSelectedItem == 1);
    
    config.skillInputKey7 = _skillKeyFields[6].inputKey;
    config.skillDelay7 = [_skillDelayFields[6].stringValue integerValue];
    config.skillCheck7 = (_skillCheckButtons[6].state == NSControlStateValueOn);
    config.skillHold7 = (_skillModePopUps[6].indexOfSelectedItem == 1);
    
    config.skillInputKey8 = _skillKeyFields[7].inputKey;
    config.skillDelay8 = [_skillDelayFields[7].stringValue integerValue];
    config.skillCheck8 = (_skillCheckButtons[7].state == NSControlStateValueOn);
    config.skillHold8 = (_skillModePopUps[7].indexOfSelectedItem == 1);
    
    // 특수키 1 ~ 3
    config.specialKey1 = _specialKeyFields[0].inputKey;
    config.specialKeyCooldown1 = (_specialKeyCheckButtons[0].state == NSControlStateValueOn);
    config.specialKey2 = _specialKeyFields[1].inputKey;
    config.specialKeyCooldown2 = (_specialKeyCheckButtons[1].state == NSControlStateValueOn);
    config.specialKey3 = _specialKeyFields[2].inputKey;
    config.specialKeyCooldown3 = (_specialKeyCheckButtons[2].state == NSControlStateValueOn);
    
    // 오프너 시퀀스 (메인 화면 및 탭 2 양방향 동기화)
    config.openerEnabled = (_mainOpenerCheckBtn.state == NSControlStateValueOn);
    config.openerTriggerKey = _mainOpenerTriggerKeyField.inputKey ?: [D3InputKey emptyKey];
    for (int i = 0; i < 5; i++) {
        D3InputKey *key = _openerKeyFields[i].inputKey ?: [D3InputKey emptyKey];
        NSUInteger delay = [self parseDelayString:_openerDelayFields[i].stringValue defaultVal:150];
        NSUInteger reps = openerRepeatCountForIndex(_openerRepeatPopUps[i].indexOfSelectedItem);
        NSString *desc = _openerDescFields[i].stringValue ?: @"";
        [config setOpenerStep:[D3OpenerStep stepWithKey:key delayMs:delay repeatCount:reps description:desc] atIndex:(i + 1)];
    }
    
    // 연계 콤보 사이클
    config.comboEnabled = (_comboCheckBtn.state == NSControlStateValueOn);
    config.comboGeneratorKey = _comboGenKeyField.inputKey ?: [D3InputKey emptyKey];
    config.comboGeneratorCount = [self parseDelayString:_comboGenCountField.stringValue defaultVal:3];
    config.comboSpenderKey = _comboSpendKeyField.inputKey ?: [D3InputKey emptyKey];
    config.comboSpenderCount = [self parseDelayString:_comboSpendCountField.stringValue defaultVal:1];
    config.comboInterval = [self parseDelayString:_comboIntervalField.stringValue defaultVal:150];
    
    // 단일반복키 1 ~ 3 (지연시간은 사용자가 입력한 값 유지, 빈칸 시 0)
    config.singleRepeatToggle1 = _singleToggleFields[0].inputKey ?: [D3InputKey emptyKey];
    config.singleRepeatAction1 = _singleActionFields[0].inputKey ?: [D3InputKey emptyKey];
    config.singleRepeatDelay1 = [_singleDelayFields[0].stringValue integerValue] > 0 ? (NSUInteger)[_singleDelayFields[0].stringValue integerValue] : 0;
    
    config.singleRepeatToggle2 = _singleToggleFields[1].inputKey ?: [D3InputKey emptyKey];
    config.singleRepeatAction2 = _singleActionFields[1].inputKey ?: [D3InputKey emptyKey];
    config.singleRepeatDelay2 = [_singleDelayFields[1].stringValue integerValue] > 0 ? (NSUInteger)[_singleDelayFields[1].stringValue integerValue] : 0;
    
    config.singleRepeatToggle3 = _singleToggleFields[2].inputKey ?: [D3InputKey emptyKey];
    config.singleRepeatAction3 = _singleActionFields[2].inputKey ?: [D3InputKey emptyKey];
    config.singleRepeatDelay3 = [_singleDelayFields[2].stringValue integerValue] > 0 ? (NSUInteger)[_singleDelayFields[2].stringValue integerValue] : 0;
    
    // 퀘스트키 & 시간조절키
    config.questKey = _questKeyField.inputKey;
    config.speedModKey = _speedModKeyField.inputKey;
    config.speedModOffset = [_speedModOffsetField.stringValue integerValue];
    config.speedModToggleMode = (_speedModToggleBtn.state == NSControlStateValueOn);
    
    // 방해금지 모드 및 사운드
    config.antiDisturbanceEnabled = (_antiDisturbanceButton.state == NSControlStateValueOn);
    config.soundFeedbackEnabled = (_soundFeedbackBtn.state == NSControlStateValueOn);
    config.selectedResolution = _resolutionPopUp.titleOfSelectedItem ?: @"자동 감지 (현재 디스플레이)";
    
    [config sanitize];
    return config;
}

- (void)save {
    if (_isUpdatingUI) return;
    _isUpdatingUI = YES;
    @try {
        NSString *configId = [NSString stringWithFormat:@"%ld", (long)_configIdSegment.selectedSegment + 1];
        D3KeyConfig *config = [self getFieldValues];
        [config sanitize];
        
        // UI 동기화
        _mainOpenerCheckBtn.state = config.openerEnabled ? NSControlStateValueOn : NSControlStateValueOff;
        _openerCheckBtn.state = config.openerEnabled ? NSControlStateValueOn : NSControlStateValueOff;
        [_mainOpenerTriggerKeyField setInputKey:config.openerTriggerKey];
        [_openerTriggerKeyField setInputKey:config.openerTriggerKey];
        
        for (int i = 0; i < 3; i++) {
            NSInteger slot = i + 1;
            [_singleToggleFields[i] setInputKey:[config singleRepeatToggleAtIndex:slot]];
            [_singleActionFields[i] setInputKey:[config singleRepeatActionAtIndex:slot]];
        }
        
        [[D3KeyConfigService sharedService] saveConfig:config withConfigId:configId];
        [[D3HelperEngine sharedEngine] updateConfig:config];
        [self updateEngineUIState:[[D3HelperEngine sharedEngine] isRunning]];
    } @finally {
        _isUpdatingUI = NO;
    }
}

- (void)changePreset:(NSInteger)presetNum {
    _configIdSegment.selectedSegment = presetNum;
    NSString *configId = [NSString stringWithFormat:@"%ld", (long)presetNum + 1];
    [self loadConfig:configId];
    [[NSNotificationCenter defaultCenter] postNotificationName:kD3KeyConfigChangedNotification object:nil userInfo:@{@"configId":configId}];
    [[D3HelperEngine sharedEngine] stop];
}

#pragma mark Actions

- (IBAction)selectConfigIdSegemnt:(id)sender {
    [self.window makeFirstResponder:nil];
    NSSegmentedControl *control = (NSSegmentedControl *)sender;
    NSString *configId = [NSString stringWithFormat:@"%ld", (long)control.selectedSegment + 1];
    [self loadConfig:configId];
    [[NSNotificationCenter defaultCenter] postNotificationName:kD3KeyConfigChangedNotification object:nil userInfo:@{@"configId":configId}];
}

- (IBAction)presetSelected:(id)sender {
    NSInteger selectedIndex = _presetPopUp.indexOfSelectedItem;
    if (selectedIndex <= 0) return;
    
    NSArray *presetNames = [D3KeyConfig availablePresetNames];
    if (selectedIndex - 1 < presetNames.count) {
        NSString *originalName = presetNames[selectedIndex - 1];
        D3KeyConfig *preset = [D3KeyConfig presetWithName:originalName];
        if (preset) {
            _isUpdatingUI = YES;
            [self setFieldValues:preset];
            _isUpdatingUI = NO;
            [self save];
            [self updateEngineUIState:[[D3HelperEngine sharedEngine] isRunning]];
        }
    }
    
    // 다시 타이틀 복원
    [_presetPopUp selectItemAtIndex:0];
}

- (void)languageSelectedAction:(id)sender {
    NSPopUpButton *popup = (NSPopUpButton *)sender;
    NSInteger idx = popup.indexOfSelectedItem;
    D3LanguageMode mode = D3LanguageModeAuto;
    if (idx == 0) {
        mode = D3LanguageModeKorean;
    } else if (idx == 1) {
        mode = D3LanguageModeEnglish;
    } else {
        mode = D3LanguageModeAuto;
    }
    [D3LocalizationManager sharedManager].languageMode = mode;
}

- (void)languageDidChangeNotification:(NSNotification *)note {
    NSInteger curPreset = _configIdSegment.selectedSegment;
    D3KeyConfig *cur = [self getFieldValues];
    [self buildDHelperUI];
    [self setFieldValues:cur];
    if (curPreset >= 0 && curPreset < 5) {
        _configIdSegment.selectedSegment = curPreset;
    }
    [self updateAccessibilityStatusUI];
    [self updateEngineUIState:[[D3HelperEngine sharedEngine] isRunning]];
    if (_helpWindow && _helpWindow.isVisible) {
        _helpWindow.title = D3Loc(@"guide_win_title");
        [self updateHelpContentForCategory:_helpCategorySegment.selectedSegment];
    }
}

- (IBAction)toggleEngineAction:(id)sender {
    [[D3HelperEngine sharedEngine] toggle];
}

- (IBAction)runOpenerTest:(id)sender {
    [self save];
    [[D3HelperEngine sharedEngine] triggerOpener];
}

- (void)skillModeChanged:(id)sender {
    NSPopUpButton *popup = (NSPopUpButton *)sender;
    NSInteger index = popup.tag;
    if (index >= 0 && index < 8) {
        BOOL isHold = (popup.indexOfSelectedItem == 1);
        _skillDelayFields[index].enabled = !isHold;
    }
    [self save];
}

- (void)engineStateChangedNotification:(NSNotification *)note {
    BOOL isRunning = [[D3HelperEngine sharedEngine] isRunning];
    [self updateEngineUIState:isRunning];
}

- (void)engineOpenerNotification:(NSNotification *)note {
    BOOL isOpenerRunning = [note.userInfo[@"isOpenerRunning"] boolValue];
    [self updateOpenerUIState:isOpenerRunning];
}

- (void)helperEngineStateChanged:(BOOL)isRunning {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateEngineUIState:isRunning];
    });
}

- (void)helperEngineOpenerStateChanged:(BOOL)isOpenerRunning {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateOpenerUIState:isOpenerRunning];
    });
}

- (void)updateEngineUIState:(BOOL)isRunning {
    NSString *keyStr = [_startKeyField.inputKey displayString];
    if (keyStr.length == 0) keyStr = D3LocDef(@"manual_start", @"수동 시작");
    
    if ([[D3HelperEngine sharedEngine] isOpenerRunning]) {
        [self updateOpenerUIState:YES];
        return;
    }
    
    if (isRunning) {
        _engineToggleBtn.title = D3Loc(@"engine_stop");
        _engineStatusLabel.stringValue = [NSString stringWithFormat:@"%@ (%@)", D3Loc(@"status_running"), keyStr];
        _engineStatusLabel.textColor = [NSColor systemGreenColor];
    } else {
        _engineToggleBtn.title = D3Loc(@"engine_start");
        _engineStatusLabel.stringValue = [NSString stringWithFormat:@"%@ (%@)", D3Loc(@"status_stopped"), keyStr];
        _engineStatusLabel.textColor = [NSColor secondaryLabelColor];
    }
}

- (void)updateOpenerUIState:(BOOL)isOpenerRunning {
    if (isOpenerRunning) {
        _engineToggleBtn.title = D3Loc(@"engine_stop");
        _engineStatusLabel.stringValue = [NSString stringWithFormat:@"%@...", D3Loc(@"status_opener")];
        _engineStatusLabel.textColor = [NSColor systemOrangeColor];
    } else {
        [self updateEngineUIState:[[D3HelperEngine sharedEngine] isRunning]];
    }
}

- (IBAction)resetToDefaultsAction:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = D3LocDef(@"reset_alert_title", @"기본 설정으로 초기화");
    alert.informativeText = [NSString stringWithFormat:D3LocDef(@"reset_alert_info", @"프로필 %ld을(를) DHelper 기본 설정으로 복원하시겠습니까?"), (long)_configIdSegment.selectedSegment + 1];
    [alert addButtonWithTitle:D3Loc(@"btn_reset_defaults")];
    [alert addButtonWithTitle:D3LocDef(@"alert_cancel", @"취소")];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            D3KeyConfig *defaultConfig = [D3KeyConfig defaultKeyConfig];
            self->_isUpdatingUI = YES;
            [self setFieldValues:defaultConfig];
            self->_isUpdatingUI = NO;
            [self save];
            [self updateEngineUIState:[[D3HelperEngine sharedEngine] isRunning]];
        }
    }];
}

- (IBAction)selectActiveSegment:(id)sender {
    NSSegmentedControl *control = (NSSegmentedControl *)sender;
    if (control.selectedSegment == 0) {
        [[D3EventTapService sharedService] startEventTap];
        [[D3HelperEngine sharedEngine] start];
    } else {
        [[D3HelperEngine sharedEngine] stop];
    }
}

- (void)checkboxClicked:(id)sender {
    if (sender == _mainOpenerCheckBtn) {
        _openerCheckBtn.state = _mainOpenerCheckBtn.state;
    } else if (sender == _openerCheckBtn) {
        _mainOpenerCheckBtn.state = _openerCheckBtn.state;
    }
    [self save];
}

- (void)resolutionChanged:(id)sender {
    [self save];
}

- (IBAction)importConfigFile:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes = @[@"dhp", @"json"];
    panel.allowsMultipleSelection = NO;
    panel.canChooseDirectories = NO;
    panel.canCreateDirectories = NO;
    
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK && panel.URL) {
            NSError *error = nil;
            D3KeyConfig *imported = [[D3KeyConfigService sharedService] importConfigFromURL:panel.URL error:&error];
            if (imported) {
                self->_isUpdatingUI = YES;
                [self setFieldValues:imported];
                self->_isUpdatingUI = NO;
                [self save];
            } else {
                NSAlert *alert = [NSAlert alertWithError:error];
                [alert beginSheetModalForWindow:self.window completionHandler:nil];
            }
        }
    }];
}

- (IBAction)exportConfigFile:(id)sender {
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedFileTypes = @[@"dhp", @"json"];
    panel.nameFieldStringValue = [NSString stringWithFormat:@"%@.dhp", _memoField.stringValue.length ? _memoField.stringValue : @"DHelperConfig"];
    
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK && panel.URL) {
            NSError *error = nil;
            D3KeyConfig *current = [self getFieldValues];
            BOOL success = [[D3KeyConfigService sharedService] exportConfig:current toURL:panel.URL error:&error];
            if (!success && error) {
                NSAlert *alert = [NSAlert alertWithError:error];
                [alert beginSheetModalForWindow:self.window completionHandler:nil];
            }
        }
    }];
}

#pragma mark Google Sheets Preset Hub & D3PresetShareDelegate

- (IBAction)showPresetShareWindow:(id)sender {
    D3PresetShareWindowController *ctrl = [D3PresetShareWindowController sharedController];
    ctrl.delegate = self;
    [ctrl showWindowAndRefresh:sender];
}

- (void)presetShareDidSelectConfig:(D3KeyConfig *)config forSlot:(NSInteger)slot {
    if (slot < 1 || slot > 5) slot = 1;
    NSString *configId = [NSString stringWithFormat:@"%ld", (long)slot];
    [[D3KeyConfigService sharedService] saveConfig:config withConfigId:configId];
    
    // 만약 현재 활성화된 슬롯에 적용되었다면 즉시 UI와 엔진 갱신
    if ((long)_configIdSegment.selectedSegment + 1 == slot) {
        _isUpdatingUI = YES;
        [self setFieldValues:config];
        _isUpdatingUI = NO;
        [[D3HelperEngine sharedEngine] updateConfig:config];
    }
}

- (D3KeyConfig *)currentConfigForPresetSharing {
    return [self getFieldValues];
}

- (NSInteger)currentActiveSlot {
    return (NSInteger)_configIdSegment.selectedSegment + 1;
}

#pragma mark NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor {
    if ([control isKindOfClass:[D3KeyTextField class]]) {
        return NO;
    }
    return YES;
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if (_isUpdatingUI) return;
    
    // 오프너 트리거 키 필드 간 즉시 양방향 동기화
    if (notification.object == _mainOpenerTriggerKeyField) {
        [_openerTriggerKeyField setInputKey:_mainOpenerTriggerKeyField.inputKey];
    } else if (notification.object == _openerTriggerKeyField) {
        [_mainOpenerTriggerKeyField setInputKey:_openerTriggerKeyField.inputKey];
    }
    
    [self save];
}

#pragma mark Accessibility Management

- (void)updateAccessibilityStatusUI {
    BOOL isOk = [[D3EventTapService sharedService] isRunning] || AXIsProcessTrusted();
    if (isOk) {
        _accessibilityStatusLabel.stringValue = D3Loc(@"a11y_granted");
        _accessibilityStatusLabel.textColor = [NSColor systemGreenColor];
        _openSettingsBtn.hidden = YES;
        _retryA11yBtn.hidden = YES;
        _resetDefaultsBtn.hidden = NO;
    } else {
        _accessibilityStatusLabel.stringValue = D3Loc(@"a11y_needed");
        _accessibilityStatusLabel.textColor = [NSColor systemOrangeColor];
        _openSettingsBtn.hidden = NO;
        _retryA11yBtn.hidden = NO;
        _resetDefaultsBtn.hidden = YES;
    }
}

- (void)openAccessibilitySettings:(id)sender {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)retryAccessibility:(id)sender {
    if ([[D3EventTapService sharedService] startEventTap]) {
        [self updateAccessibilityStatusUI];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"손쉬운 사용 권한 설정 안내";
        alert.informativeText = @"시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에 이미 'DM_Helper'가 켜져 있는 경우:\n\n1. 시스템 설정의 손쉬운 사용 목록에서 'DM_Helper'를 클릭하여 선택합니다.\n2. 목록 하단의 '-' (제거) 버튼을 눌러 삭제합니다.\n3. '+' 버튼을 눌러 앱을 다시 추가하거나 목록 토글을 껐다 켜주세요.\n\n(macOS 보안 캐시로 인해 이전 버전 권한이 남아있을 때 발생하는 현상입니다.)";
        [alert addButtonWithTitle:@"시스템 설정 열기"];
        [alert addButtonWithTitle:@"확인"];
        [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            if (returnCode == NSAlertFirstButtonReturn) {
                [self openAccessibilitySettings:nil];
            }
        }];
    }
}

#pragma mark In-App Help & Guide Window

- (IBAction)showHelpWindow:(id)sender {
    if (_helpWindow == nil) {
        [self createHelpWindow];
    }
    [self updateHelpContentForCategory:_helpCategorySegment.selectedSegment];
    [_helpWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)createHelpWindow {
    NSRect frame = NSMakeRect(0, 0, 840, 650);
    _helpWindow = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled |
                                                         NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable |
                                                         NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    _helpWindow.title = D3Loc(@"guide_win_title");
    _helpWindow.minSize = NSMakeSize(760, 520);
    [_helpWindow center];
    
    NSView *contentView = _helpWindow.contentView;
    
    // 1. 상단 헤더: 앱 아이콘 + 타이틀
    NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(20, 595, 42, 42)];
    iconView.image = [NSImage imageNamed:NSImageNameApplicationIcon];
    [contentView addSubview:iconView];
    
    NSTextField *titleLabel = [self labelWithText:D3Loc(@"guide_header_title") frame:NSMakeRect(70, 615, 500, 24) bold:YES];
    titleLabel.font = [NSFont boldSystemFontOfSize:16];
    [contentView addSubview:titleLabel];
    
    NSTextField *subtitleLabel = [self labelWithText:D3Loc(@"guide_header_sub") frame:NSMakeRect(70, 595, 500, 18) bold:NO];
    subtitleLabel.textColor = [NSColor secondaryLabelColor];
    subtitleLabel.font = [NSFont systemFontOfSize:11];
    [contentView addSubview:subtitleLabel];
    
    // 2. 카테고리 탭 세그먼트
    _helpCategorySegment = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(20, 555, 800, 28)];
    _helpCategorySegment.segmentCount = 5;
    [_helpCategorySegment setLabel:D3Loc(@"guide_tab_0") forSegment:0];
    [_helpCategorySegment setLabel:D3Loc(@"guide_tab_1") forSegment:1];
    [_helpCategorySegment setLabel:D3Loc(@"guide_tab_2") forSegment:2];
    [_helpCategorySegment setLabel:D3Loc(@"guide_tab_3") forSegment:3];
    [_helpCategorySegment setLabel:D3Loc(@"guide_tab_4") forSegment:4];
    _helpCategorySegment.selectedSegment = 0;
    _helpCategorySegment.target = self;
    _helpCategorySegment.action = @selector(helpCategoryChanged:);
    _helpCategorySegment.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [contentView addSubview:_helpCategorySegment];
    
    // 3. 본문 텍스트 스크롤 뷰
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 55, 800, 490)];
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = NO;
    scrollView.autohidesScrollers = YES;
    scrollView.borderType = NSBezelBorder;
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    _helpTextView = [[NSTextView alloc] initWithFrame:scrollView.contentView.bounds];
    _helpTextView.editable = NO;
    _helpTextView.selectable = YES;
    _helpTextView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _helpTextView.textContainer.containerSize = NSMakeSize(scrollView.contentView.bounds.size.width, CGFLOAT_MAX);
    _helpTextView.textContainer.widthTracksTextView = YES;
    _helpTextView.textContainerInset = NSMakeSize(16, 16);
    
    scrollView.documentView = _helpTextView;
    [contentView addSubview:scrollView];
    
    // 4. 하단 버튼 바
    NSButton *openManualBtn = [[NSButton alloc] initWithFrame:NSMakeRect(20, 15, 260, 28)];
    openManualBtn.title = D3Loc(@"btn_open_manual_md");
    openManualBtn.bezelStyle = NSBezelStyleRounded;
    openManualBtn.target = self;
    openManualBtn.action = @selector(openManualFileAction:);
    openManualBtn.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
    [contentView addSubview:openManualBtn];
    
    NSButton *closeBtn = [[NSButton alloc] initWithFrame:NSMakeRect(725, 15, 95, 28)];
    closeBtn.title = D3Loc(@"btn_close");
    closeBtn.bezelStyle = NSBezelStyleRounded;
    closeBtn.target = _helpWindow;
    closeBtn.action = @selector(performClose:);
    closeBtn.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
    [contentView addSubview:closeBtn];
}

- (BOOL)isCurrentAppearanceDark {
    if (@available(macOS 10.14, *)) {
        NSAppearance *appr = _helpWindow.effectiveAppearance ?: [NSApp effectiveAppearance];
        NSAppearanceName match = [appr bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
        return [match isEqualToString:NSAppearanceNameDarkAqua];
    }
    return NO;
}

- (void)systemThemeChanged:(NSNotification *)note {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self->_helpWindow && self->_helpWindow.isVisible) {
            [self updateHelpContentForCategory:self->_helpCategorySegment.selectedSegment];
        }
    });
}

- (void)helpCategoryChanged:(id)sender {
    [self updateHelpContentForCategory:_helpCategorySegment.selectedSegment];
}

- (void)openManualFileAction:(id)sender {
    NSString *bundleManual = [[NSBundle mainBundle] pathForResource:@"MANUAL" ofType:@"md"];
    NSString *fallbackManual = @"/Users/ssh/Documents/Develope/mac-diablo-helper/MANUAL.md";
    NSString *path = (bundleManual && [[NSFileManager defaultManager] fileExistsAtPath:bundleManual]) ? bundleManual : fallbackManual;
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSWorkspace sharedWorkspace] openFile:path];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"매뉴얼 파일 안내";
        alert.informativeText = [NSString stringWithFormat:@"매뉴얼 파일 경로:\n%@", path];
        [alert addButtonWithTitle:@"확인"];
        [alert runModal];
    }
}

- (void)updateHelpContentForCategory:(NSInteger)categoryIndex {
    BOOL isDark = [self isCurrentAppearanceDark];
    
    // 라이트 / 다크 모드 맞춤 색상 팔레트
    NSString *bgColor = isDark ? @"#161b22" : @"#ffffff";
    NSString *textColor = isDark ? @"#e6edf3" : @"#24292f";
    NSString *strongColor = isDark ? @"#ffffff" : @"#000000";
    NSString *h2Color = isDark ? @"#ff7b72" : @"#c93b2b";
    NSString *h3Color = isDark ? @"#79c0ff" : @"#0969da";
    NSString *boxBg = isDark ? @"#21262d" : @"#f6f8fa";
    NSString *boxBorder = isDark ? @"#ff7b72" : @"#c93b2b";
    NSString *tblBorder = isDark ? @"#30363d" : @"#d0d7de";
    NSString *tblHeadBg = isDark ? @"#21262d" : @"#eaecef";
    NSString *tblHeadText = isDark ? @"#f0f6fc" : @"#1f2328";
    NSString *tblRowAltBg = isDark ? @"#1c2128" : @"#f6f8fa";
    NSString *codeBg = isDark ? @"#2d333b" : @"#eff1f3";
    NSString *codeColor = isDark ? @"#ff7b72" : @"#b32d20";
    
    // View 배경 및 텍스트 뷰 속성 동기화
    if (_helpTextView) {
        _helpTextView.drawsBackground = YES;
        _helpTextView.backgroundColor = isDark ? [NSColor colorWithCalibratedRed:0.09 green:0.11 blue:0.13 alpha:1.0] : [NSColor textBackgroundColor];
    }
    
    NSString *css = [NSString stringWithFormat:
        @"<style>"
        @"body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 13px; line-height: 1.6; color: %@; background-color: %@; margin: 0; padding: 4px; }"
        @"h2 { color: %@; border-bottom: 2px solid %@; padding-bottom: 6px; margin-top: 4px; }"
        @"h3 { color: %@; margin-top: 18px; margin-bottom: 8px; }"
        @"p, li { color: %@; }"
        @"b, strong { color: %@; }"
        @".callout { background-color: %@; border-left: 4px solid %@; padding: 12px; margin: 14px 0; border-radius: 4px; color: %@; }"
        @"table { border-collapse: collapse; width: 100%%; border: 1px solid %@; font-size: 12px; margin-top: 10px; }"
        @"th { background-color: %@; color: %@; border: 1px solid %@; padding: 8px; text-align: left; }"
        @"td { border: 1px solid %@; padding: 8px; color: %@; background-color: %@; }"
        @"tr:nth-child(even) td { background-color: %@; }"
        @"code { background-color: %@; color: %@; padding: 2px 5px; border-radius: 3px; font-family: ui-monospace, Menlo, monospace; font-size: 11.5px; }"
        @"</style>",
        textColor, bgColor,
        h2Color, h2Color,
        h3Color,
        textColor,
        strongColor,
        boxBg, boxBorder, textColor,
        tblBorder,
        tblHeadBg, tblHeadText, tblBorder,
        tblBorder, textColor, bgColor,
        tblRowAltBg,
        codeBg, codeColor
    ];
    
    BOOL isKorean = [D3LocalizationManager sharedManager].isKorean;
    NSString *bodyContent = @"";
    switch (categoryIndex) {
        case 0:
            if (isKorean) {
                bodyContent = @"<h2>⚡️ 3분 빠른 시작 (초보자 가이드)</h2>"
                              @"<p><b>DM_Helper</b>는 맥북 M1~M4 실리콘 및 Intel Mac 환경에서 디아블로 3와 디아블로 4를 가장 쾌적하게 즐길 수 있도록 제작된 초정밀 네이티브 게이밍 헬퍼입니다.</p>"
                              @"<div class='callout'>"
                              @"<b>1단계. 손쉬운 사용 권한 허용</b><br/>"
                              @"앱 최초 실행 시 <code>시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용</code>에서 <b>DM_Helper</b>를 허용합니다. (권한 허용 시 메인 창에 초록색 불 점등)<br/><br/>"
                              @"<b>2단계. 원클릭 직업 프리셋 선택</b><br/>"
                              @"상단바의 <b>[직업 프리셋 적용 ▼]</b> 드롭다운에서 본인의 캐릭터(예: <b>악마술사(타오르는 비명)</b>, <b>원소술사</b>, <b>야만용사</b> 등)를 선택합니다. 오프너와 주기가 최적값으로 자동 로드됩니다.<br/><br/>"
                              @"<b>3단계. 게임 화면에서 시작</b><br/>"
                              @"디아블로 창으로 전환한 후 시작키 <b>[</b> (대괄호 열기)를 누르면 'Tink' 효과음과 함께 오토가 시작됩니다. 중단할 때도 <b>[</b> 키를 누르면 즉시 정지('Pop' 효과음)됩니다."
                              @"</div>"
                              @"<h3>⌨️ 키 입력 & 단축키 조작법</h3>"
                              @"<ul>"
                              @"<li><b>키 등록</b>: 입력 필드를 클릭한 뒤 원하는 키보드 키, 마우스 휠(Up/Down), 사이드 버튼을 누르면 즉시 등록됩니다.</li>"
                              @"<li><b>키 삭제 (초기화)</b>: 입력 필드를 클릭한 뒤 <b>ESC</b> 키 또는 <b>Delete(Backspace)</b> 키를 누르거나, 우클릭 메뉴에서 <b>'설정 해제 (없음)'</b>을 선택하면 비워집니다.</li>"
                              @"<li><b>프로필 즉시 전환</b>: 숫자 1~5번 슬롯을 클릭하거나 게임 중 <b>F1 ~ F5</b> 키를 누르면 프로필이 즉시 교체됩니다.</li>"
                              @"</ul>";
            } else {
                bodyContent = @"<h2>⚡️ 3-Minute Quick Start Guide</h2>"
                              @"<p><b>DM_Helper</b> is a high-precision native gaming helper optimized for Apple Silicon (M1~M4) and Intel Macs to elevate your gameplay in Diablo 3 and Diablo 4.</p>"
                              @"<div class='callout'>"
                              @"<b>Step 1. Grant Accessibility Permission</b><br/>"
                              @"On first launch, allow <b>DM_Helper</b> in <code>System Settings > Privacy & Security > Accessibility</code>. (Green indicator turns on when granted)<br/><br/>"
                              @"<b>Step 2. Select One-Click Class Preset</b><br/>"
                              @"Choose your build from the <b>[Apply Class Preset ▼]</b> dropdown (e.g., <b>Warlock (Fiery Scream)</b>, <b>Sorcerer</b>, <b>Barbarian</b>, etc.). Opener, delays, and repeat rates are automatically configured.<br/><br/>"
                              @"<b>Step 3. Start in Game</b><br/>"
                              @"Switch to your Diablo window and press <b>[</b> (Left Bracket) to start with a 'Tink' sound. Press <b>[</b> again to stop anytime ('Pop' sound)."
                              @"</div>"
                              @"<h3>⌨️ Key Bindings & Shortcuts</h3>"
                              @"<ul>"
                              @"<li><b>Assign Key</b>: Click an input field and press any keyboard key, scroll mouse wheel (Up/Down), or side buttons (XButton 1/2).</li>"
                              @"<li><b>Clear Key</b>: Press <b>ESC</b> or <b>Delete(Backspace)</b>, or right-click and choose <b>'Clear (None)'</b>.</li>"
                              @"<li><b>Switch Profile</b>: Click slots 1~5 or press <b>F1 ~ F5</b> during gameplay.</li>"
                              @"</ul>";
            }
            break;
            
        case 1:
            if (isKorean) {
                bodyContent = @"<h2>🎮 디아블로 4 직업별 맞춤 프리셋 & 구글 시트 공유</h2>"
                              @"<p>상단바의 <b>[직업 프리셋 적용 ▼]</b> 또는 <b>[🌐 시트 공유]</b> 버튼에서 클릭 한 번으로 공인 및 유저 커뮤니티 빌드를 바로 불러올 수 있습니다.</p>"
                              @"<div class='callout'>"
                              @"<b>🌐 구글 시트 프리셋 공유 센터</b><br/>"
                              @"• 상단바 <b>[🌐 시트 공유]</b>를 클릭하면 유저별, 시즌별, 직업/빌드별 공인 세팅을 실시간 검색하고 원하는 슬롯(1~5)으로 즉시 가져올 수 있습니다.<br/>"
                              @"• 내가 완성한 커스텀 세팅도 <b>[📤 현재 내 설정 시트에 공유...]</b> 버튼으로 원클릭 등록 및 행 복사 공유가 가능합니다.<br/>"
                              @"• 클랜/길드 전용 비공개 구글 시트가 있다면 <b>[⚙️ 시트 설정]</b>에서 시트 URL을 등록해 팀원들과 전용 빌드를 공유하세요."
                              @"</div>"
                              @"<table>"
                              @"<tr><th style='width: 25%;'>직업 / 빌드</th><th style='width: 35%;'>핵심 메커니즘</th><th style='width: 40%;'>DM_Helper 자동 동작 구성</th></tr>"
                              @"<tr><td><b>🔥 악마술사</b><br/>(타오르는 비명)</td><td><b>나락 150단 오토봄버</b><br/>소환수 활성화 → 탈태(변신) 지배력 버프 → 감옥 CC → 타오르는 비명 무한 난사</td><td>• <b>오프너</b>: 1단계 아보디안 소환 → 2단계 탈태 → 3단계 어둠의 감옥 → 4단계 인장<br/>• <b>본 루프</b>: 탈태/감옥 쿨타임 유지 + <b>우클릭(타오르는 비명) 120ms 고속 연타</b></td></tr>"
                              @"<tr><td><b>🔮 원소술사</b><br/>(번개창/탈라샤)</td><td><b>보호막 & 4원소 탈라샤 스택</b><br/>보호막 켜고 평타 3회로 4원소 스택 적재 후 본 공격</td><td>• <b>오프너</b>: 얼음갑옷 → 순간이동 → 번개창 → 기본기 3회 스택<br/>• <b>본 루프</b>: 보호막/순간이동 쿨마다 유지 + 주력 스킬 자동 순환</td></tr>"
                              @"<tr><td><b>⚔️ 야만용사</b><br/>(소용돌이 채널링)</td><td><b>3함성 분노 폭발 & 소용돌이 지속 회전</b></td><td>• <b>오프너</b>: 집결/도전/전장 3함성 순차 시전<br/>• <b>본 루프</b>: 3함성 쿨마다 유지 + <b>우클릭(소용돌이) [홀드(누름)] 모드</b></td></tr>"
                              @"<tr><td><b>🏹 도적</b><br/>(3콤보 포인트)</td><td><b>3:1 연계 콤보 사이클</b><br/>기본기 3회로 콤보 포인트 충전 후 핵심기 1회 방출</td><td>• <b>오프너</b>: 암흑 주입 → 그림자 걸음 진입<br/>• <b>콤보 루프</b>: 생성기(3번) 3회 ↔ 소모기(우클릭) 1회 자동 교대 (130ms)</td></tr>"
                              @"<tr><td><b>💀 강령술사</b><br/>(시폭 & 뼈창)</td><td><b>골렘/저주 군중제어 & 시폭/뼈창 폭딜</b></td><td>• <b>오프너</b>: 골렘 활성화 → 노화 저주 광역 살포 → 시체 촉수<br/>• <b>본 루프</b>: 뼈창(200ms) + 시체 폭발(120ms) 고속 연타</td></tr>"
                              @"<tr><td><b>🦅 혼령사</b><br/>(태세 & 제압)</td><td><b>태세 버프 & 결의 스택 제압 사이클</b></td><td>• <b>오프너</b>: 태세 버프 가동 → 결의 스택 누적<br/>• <b>콤보 루프</b>: 깃털 투척 3회 ↔ 제압기 1회 (140ms) 교대</td></tr>"
                              @"</table>";
            } else {
                bodyContent = @"<h2>🎮 Diablo 4 Class Presets & Google Sheets Hub</h2>"
                              @"<p>Quickly load official and community meta builds with one click from <b>[Apply Class Preset ▼]</b> or <b>[🌐 Sheet Hub]</b>.</p>"
                              @"<div class='callout'>"
                              @"<b>🌐 Google Sheets Preset Hub</b><br/>"
                              @"• Click <b>[🌐 Sheet Hub]</b> to search community builds by user, season, or class and load directly into slots 1~5.<br/>"
                              @"• Share your custom settings via <b>[📤 Share My Preset to Sheet...]</b> or copy TSV row data with Cmd+V.<br/>"
                              @"• Connect your private clan/guild spreadsheet via <b>[⚙️ Sheet Settings]</b>."
                              @"</div>"
                              @"<table>"
                              @"<tr><th style='width: 25%;'>Class / Build</th><th style='width: 35%;'>Core Mechanics</th><th style='width: 40%;'>DM_Helper Automation</th></tr>"
                              @"<tr><td><b>🔥 Warlock</b><br/>(Fiery Scream)</td><td><b>Pit Tier 150 Auto-Bomber</b><br/>Summon Abodion → Metamorphosis dominance buff → Prison CC → Spam Fiery Scream</td><td>• <b>Opener</b>: 1. Abodion → 2. Metamorphosis → 3. Prison → 4. Sigil<br/>• <b>Loop</b>: Maintain cooldowns + <b>Right-click 120ms high-speed spam</b></td></tr>"
                              @"<tr><td><b>🔮 Sorcerer</b><br/>(Lightning Spear)</td><td><b>Barrier & 4-Element Stacks</b><br/>Activate barrier, stack 4 elements with 3 basic hits, unleash</td><td>• <b>Opener</b>: Ice Armor → Teleport → Lightning Spear → 3x Fire Bolt<br/>• <b>Loop</b>: Keep barrier/teleport on CD + auto chain skill rotation</td></tr>"
                              @"<tr><td><b>⚔️ Barbarian</b><br/>(Whirlwind Channel)</td><td><b>3 Warcries & Continuous Spin</b></td><td>• <b>Opener</b>: Rallying / Challenging / War Cry in sequence<br/>• <b>Loop</b>: Recast shouts on CD + <b>Right-click [Hold Mode]</b></td></tr>"
                              @"<tr><td><b>🏹 Rogue</b><br/>(3 Combo Points)</td><td><b>3:1 Combo Cycle</b><br/>3 basic punctures to fill combo points, 1 core skill release</td><td>• <b>Opener</b>: Shadow Imbuement → Shadow Step<br/>• <b>Combo Loop</b>: Generator 3x ↔ Spender 1x auto alternating (130ms)</td></tr>"
                              @"<tr><td><b>💀 Necromancer</b><br/>(Bone Spear & CE)</td><td><b>Golem/Curse CC & Explosive Burst</b></td><td>• <b>Opener</b>: Golem → Decrepify AoE → Corpse Tendrils<br/>• <b>Loop</b>: Bone Spear (200ms) + Corpse Explosion (120ms)</td></tr>"
                              @"<tr><td><b>🦅 Spiritborn</b><br/>(Aspect & Overpower)</td><td><b>Stance Buff & Resolve Overpower</b></td><td>• <b>Opener</b>: Stance activation → Resolve accumulation<br/>• <b>Combo Loop</b>: 3x Feather ↔ 1x Overpower strike (140ms)</td></tr>"
                              @"</table>";
            }
            break;
            
        case 2:
            if (isKorean) {
                bodyContent = @"<h2>🔄 로테이션 & 준비 시퀀스 가이드</h2>"
                              @"<h3>1. 초기 준비 시퀀스 (Opener & Ramp-up)</h3>"
                              @"<p>사냥을 시작할 때 버프를 켜고, 변신을 하고, 평타 3대로 스택을 쌓는 과정을 자동으로 실행합니다.</p>"
                              @"<ul>"
                              @"<li><b>메인 화면 원터치 키 설정</b>: 첫 번째 [기본 헬퍼] 화면의 <b>[시작 / 종료 & 준비 시퀀스 키]</b> 박스에서 '준비 키'와 '사용' 체크박스로 언제든 단축키를 설정하고 On/Off 할 수 있습니다.</li>"
                              @"<li><b>스텝 구성 (최대 5단계)</b>: 스킬 키 + 실행 간격(ms) + 반복 횟수(1~10회, 15/20/30회) + 메모</li>"
                              @"<li><b>작동 원리</b>: 시작키(또는 상단 <b>[⚡️ 준비 시퀀스]</b> 버튼)를 누르면 1~5단계를 순차 완료한 뒤 본 전투 루프로 자동 전환됩니다.</li>"
                              @"<li><b>수동 트리거 키 (F1 등)</b>: 전투 중 버프가 꺼지거나 보스전에 진입했을 때 누르면 즉시 오프너를 1회 재실행합니다.</li>"
                              @"</ul>"
                              @"<h3>2. 스킬 연계 콤보 사이클 (Generator-to-Spender)</h3>"
                              @"<p>도적의 3콤보 포인트(구멍 뚫기 3회 → 회전 칼날 1회), 야만용사의 분노 생성/소모 빌드처럼 두 스킬을 정해진 비율로 번갈아 시전합니다.</p>"
                              @"<ul>"
                              @"<li><b>스택 생성기 (A)</b>: N회 시전 (예: 3회)</li>"
                              @"<li><b>핵심 소모기 (B)</b>: M회 시전 (예: 1회)</li>"
                              @"<li>지정된 주기(ms)마다 A와 B를 칼같이 교대하여 스킬 낭비와 모션 캔슬을 방지합니다.</li>"
                              @"</ul>"
                              @"<h3>3. 스킬 시전 방식 (연타 vs 홀드/채널링)</h3>"
                              @"<ul>"
                              @"<li><b>연타 (Spam)</b>: 주기마다 키를 눌렀다 뗌 (일반 스킬, 쿨다운 스킬)</li>"
                              @"<li><b>홀드(누름) (Hold)</b>: 헬퍼 활성 시 키 다운 유지 (야만용사 <b>소용돌이</b>, 원소술사 <b>소각</b> 등 지속 채널링)</li>"
                              @"</ul>";
            } else {
                bodyContent = @"<h2>🔄 Rotation & Opener Sequence Guide</h2>"
                              @"<h3>1. Opener & Ramp-up Sequence</h3>"
                              @"<p>Automatically triggers preparatory buffs, transformations, and stack builders before engaging in the main combat loop.</p>"
                              @"<ul>"
                              @"<li><b>One-Touch Setup on Tab 1</b>: Configure the Opener Key and toggle 'Enable' right from the main Basic Helper tab.</li>"
                              @"<li><b>Up to 5 Steps</b>: Skill key + execution delay(ms) + repeat count (1~10, 15, 20, 30) + memo.</li>"
                              @"<li><b>How it works</b>: Pressing start (or the top <b>[⚡️ Opener]</b> button) executes steps 1~5 in sequence then transitions to continuous combat.</li>"
                              @"<li><b>Manual Trigger Key (F1)</b>: Re-trigger opener anytime mid-combat when buffs expire or upon entering boss rooms.</li>"
                              @"</ul>"
                              @"<h3>2. Skill Combo Cycle (Generator-to-Spender)</h3>"
                              @"<p>Alternates between building resource/stacks and expending them (e.g. Rogue 3:1 combo points, Barbarian fury gen/spend).</p>"
                              @"<ul>"
                              @"<li><b>Stack Generator (A)</b>: Cast N times (e.g., 3)</li>"
                              @"<li><b>Core Spender (B)</b>: Cast M times (e.g., 1)</li>"
                              @"<li>Strictly timed alternation prevents skill clipping and wasted attacks.</li>"
                              @"</ul>"
                              @"<h3>3. Cast Modes (Spam vs Hold)</h3>"
                              @"<ul>"
                              @"<li><b>Spam</b>: Rapid key press and release every interval (regular attacks, cooldown skills).</li>"
                              @"<li><b>Hold (Channel)</b>: Keeps key continuously held down while helper is active (Whirlwind, Incinerate).</li>"
                              @"</ul>";
            }
            break;
            
        case 3:
            if (isKorean) {
                bodyContent = @"<h2>💎 DHelper 정통 편의 기능 안내</h2>"
                              @"<h3>1. 단일반복키 (최대 3개, 독립 루프)</h3>"
                              @"<p>메인 헬퍼 활성화 여부와 상관없이 <b>누르고 있는 동안만 초고속 동작</b>합니다.</p>"
                              @"<ul>"
                              @"<li><b>1번 기본값 (Grave `~`)</b>: 마우스 좌클릭 50ms ➡️ 바닥 아이템 자동 폭풍 줍기, 신단 클릭, 포탈 진입</li>"
                              @"<li><b>2번 기본값 (Tab)</b>: 마우스 우클릭 60ms ➡️ 카달라 수수께끼 상점 핏빛 파편 대량 겜블 (1초 만에 가방 가득 구매)</li>"
                              @"</ul>"
                              @"<h3>2. 특수키 (최대 3개) & 쿨타임 대기</h3>"
                              @"<ul>"
                              @"<li>누르고 있는 동안 <b>체크박스에 체크된 스킬의 자동 시전을 일시 정지</b>합니다.</li>"
                              @"<li><b>쿨타임 대기 체크 시</b>: 키를 뗐을 때 남은 잔여 쿨타임을 기다렸다가 재개 (버프 주기 엄격 유지)</li>"
                              @"<li><b>쿨타임 대기 해제 시</b>: 키를 떼자마자 즉시 1회 시전 후 원래 주기 재개</li>"
                              @"</ul>"
                              @"<h3>3. 퀘스트키 & 시간조절키</h3>"
                              @"<ul>"
                              @"<li><b>퀘스트키</b>: NPC와 대화하거나 대장장이/비술사 메뉴를 볼 때 누르면 모든 스킬 전면 정지 (창 닫힘 방지)</li>"
                              @"<li><b>시간조절키 (신단 토글)</b>: 도관/쿨감 신단을 먹었을 때 1회 누르면 전 스킬 주기가 가속(오프셋 ms)되며, 끝나면 다시 눌러 복귀</li>"
                              @"</ul>"
                              @"<h3>4. 안전 시스템</h3>"
                              @"<ul>"
                              @"<li><b>인게임 8대 UI 연동 종료</b>: 가방(I), 스킬(S), 지도(M), 포탈(T), 채팅(Enter) 오픈 시 헬퍼 즉시 자동 정지</li>"
                              @"<li><b>방해금지 데드존</b>: 하단 스킬바, 자원 구슬 영역에 마우스가 있으면 좌클릭 입력을 자동으로 건너뜁니다.</li>"
                              @"</ul>";
            } else {
                bodyContent = @"<h2>💎 DHelper Classic Utility Features</h2>"
                              @"<h3>1. Single Repeat Keys (Up to 3, Independent Loops)</h3>"
                              @"<p>Fires at ultra-high speed <b>only while held</b>, regardless of whether the main helper is running.</p>"
                              @"<ul>"
                              @"<li><b>Slot 1 Default (Grave `~`)</b>: Left-click 50ms ➡️ vacuum loot floor items, shrines, town portals.</li>"
                              @"<li><b>Slot 2 Default (Tab)</b>: Right-click 60ms ➡️ mass Kadala gambling (fill inventory in 1 second).</li>"
                              @"</ul>"
                              @"<h3>2. Special Keys & Cooldown Delay</h3>"
                              @"<ul>"
                              @"<li>Pauses automated casting of checked skills while the special key is held.</li>"
                              @"<li><b>With 'After CD' checked</b>: Waits for remaining cooldown on key release to preserve buff timing.</li>"
                              @"<li><b>Without 'After CD'</b>: Fires once immediately upon release.</li>"
                              @"</ul>"
                              @"<h3>3. Quest Key & Speed Modifier</h3>"
                              @"<ul>"
                              @"<li><b>Quest Key</b>: Pauses all skills when talking to NPCs or viewing blacksmith/occultist menus.</li>"
                              @"<li><b>Speed Modifier (Pylon Toggle)</b>: Accelerates all skill timers when grabbing conduit/channeling pylons.</li>"
                              @"</ul>"
                              @"<h3>4. Safety & Protection</h3>"
                              @"<ul>"
                              @"<li><b>8 In-game UI Pause Keys</b>: Automatically pauses when inventory, map, portal, or chat opens.</li>"
                              @"<li><b>Anti-Disturbance Deadzone</b>: Skips left clicks when cursor is over bottom skillbars or resource orbs.</li>"
                              @"</ul>";
            }
            break;
            
        case 4:
            if (isKorean) {
                bodyContent = @"<h2>🛡 보안 권한 설정 및 자주 묻는 질문 (FAQ)</h2>"
                              @"<h3>Q1. 시작키를 눌렀는데 게임에서 아무 반응이 없어요.</h3>"
                              @"<ol>"
                              @"<li><b>최전면 창 확인</b>: 헬퍼는 외부 앱에 키가 유출되지 않도록 디아블로 창이 최전면일 때만 작동합니다. 게임 화면을 클릭 후 시작키를 누르세요.</li>"
                              @"<li><b>손쉬운 사용 권한 재등록 (가장 흔한 해결법)</b>:<br/>"
                              @"• macOS 업데이트나 앱 파일 교체 시 보안 캐시 문제로 권한이 풀릴 수 있습니다.<br/>"
                              @"• <code>시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용</code>으로 이동합니다.<br/>"
                              @"• 목록에서 <b>DM_Helper</b>를 선택하고 <b>[-] (제거)</b> 버튼을 눌러 완전히 삭제합니다.<br/>"
                              @"• <b>[+]</b> 버튼을 눌러 <code>/Applications/DM_Helper.app</code>을 다시 추가하거나 우측 스위치를 껐다 켭니다.</li>"
                              @"</ol>"
                              @"<h3>Q2. 마우스 휠이나 사이드 버튼도 단축키로 쓸 수 있나요?</h3>"
                              @"<p>네! 키 입력칸을 클릭한 후 마우스 휠을 위/아래로 굴리거나 사이드 버튼을 누르면 <code>Wheel Up</code>, <code>Wheel Down</code>, <code>XButton 1</code> 등으로 완벽히 등록됩니다.</p>"
                              @"<h3>Q3. 시작키와 종료키를 따로 쓰거나 하나로 쓸 수 있나요?</h3>"
                              @"<p>시작키와 종료키를 동일하게 설정(기본값: 둘 다 <code>[</code>)하면 원버튼 On/Off 토글로 동작합니다. 분리하고 싶다면 종료키에 다른 키를 입력하시면 됩니다.</p>"
                              @"<h3>Q4. 프로필 파일 백업 및 공유</h3>"
                              @"<p>상단의 <b>[저장하기]</b> 버튼을 누르면 현재 설정을 <code>.dhp</code> 또는 <code>.json</code> 파일로 내보낼 수 있으며, <b>[불러오기]</b>로 언제든 복원할 수 있습니다.</p>";
            } else {
                bodyContent = @"<h2>🛡 Security Permission & FAQ</h2>"
                              @"<h3>Q1. Nothing happens when I press the start key in game.</h3>"
                              @"<ol>"
                              @"<li><b>Active Window</b>: Helper only sends keys when Diablo is the frontmost window to prevent key leakage.</li>"
                              @"<li><b>Reset Accessibility Permission (Most common fix)</b>:<br/>"
                              @"• Open <code>System Settings > Privacy & Security > Accessibility</code>.<br/>"
                              @"• Select <b>DM_Helper</b> and click <b>[-] (Remove)</b> to completely delete it.<br/>"
                              @"• Click <b>[+]</b> to re-add <code>/Applications/DM_Helper.app</code> or toggle the switch.</li>"
                              @"</ol>"
                              @"<h3>Q2. Can I use mouse wheel or side buttons as shortcuts?</h3>"
                              @"<p>Yes! Click an input field and scroll wheel or press side buttons to bind <code>Wheel Up</code>, <code>Wheel Down</code>, <code>XButton 1</code>, etc.</p>"
                              @"<h3>Q3. Can start and stop keys be the same?</h3>"
                              @"<p>Yes. Setting both to the same key makes it a toggle switch. Set them differently if you prefer dedicated On/Off keys.</p>"
                              @"<h3>Q4. Profile backup and restore</h3>"
                              @"<p>Use <b>[Export]</b> to save configurations as <code>.dhp</code> or <code>.json</code>, and <b>[Import]</b> to restore anytime.</p>";
            }
            break;
    }
    
    NSString *fullHtml = [NSString stringWithFormat:@"%@<body>%@</body>", css, bodyContent];
    
    NSAttributedString *attrStr = [[NSAttributedString alloc] initWithData:[fullHtml dataUsingEncoding:NSUTF8StringEncoding]
                                                                   options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                                                             NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)}
                                                        documentAttributes:nil
                                                                     error:nil];
    if (attrStr) {
        [_helpTextView.textStorage setAttributedString:attrStr];
        [_helpTextView scrollRangeToVisible:NSMakeRange(0, 0)];
    }
}

@end
