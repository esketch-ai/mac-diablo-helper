//
//  D3PresetShareWindowController.m
//  DM_Helper
//
//  Created by sunghyuk on 2026. 9. 29.
//  Copyright © 2026 sunghyuk. All rights reserved.
//

#import "D3PresetShareWindowController.h"
#import "D3GoogleSheetService.h"
#import "D3LocalizationManager.h"
#import <objc/runtime.h>

@interface D3PresetShareWindowController ()

@property (nonatomic, strong) NSPopUpButton *seasonPopUp;
@property (nonatomic, strong) NSPopUpButton *classPopUp;
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSTextView *detailTextView;
@property (nonatomic, strong) NSPopUpButton *targetSlotPopUp;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSArray<D3PresetItem *> *displayedPresets;

@end

@implementation D3PresetShareWindowController

+ (instancetype)sharedController {
    static D3PresetShareWindowController *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[D3PresetShareWindowController alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super initWithWindow:nil];
    if (self) {
        _displayedPresets = [NSArray array];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(presetsChangedNotification:)
                                                     name:kD3GoogleSheetPresetsChangedNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)showWindowAndRefresh:(id)sender {
    if (!self.window) {
        [self createShareWindow];
    }
    
    if (self.delegate) {
        NSInteger curSlot = [self.delegate currentActiveSlot];
        if (curSlot >= 1 && curSlot <= 5) {
            [_targetSlotPopUp selectItemAtIndex:(curSlot - 1)];
        }
    }
    
    [self.window center];
    [self.window makeKeyAndOrderFront:sender];
    [NSApp activateIgnoringOtherApps:YES];
    
    [self reloadDataFromService];
    [self refreshRemotePresets:nil];
}

- (void)createShareWindow {
    NSRect frame = NSMakeRect(0, 0, 960, 680);
    NSWindow *win = [[NSWindow alloc] initWithContentRect:frame
                                                styleMask:(NSWindowStyleMaskTitled |
                                                           NSWindowStyleMaskClosable |
                                                           NSWindowStyleMaskMiniaturizable |
                                                           NSWindowStyleMaskResizable)
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    win.title = D3Loc(@"sheet_win_title");
    win.minSize = NSMakeSize(880, 580);
    self.window = win;
    
    NSView *root = win.contentView;
    BOOL isKorean = [D3LocalizationManager sharedManager].isKorean;
    
    // -------------------------------------------------------------
    // 1. 헤더: 아이콘, 타이틀, 우측 버튼
    // -------------------------------------------------------------
    NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(20, 622, 42, 42)];
    iconView.image = [NSImage imageNamed:NSImageNameApplicationIcon];
    [root addSubview:iconView];
    
    NSTextField *titleLabel = [self labelWithText:D3Loc(@"sheet_header_title") frame:NSMakeRect(70, 640, 400, 22) bold:YES fontSize:16];
    [root addSubview:titleLabel];
    
    NSTextField *subLabel = [self labelWithText:D3Loc(@"sheet_header_sub") frame:NSMakeRect(70, 622, 600, 18) bold:NO fontSize:11];
    subLabel.textColor = [NSColor secondaryLabelColor];
    [root addSubview:subLabel];
    
    NSButton *openWebBtn = [[NSButton alloc] initWithFrame:NSMakeRect(720, 628, 115, 28)];
    openWebBtn.title = D3Loc(@"btn_open_web");
    openWebBtn.bezelStyle = NSBezelStyleRounded;
    openWebBtn.target = self;
    openWebBtn.action = @selector(openSheetInBrowserAction:);
    openWebBtn.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    [root addSubview:openWebBtn];
    
    NSButton *settingsBtn = [[NSButton alloc] initWithFrame:NSMakeRect(840, 628, 100, 28)];
    settingsBtn.title = D3Loc(@"btn_sheet_settings");
    settingsBtn.bezelStyle = NSBezelStyleRounded;
    settingsBtn.target = self;
    settingsBtn.action = @selector(openSettingsSheetAction:);
    settingsBtn.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
    [root addSubview:settingsBtn];
    
    // -------------------------------------------------------------
    // 2. 필터 바 (시즌 선택, 직업 선택, 검색창, 새로고침)
    // -------------------------------------------------------------
    NSBox *filterBox = [[NSBox alloc] initWithFrame:NSMakeRect(20, 568, 920, 48)];
    filterBox.titlePosition = NSNoTitle;
    filterBox.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [root addSubview:filterBox];
    
    _seasonPopUp = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(10, 10, 150, 26) pullsDown:NO];
    NSArray *seasons = isKorean ? @[@"시즌: 전체", @"시즌 6", @"시즌 7", @"시즌 8", @"영원", @"디아블로 3"] :
                                  @[@"Season: All", @"Season 6", @"Season 7", @"Season 8", @"Eternal", @"Diablo 3"];
    [_seasonPopUp addItemsWithTitles:seasons];
    _seasonPopUp.target = self;
    _seasonPopUp.action = @selector(filterChanged:);
    [filterBox.contentView addSubview:_seasonPopUp];
    
    _classPopUp = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(165, 10, 140, 26) pullsDown:NO];
    NSArray *classes = isKorean ? @[@"직업: 전체", @"악마술사", @"원소술사", @"야만용사", @"도적", @"강령술사", @"혼령사", @"드루이드", @"디아3 전직업"] :
                                  @[@"Class: All", @"Warlock", @"Sorcerer", @"Barbarian", @"Rogue", @"Necromancer", @"Spiritborn", @"Druid", @"D3 All"];
    [_classPopUp addItemsWithTitles:classes];
    _classPopUp.target = self;
    _classPopUp.action = @selector(filterChanged:);
    [filterBox.contentView addSubview:_classPopUp];
    
    _searchField = [[NSSearchField alloc] initWithFrame:NSMakeRect(315, 12, 470, 24)];
    _searchField.placeholderString = D3Loc(@"search_placeholder");
    _searchField.delegate = self;
    _searchField.autoresizingMask = NSViewWidthSizable;
    [filterBox.contentView addSubview:_searchField];
    
    NSButton *refreshBtn = [[NSButton alloc] initWithFrame:NSMakeRect(795, 10, 110, 26)];
    refreshBtn.title = D3Loc(@"btn_refresh");
    refreshBtn.bezelStyle = NSBezelStyleRounded;
    refreshBtn.target = self;
    refreshBtn.action = @selector(refreshRemotePresets:);
    refreshBtn.autoresizingMask = NSViewMinXMargin;
    [filterBox.contentView addSubview:refreshBtn];
    
    // -------------------------------------------------------------
    // 3. 메인 프리셋 목록 테이블 뷰
    // -------------------------------------------------------------
    NSScrollView *tableScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 230, 920, 330)];
    tableScroll.hasVerticalScroller = YES;
    tableScroll.hasHorizontalScroller = YES;
    tableScroll.autohidesScrollers = YES;
    tableScroll.borderType = NSBezelBorder;
    tableScroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    _tableView = [[NSTableView alloc] initWithFrame:tableScroll.contentView.bounds];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 24.0;
    _tableView.usesAlternatingRowBackgroundColors = YES;
    _tableView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    NSArray *colInfo = @[
        @{@"id": @"season", @"title": D3Loc(@"col_season"), @"width": @95},
        @{@"id": @"class", @"title": D3Loc(@"col_class"), @"width": @85},
        @{@"id": @"build", @"title": D3Loc(@"col_build"), @"width": @230},
        @{@"id": @"author", @"title": D3Loc(@"col_author"), @"width": @110},
        @{@"id": @"date", @"title": D3LocDef(@"col_date", @"등록일"), @"width": @90},
        @{@"id": @"desc", @"title": D3LocDef(@"col_desc", @"상세 설명 / 운용 요약"), @"width": @290}
    ];
    
    for (NSDictionary *info in colInfo) {
        NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:info[@"id"]];
        col.title = info[@"title"];
        col.width = [info[@"width"] doubleValue];
        [_tableView addTableColumn:col];
    }
    
    tableScroll.documentView = _tableView;
    [root addSubview:tableScroll];
    
    // -------------------------------------------------------------
    // 4. 하단 상세 정보 카드 (Detail Preview)
    // -------------------------------------------------------------
    NSBox *previewBox = [[NSBox alloc] initWithFrame:NSMakeRect(20, 58, 920, 165)];
    previewBox.title = isKorean ? @"선택된 프리셋 구성 미리보기 & 빌드 상세" : @"Selected Preset Preview & Build Details";
    previewBox.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    [root addSubview:previewBox];
    
    NSScrollView *detailScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 8, 898, 130)];
    detailScroll.hasVerticalScroller = YES;
    detailScroll.autohidesScrollers = YES;
    detailScroll.borderType = NSNoBorder;
    detailScroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    _detailTextView = [[NSTextView alloc] initWithFrame:detailScroll.contentView.bounds];
    _detailTextView.editable = NO;
    _detailTextView.selectable = YES;
    _detailTextView.font = [NSFont systemFontOfSize:12];
    _detailTextView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    detailScroll.documentView = _detailTextView;
    [previewBox.contentView addSubview:detailScroll];
    
    // -------------------------------------------------------------
    // 5. 하단 액션 버튼 바
    // -------------------------------------------------------------
    NSTextField *slotLabel = [self labelWithText:D3Loc(@"label_target_slot") frame:NSMakeRect(20, 19, 140, 20) bold:YES fontSize:12];
    [root addSubview:slotLabel];
    
    _targetSlotPopUp = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(165, 16, 95, 26) pullsDown:NO];
    for (NSInteger s = 1; s <= 5; s++) {
        [_targetSlotPopUp addItemWithTitle:[NSString stringWithFormat:D3Loc(@"slot_format"), (long)s]];
    }
    [root addSubview:_targetSlotPopUp];
    
    NSButton *importBtn = [[NSButton alloc] initWithFrame:NSMakeRect(268, 15, 195, 28)];
    importBtn.title = D3Loc(@"btn_import_helper");
    importBtn.bezelStyle = NSBezelStyleRounded;
    importBtn.font = [NSFont boldSystemFontOfSize:12];
    importBtn.target = self;
    importBtn.action = @selector(importSelectedPresetAction:);
    [root addSubview:importBtn];
    
    _statusLabel = [self labelWithText:@"" frame:NSMakeRect(470, 20, 160, 20) bold:NO fontSize:11];
    _statusLabel.textColor = [NSColor secondaryLabelColor];
    [root addSubview:_statusLabel];
    
    NSButton *shareCurrentBtn = [[NSButton alloc] initWithFrame:NSMakeRect(635, 15, 175, 28)];
    shareCurrentBtn.title = D3Loc(@"btn_share_preset");
    shareCurrentBtn.bezelStyle = NSBezelStyleRounded;
    shareCurrentBtn.target = self;
    shareCurrentBtn.action = @selector(openShareModalAction:);
    shareCurrentBtn.autoresizingMask = NSViewMinXMargin;
    [root addSubview:shareCurrentBtn];
    
    NSButton *copyRowBtn = [[NSButton alloc] initWithFrame:NSMakeRect(815, 15, 125, 28)];
    copyRowBtn.title = D3Loc(@"btn_copy_tsv");
    copyRowBtn.toolTip = D3Loc(@"btn_copy_tsv_tooltip");
    copyRowBtn.bezelStyle = NSBezelStyleRounded;
    copyRowBtn.target = self;
    copyRowBtn.action = @selector(copySelectedRowAction:);
    copyRowBtn.autoresizingMask = NSViewMinXMargin;
    [root addSubview:copyRowBtn];
}

#pragma mark Filtering & Data

- (void)reloadDataFromService {
    NSString *season = _seasonPopUp.titleOfSelectedItem;
    if ([season isEqualToString:@"시즌: 전체"]) season = @"전체";
    
    NSString *charClass = _classPopUp.titleOfSelectedItem;
    if ([charClass isEqualToString:@"직업: 전체"]) charClass = @"전체";
    
    NSString *kw = _searchField.stringValue;
    
    _displayedPresets = [[D3GoogleSheetService sharedService] filterPresetsWithSeason:season
                                                                     characterClass:charClass
                                                                            keyword:kw];
    [_tableView reloadData];
    
    if (_displayedPresets.count > 0) {
        [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        [self updateDetailPreviewForPreset:_displayedPresets[0]];
    } else {
        _detailTextView.string = @"검색 조건에 맞는 프리셋이 없습니다.";
    }
}

- (void)filterChanged:(id)sender {
    [self reloadDataFromService];
}

- (void)controlTextDidChange:(NSNotification *)obj {
    if (obj.object == _searchField) {
        [self reloadDataFromService];
    }
}

- (void)presetsChangedNotification:(NSNotification *)note {
    [self reloadDataFromService];
}

- (void)refreshRemotePresets:(id)sender {
    _statusLabel.stringValue = @"동기화 중...";
    [[D3GoogleSheetService sharedService] fetchPresetsWithCompletion:^(NSArray<D3PresetItem *> *presets, NSError *error) {
        if (!error) {
            self->_statusLabel.stringValue = [NSString stringWithFormat:@"동기화 완료 (%lu건)", (unsigned long)presets.count];
        } else {
            self->_statusLabel.stringValue = @"오프라인/캐시 목록 표시 중";
        }
        [self reloadDataFromService];
    }];
}

#pragma mark NSTableViewDataSource & Delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _displayedPresets.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row < 0 || row >= _displayedPresets.count) return nil;
    D3PresetItem *item = _displayedPresets[row];
    
    NSString *ident = tableColumn.identifier;
    NSTextField *cell = [tableView makeViewWithIdentifier:ident owner:self];
    if (!cell) {
        cell = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, 24)];
        cell.identifier = ident;
        cell.editable = NO;
        cell.bordered = NO;
        cell.backgroundColor = [NSColor clearColor];
        cell.lineBreakMode = NSLineBreakByTruncatingTail;
    }
    
    if ([ident isEqualToString:@"season"]) {
        cell.stringValue = item.season ?: @"";
        cell.font = [NSFont systemFontOfSize:11];
    } else if ([ident isEqualToString:@"class"]) {
        cell.stringValue = item.characterClass ?: @"";
        cell.font = [NSFont boldSystemFontOfSize:11];
    } else if ([ident isEqualToString:@"build"]) {
        cell.stringValue = item.buildName ?: @"";
        cell.font = [NSFont boldSystemFontOfSize:12];
    } else if ([ident isEqualToString:@"author"]) {
        cell.stringValue = item.author ?: @"";
        cell.font = [NSFont systemFontOfSize:11];
    } else if ([ident isEqualToString:@"date"]) {
        cell.stringValue = item.createdAt ?: @"";
        cell.font = [NSFont systemFontOfSize:10];
        cell.textColor = [NSColor secondaryLabelColor];
    } else if ([ident isEqualToString:@"desc"]) {
        cell.stringValue = item.presetDescription ?: @"";
        cell.font = [NSFont systemFontOfSize:11];
    }
    
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger sel = _tableView.selectedRow;
    if (sel >= 0 && sel < _displayedPresets.count) {
        [self updateDetailPreviewForPreset:_displayedPresets[sel]];
    }
}

- (void)updateDetailPreviewForPreset:(D3PresetItem *)item {
    if (!item) return;
    NSMutableString *str = [NSMutableString string];
    [str appendFormat:@"【 %@ 】\n", item.buildName ?: @""];
    [str appendFormat:@"• 시즌: %@  |  직업: %@  |  작성자: %@  |  등록일: %@\n",
     item.season ?: @"", item.characterClass ?: @"", item.author ?: @"", item.createdAt ?: @""];
    if (item.presetDescription.length > 0) {
        [str appendFormat:@"• 빌드 설명 및 운용법:\n  %@\n\n", item.presetDescription];
    } else {
        [str appendString:@"\n"];
    }
    [str appendString:@"[세부 메커니즘 & 키 바인딩 요약]\n"];
    [str appendString:[item summaryText]];
    
    _detailTextView.string = str;
}

#pragma mark Actions

- (void)importSelectedPresetAction:(id)sender {
    NSInteger sel = _tableView.selectedRow;
    if (sel < 0 || sel >= _displayedPresets.count) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"프리셋 선택 필요";
        alert.informativeText = @"목록에서 적용할 프리셋을 먼저 선택해 주세요.";
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
        return;
    }
    
    D3PresetItem *item = _displayedPresets[sel];
    D3KeyConfig *config = [item createKeyConfig];
    NSInteger slot = _targetSlotPopUp.indexOfSelectedItem + 1;
    
    if (self.delegate) {
        [self.delegate presetShareDidSelectConfig:config forSlot:slot];
        
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"프리셋 가져오기 완료";
        alert.informativeText = [NSString stringWithFormat:@"[%@] %@ 프리셋이 프로필 슬롯 %ld번에 성공적으로 로드되었습니다.",
                                 item.characterClass, item.buildName, (long)slot];
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
    }
}

- (void)copySelectedRowAction:(id)sender {
    NSInteger sel = _tableView.selectedRow;
    if (sel < 0 || sel >= _displayedPresets.count) return;
    D3PresetItem *item = _displayedPresets[sel];
    [[D3GoogleSheetService sharedService] copyPresetRowToClipboard:item];
    
    _statusLabel.stringValue = @"선택한 행이 클립보드에 복사됨";
}

- (void)openSheetInBrowserAction:(id)sender {
    [[D3GoogleSheetService sharedService] openSheetInBrowser];
}

#pragma mark Share Modal Dialog

- (void)openShareModalAction:(id)sender {
    D3KeyConfig *curConfig = nil;
    if (self.delegate) {
        curConfig = [self.delegate currentConfigForPresetSharing];
    }
    if (!curConfig) {
        curConfig = [D3KeyConfig defaultKeyConfig];
    }
    
    NSWindow *modalWin = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 520, 420)
                                                     styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                                                       backing:NSBackingStoreBuffered
                                                         defer:NO];
    modalWin.title = @"현재 내 설정을 구글 시트에 공유 및 등록";
    
    NSView *mv = modalWin.contentView;
    [mv addSubview:[self labelWithText:@"작성자 (유저 닉네임):" frame:NSMakeRect(25, 360, 150, 20) bold:YES fontSize:12]];
    NSTextField *authorField = [[NSTextField alloc] initWithFrame:NSMakeRect(175, 358, 315, 24)];
    authorField.stringValue = [D3GoogleSheetService sharedService].lastAuthor ?: @"성역의용사";
    [mv addSubview:authorField];
    
    [mv addSubview:[self labelWithText:@"시즌 구분:" frame:NSMakeRect(25, 320, 150, 20) bold:YES fontSize:12]];
    NSPopUpButton *seasonPop = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(175, 318, 180, 26) pullsDown:NO];
    [seasonPop addItemsWithTitles:@[@"시즌 6 (증오의 그릇)", @"시즌 7", @"시즌 8", @"영원", @"디아블로 3"]];
    [mv addSubview:seasonPop];
    
    [mv addSubview:[self labelWithText:@"직업 구분:" frame:NSMakeRect(25, 280, 150, 20) bold:YES fontSize:12]];
    NSPopUpButton *classPop = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(175, 278, 180, 26) pullsDown:NO];
    [classPop addItemsWithTitles:@[@"악마술사", @"원소술사", @"야만용사", @"도적", @"강령술사", @"혼령사", @"드루이드", @"기타/공통"]];
    [mv addSubview:classPop];
    
    [mv addSubview:[self labelWithText:@"빌드명:" frame:NSMakeRect(25, 240, 150, 20) bold:YES fontSize:12]];
    NSTextField *buildField = [[NSTextField alloc] initWithFrame:NSMakeRect(175, 238, 315, 24)];
    buildField.stringValue = curConfig.memo.length > 0 ? curConfig.memo : @"나만의 추천 빌드";
    [mv addSubview:buildField];
    
    [mv addSubview:[self labelWithText:@"빌드 설명 & 팁:" frame:NSMakeRect(25, 200, 150, 20) bold:YES fontSize:12]];
    NSScrollView *descScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(25, 75, 465, 120)];
    descScroll.borderType = NSBezelBorder;
    NSTextView *descText = [[NSTextView alloc] initWithFrame:descScroll.contentView.bounds];
    descText.string = @"로테이션 및 스킬 운용 팁을 적어주세요.";
    descScroll.documentView = descText;
    [mv addSubview:descScroll];
    
    NSButton *cancelBtn = [[NSButton alloc] initWithFrame:NSMakeRect(305, 20, 85, 32)];
    cancelBtn.title = @"취소";
    cancelBtn.bezelStyle = NSBezelStyleRounded;
    [mv addSubview:cancelBtn];
    
    NSButton *okBtn = [[NSButton alloc] initWithFrame:NSMakeRect(395, 20, 100, 32)];
    okBtn.title = @"🚀 시트 공유";
    okBtn.bezelStyle = NSBezelStyleRounded;
    okBtn.font = [NSFont boldSystemFontOfSize:12];
    [mv addSubview:okBtn];
    
    [self.window beginSheet:modalWin completionHandler:nil];
    
    cancelBtn.target = self;
    cancelBtn.action = @selector(dismissModalSheet:);
    
    __weak typeof(self) weakSelf = self;
    okBtn.target = self;
    okBtn.action = @selector(executeShareButtonAction:);
    
    // 공유 실행 이벤트 클로저
    [cancelBtn setTarget:self];
    [cancelBtn setAction:@selector(dismissModalSheet:)];
    
    // 제출 버튼 콜백
    objc_setAssociatedObject(okBtn, "share_action", ^{
        NSString *author = authorField.stringValue;
        NSString *season = seasonPop.titleOfSelectedItem;
        NSString *charClass = classPop.titleOfSelectedItem;
        NSString *buildName = buildField.stringValue;
        NSString *desc = descText.string;
        
        [D3GoogleSheetService sharedService].lastAuthor = author;
        
        D3PresetItem *item = [D3PresetItem presetWithAuthor:author
                                                     season:season
                                             characterClass:charClass
                                                  buildName:buildName
                                                description:desc
                                                     config:curConfig];
        
        [[D3GoogleSheetService sharedService] publishPreset:item completion:^(BOOL success, NSString *message) {
            NSAlert *resAlert = [[NSAlert alloc] init];
            resAlert.messageText = success ? @"프리셋 공유 등록" : @"등록 알림";
            resAlert.informativeText = message;
            [resAlert beginSheetModalForWindow:weakSelf.window completionHandler:nil];
        }];
    }, OBJC_ASSOCIATION_COPY_NONATOMIC);
    
    okBtn.target = self;
    okBtn.action = @selector(executeShareButtonAction:);
}

- (void)executeShareButtonAction:(id)sender {
    void (^action)(void) = objc_getAssociatedObject(sender, "share_action");
    if (action) {
        action();
    }
    [self dismissModalSheet:sender];
}

- (void)dismissModalSheet:(id)sender {
    NSWindow *sheet = [sender window];
    [self.window endSheet:sheet];
    [sheet orderOut:nil];
}

#pragma mark Settings Dialog

- (void)openSettingsSheetAction:(id)sender {
    NSWindow *settingsWin = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 560, 360)
                                                        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO];
    settingsWin.title = @"구글 시트 연동 및 Web App 엔드포인트 설정";
    NSView *sv = settingsWin.contentView;
    
    [sv addSubview:[self labelWithText:@"구글 스프레드시트 URL 또는 시트 ID:" frame:NSMakeRect(25, 305, 350, 20) bold:YES fontSize:12]];
    NSTextField *sheetUrlField = [[NSTextField alloc] initWithFrame:NSMakeRect(25, 278, 510, 24)];
    sheetUrlField.stringValue = [D3GoogleSheetService sharedService].sheetUrl ?: @"";
    sheetUrlField.placeholderString = @"https://docs.google.com/spreadsheets/d/.../edit";
    [sv addSubview:sheetUrlField];
    
    [sv addSubview:[self labelWithText:@"Google Apps Script Web App URL (자동 등록용, 선택):" frame:NSMakeRect(25, 235, 450, 20) bold:YES fontSize:12]];
    NSTextField *webAppField = [[NSTextField alloc] initWithFrame:NSMakeRect(25, 208, 510, 24)];
    webAppField.stringValue = [D3GoogleSheetService sharedService].webAppUrl ?: @"";
    webAppField.placeholderString = @"https://script.google.com/macros/s/.../exec";
    [sv addSubview:webAppField];
    
    NSTextField *tipLabel = [self labelWithText:@"💡 팁: Web App URL이 없어도 [시트 행 복사]로 시트에 즉시 붙여넣기(Cmd+V)가 가능합니다.\n본인만의 구글 시트를 만들고 싶다면 [Apps Script 코드 복사]를 눌러 스크립트를 적용하세요." frame:NSMakeRect(25, 120, 510, 48) bold:NO fontSize:11];
    tipLabel.textColor = [NSColor secondaryLabelColor];
    [sv addSubview:tipLabel];
    
    NSButton *copyScriptBtn = [[NSButton alloc] initWithFrame:NSMakeRect(25, 75, 200, 28)];
    copyScriptBtn.title = @"📋 Apps Script 템플릿 복사";
    copyScriptBtn.bezelStyle = NSBezelStyleRounded;
    copyScriptBtn.target = self;
    copyScriptBtn.action = @selector(copyAppsScriptTemplate:);
    [sv addSubview:copyScriptBtn];
    
    NSButton *cancelBtn = [[NSButton alloc] initWithFrame:NSMakeRect(360, 20, 80, 32)];
    cancelBtn.title = @"취소";
    cancelBtn.bezelStyle = NSBezelStyleRounded;
    cancelBtn.target = self;
    cancelBtn.action = @selector(dismissModalSheet:);
    [sv addSubview:cancelBtn];
    
    NSButton *saveBtn = [[NSButton alloc] initWithFrame:NSMakeRect(450, 20, 85, 32)];
    saveBtn.title = @"저장";
    saveBtn.bezelStyle = NSBezelStyleRounded;
    saveBtn.target = self;
    [sv addSubview:saveBtn];
    
    [self.window beginSheet:settingsWin completionHandler:nil];
    
    __weak typeof(self) weakSelf = self;
    objc_setAssociatedObject(saveBtn, "save_settings", ^{
        [D3GoogleSheetService sharedService].sheetUrl = sheetUrlField.stringValue;
        [D3GoogleSheetService sharedService].webAppUrl = webAppField.stringValue;
        [weakSelf refreshRemotePresets:nil];
    }, OBJC_ASSOCIATION_COPY_NONATOMIC);
    
    saveBtn.action = @selector(executeSettingsSaveAction:);
}

- (void)executeSettingsSaveAction:(id)sender {
    void (^action)(void) = objc_getAssociatedObject(sender, "save_settings");
    if (action) action();
    [self dismissModalSheet:sender];
}

- (void)copyAppsScriptTemplate:(id)sender {
    NSString *code = [[D3GoogleSheetService sharedService] googleAppsScriptTemplateCode];
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:code forType:NSPasteboardTypeString];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"템플릿 코드 복사 완료";
    alert.informativeText = @"구글 시트의 [확장 프로그램] > [Apps Script]에 붙여넣을 수 있는 코드가 클립보드에 복사되었습니다.";
    [alert beginSheetModalForWindow:[sender window] completionHandler:nil];
}

#pragma mark Helper

- (NSTextField *)labelWithText:(NSString *)text frame:(NSRect)frame bold:(BOOL)bold fontSize:(CGFloat)size {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = text;
    label.editable = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.font = bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
    return label;
}

@end
