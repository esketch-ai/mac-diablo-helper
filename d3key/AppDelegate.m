//
//  AppDelegate.m
//  d3key
//
//  Created by sunghyuk-imac on 2016. 2. 12..
//  Updated for Diablo Helper Evolution.
//

#import "AppDelegate.h"
#import <Carbon/Carbon.h>
#import "MainWindowController.h"
#import "D3KeyConfig.h"
#import "D3KeyConfigService.h"
#import "D3EventTapService.h"
#import "D3HelperEngine.h"
#import "D3LocalizationManager.h"
#import <ApplicationServices/ApplicationServices.h>
#include "const.h"

@interface AppDelegate () <D3HelperEngineDelegate>

@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) D3KeyConfig *keyConfig;

@end

@implementation AppDelegate

- (void)updateStatusMenu {
    if (self.statusMenu == nil) {
        self.statusMenu = [[NSMenu alloc] initWithTitle:@"DM_Helper"];
    }
    [self.statusMenu removeAllItems];
    
    // 1. App name & Version
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *appName = [info objectForKey:@"CFBundleDisplayName"] ?: @"DM_Helper";
    NSString *appVer = [info objectForKey:@"CFBundleShortVersionString"] ?: @"1.5.1";
    NSString *aboutTitle = [NSString stringWithFormat:@"%@ v%@", appName, appVer];
    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:aboutTitle action:@selector(statusPreferences:) keyEquivalent:@""];
    aboutItem.target = self;
    [self.statusMenu addItem:aboutItem];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // 2. Start / Stop Helper toggle
    BOOL isRunning = [[D3HelperEngine sharedEngine] isRunning];
    NSString *toggleTitle = isRunning ? D3Loc(@"menu_stop") : D3Loc(@"menu_start");
    NSMenuItem *toggleItem = [[NSMenuItem alloc] initWithTitle:toggleTitle action:@selector(toggleHelper:) keyEquivalent:@""];
    toggleItem.target = self;
    [self.statusMenu addItem:toggleItem];
    
    // 3. Opener sequence trigger
    NSMenuItem *openerItem = [[NSMenuItem alloc] initWithTitle:D3Loc(@"menu_opener") action:@selector(triggerOpener:) keyEquivalent:@""];
    openerItem.target = self;
    [self.statusMenu addItem:openerItem];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // 4. Main Window (Settings)
    NSMenuItem *prefItem = [[NSMenuItem alloc] initWithTitle:D3Loc(@"menu_pref") action:@selector(statusPreferences:) keyEquivalent:@","];
    prefItem.target = self;
    [self.statusMenu addItem:prefItem];
    
    // 5. Google Sheets Preset Hub
    NSMenuItem *hubItem = [[NSMenuItem alloc] initWithTitle:D3Loc(@"menu_sheet") action:@selector(openPresetShareWindow:) keyEquivalent:@""];
    hubItem.target = self;
    [self.statusMenu addItem:hubItem];
    
    // 6. User Guide
    NSMenuItem *guideItem = [[NSMenuItem alloc] initWithTitle:D3Loc(@"menu_guide") action:@selector(showHelp:) keyEquivalent:@"/"];
    guideItem.target = self;
    [self.statusMenu addItem:guideItem];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // 7. Language Submenu
    NSMenuItem *langMenuItem = [[NSMenuItem alloc] initWithTitle:D3Loc(@"menu_language") action:nil keyEquivalent:@""];
    NSMenu *langMenu = [[NSMenu alloc] initWithTitle:D3Loc(@"menu_language")];
    
    D3LanguageMode curMode = [D3LocalizationManager sharedManager].languageMode;
    
    NSMenuItem *autoLang = [[NSMenuItem alloc] initWithTitle:D3Loc(@"menu_lang_auto") action:@selector(selectLanguageMode:) keyEquivalent:@""];
    autoLang.target = self;
    autoLang.tag = D3LanguageModeAuto;
    autoLang.state = (curMode == D3LanguageModeAuto) ? NSControlStateValueOn : NSControlStateValueOff;
    [langMenu addItem:autoLang];
    
    NSMenuItem *koLang = [[NSMenuItem alloc] initWithTitle:D3Loc(@"menu_lang_ko") action:@selector(selectLanguageMode:) keyEquivalent:@""];
    koLang.target = self;
    koLang.tag = D3LanguageModeKorean;
    koLang.state = (curMode == D3LanguageModeKorean) ? NSControlStateValueOn : NSControlStateValueOff;
    [langMenu addItem:koLang];
    
    NSMenuItem *enLang = [[NSMenuItem alloc] initWithTitle:D3Loc(@"menu_lang_en") action:@selector(selectLanguageMode:) keyEquivalent:@""];
    enLang.target = self;
    enLang.tag = D3LanguageModeEnglish;
    enLang.state = (curMode == D3LanguageModeEnglish) ? NSControlStateValueOn : NSControlStateValueOff;
    [langMenu addItem:enLang];
    
    langMenuItem.submenu = langMenu;
    [self.statusMenu addItem:langMenuItem];
    
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // 8. Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:D3Loc(@"menu_quit") action:@selector(terminate:) keyEquivalent:@"q"];
    [self.statusMenu addItem:quitItem];
    
    if (self.statusBar) {
        self.statusBar.menu = self.statusMenu;
    }
}

- (void)setupStatusBarItem {
    if (self.statusBar == nil) {
        self.statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    }
    
    NSImage *image = [NSImage imageNamed:@"StatusBar"];
    if (image) {
        [image setTemplate:YES];
    }
    
    if (@available(macOS 10.14, *)) {
        if (self.statusBar.button) {
            self.statusBar.button.image = image;
            self.statusBar.button.imagePosition = NSImageLeft;
            self.statusBar.button.title = @" DM";
            self.statusBar.button.toolTip = @"DM_Helper";
        }
    } else {
        self.statusBar.image = image;
        self.statusBar.title = @" DM";
    }
    
    [self updateStatusMenu];
    self.statusBar.highlightMode = YES;
}

- (void)awakeFromNib {
    [self setupStatusBarItem];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    // 1. Load initial config (preset 1)
    self.keyConfig = [[D3KeyConfigService sharedService] loadConfig:@"1"];
    [[D3HelperEngine sharedEngine] updateConfig:self.keyConfig];
    [D3HelperEngine sharedEngine].delegate = self;
    
    // 2. Notification observers
    [self addNotificationObserver];
    
    // 3. Status Bar
    [self setupStatusBarItem];
    
    // 4. Check Accessibility & start event tap
    BOOL eventTapStarted = [[D3EventTapService sharedService] startEventTap];
    if (eventTapStarted) {
        NSLog(@"Event tap started successfully on launch.");
        [[NSNotificationCenter defaultCenter] postNotificationName:kD3AccessibilityStatusChangedNotification object:nil userInfo:@{@"trusted": @YES}];
    } else {
        if (!AXIsProcessTrusted()) {
            NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
            AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
        }
        [self waitForAccessibility];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self setupStatusBarItem];
    
    // 메인 창을 화면 중앙에 띄우고 앱을 최상단으로 활성화
    if (self.windowController == nil) {
        self.windowController = [[MainWindowController alloc] initWithWindowNibName:@"MainWindow"];
    }
    [self.windowController.window center];
    [self.windowController.window makeKeyAndOrderFront:nil];
    [self.windowController showWindow:self];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    if (self.windowController == nil) {
        self.windowController = [[MainWindowController alloc] initWithWindowNibName:@"MainWindow"];
    }
    [self.windowController.window center];
    [self.windowController.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [[D3EventTapService sharedService] stopEventTap];
    [[D3HelperEngine sharedEngine] stop];
}

#pragma mark IBAction

- (IBAction)statusPreferences:(id)sender {
    if (self.windowController == nil) {
        self.windowController = [[MainWindowController alloc] initWithWindowNibName:@"MainWindow"];
    }
    [self.windowController.window center];
    [self.windowController.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)toggleHelper:(id)sender {
    [[D3HelperEngine sharedEngine] toggle];
}

- (IBAction)triggerOpener:(id)sender {
    [[D3HelperEngine sharedEngine] triggerOpener];
}

- (IBAction)openPresetShareWindow:(id)sender {
    if (self.windowController == nil) {
        self.windowController = [[MainWindowController alloc] initWithWindowNibName:@"MainWindow"];
    }
    [self.windowController showPresetShareWindow:sender];
}

- (IBAction)showHelp:(id)sender {
    if (self.windowController == nil) {
        self.windowController = [[MainWindowController alloc] initWithWindowNibName:@"MainWindow"];
    }
    [self.windowController showHelpWindow:sender];
}

- (void)selectLanguageMode:(NSMenuItem *)sender {
    [D3LocalizationManager sharedManager].languageMode = (D3LanguageMode)sender.tag;
    [self updateStatusMenu];
}

#pragma mark Notification Observer

- (void)addNotificationObserver {
    [[NSNotificationCenter defaultCenter] addObserverForName:kD3KeyStartStopNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * note) {
        NSString *action = [note.userInfo objectForKey:@"action"];
        if ([action isEqualToString:@"start"]) {
            [[D3HelperEngine sharedEngine] start];
        } else if ([action isEqualToString:@"stop"]) {
            [[D3HelperEngine sharedEngine] stop];
        }
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kD3KeyConfigChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * note) {
        NSString *configId = [note.userInfo objectForKey:@"configId"];
        self.keyConfig = [[D3KeyConfigService sharedService] loadConfig:configId];
        [[D3HelperEngine sharedEngine] updateConfig:self.keyConfig];
        NSLog(@"Config changed and loaded to engine: %@", configId);
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kD3KeyActivatedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * note) {
        [[D3EventTapService sharedService] startEventTap];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kD3KeyDeactivatedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * note) {
        [[D3EventTapService sharedService] stopEventTap];
        [[D3HelperEngine sharedEngine] stop];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kD3LanguageChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * note) {
        [self updateStatusMenu];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kD3EngineStateChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * note) {
        BOOL isRunning = [[note.userInfo objectForKey:@"isRunning"] boolValue];
        [self handleEngineStateChanged:isRunning];
    }];
}

- (void)handleEngineStateChanged:(BOOL)isRunning {
    NSLog(@"Engine state changed: %@", isRunning ? @"RUNNING" : @"STOPPED");
    [self updateStatusMenu];
    if (self.keyConfig.soundFeedbackEnabled) {
        if (isRunning) {
            [[NSSound soundNamed:@"Tink"] play];
        } else {
            [[NSSound soundNamed:@"Pop"] play];
        }
    }
}

- (void)waitForAccessibility {
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([[D3EventTapService sharedService] isRunning]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kD3AccessibilityStatusChangedNotification object:nil userInfo:@{@"trusted": @YES}];
            return;
        }
        
        BOOL success = [[D3EventTapService sharedService] startEventTap];
        if (success || AXIsProcessTrusted()) {
            NSLog(@"Accessibility granted.");
            [[D3EventTapService sharedService] startEventTap];
            [[NSNotificationCenter defaultCenter] postNotificationName:kD3AccessibilityStatusChangedNotification object:nil userInfo:@{@"trusted": @YES}];
        } else {
            [weakSelf waitForAccessibility];
        }
    });
}

#pragma mark D3HelperEngineDelegate

- (void)helperEngineStateChanged:(BOOL)isRunning {
    [self handleEngineStateChanged:isRunning];
}

- (void)helperEnginePresetChangeRequested:(NSInteger)presetIndex {
    [self.windowController changePreset:presetIndex];
}

@end
