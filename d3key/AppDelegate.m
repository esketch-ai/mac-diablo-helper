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
#import <ApplicationServices/ApplicationServices.h>
#include "const.h"

@interface AppDelegate () <D3HelperEngineDelegate>

@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) D3KeyConfig *keyConfig;

@end

@implementation AppDelegate

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
    
    self.statusBar.menu = self.statusMenu;
    self.statusBar.highlightMode = YES;
    
    // app name, version
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *aboutString = [NSString stringWithFormat:@"%@ %@", [info objectForKey:@"CFBundleDisplayName"] ?: @"DM_Helper", [info objectForKey:@"CFBundleShortVersionString"] ?: @"1.5"];
    self.aboutMenuItem.title = aboutString;
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
    NSLog(@"Engine state changed: %@", isRunning ? @"RUNNING" : @"STOPPED");
    if (self.keyConfig.soundFeedbackEnabled) {
        if (isRunning) {
            [[NSSound soundNamed:@"Tink"] play];
        } else {
            [[NSSound soundNamed:@"Pop"] play];
        }
    }
}

- (void)helperEnginePresetChangeRequested:(NSInteger)presetIndex {
    [self.windowController changePreset:presetIndex];
}

- (IBAction)showHelp:(id)sender {
    [self.windowController showHelpWindow:sender];
}

@end
