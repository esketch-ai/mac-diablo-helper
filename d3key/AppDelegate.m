//
//  AppDelegate.m
//  d3key
//
//  Created by sunghyuk-imac on 2016. 2. 12..
//  Copyright © 2016년 sunghyuk. All rights reserved.
//

#import "AppDelegate.h"
#import <Carbon/Carbon.h>
#import "MainWindowController.h"
#import "D3KeyConfig.h"
#import "D3KeyConfigService.h"
#import "MSWeakTimer.h"
#import <ApplicationServices/ApplicationServices.h>
#include "const.h"


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@property (nonatomic, strong) D3KeyConfig *keyConfig;
@property (nonatomic, strong) NSMutableArray *timers;
@property (strong, nonatomic) dispatch_queue_t timersQueue;

@end

@implementation AppDelegate
{
    NSEvent *_gEvent;
    pid_t _targetPid; // 시작키를 누른 시점의 최전면 앱 (D3 네이티브, GPTK/Wine 위의 D4 등)
}

- (void) awakeFromNib {
    self.statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    
    //self.statusBar.title = @"D3A";
    
    // you can also set an image
    self.statusBar.image = [NSImage imageNamed:@"StatusBar"];
    
    self.statusBar.menu = self.statusMenu;
    self.statusBar.highlightMode = YES;
    
    // app name, version
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *aboutString = [NSString stringWithFormat:@"%@ %@", [info objectForKey:@"CFBundleDisplayName"], [info objectForKey:@"CFBundleShortVersionString"]];
    self.aboutMenuItem.title = aboutString;
    
}

- (void) applicationWillFinishLaunching:(NSNotification *)notification {
    
    self.timers = [[NSMutableArray alloc] initWithCapacity:6];
    self.timersQueue = dispatch_queue_create("sunghyuk.d3key.timerQueue", DISPATCH_QUEUE_CONCURRENT);
    
    // load config
    self.keyConfig = [[D3KeyConfigService sharedService] loadConfig:@"1"];
    
    // notification observer
    [self addNotificationObserver];
    
    if (self.windowController == nil) {
        self.windowController = [[MainWindowController alloc] initWithWindowNibName:@"MainWindow"];
    }
    [self.windowController showWindow:self];
    
    // 손쉬운 사용 설정 안되어 있을 경우 Dialog open
    NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
    BOOL accessibilityEnabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    if (accessibilityEnabled) {
        [self registerEventMonitor];
    } else {
        // 허용될 때까지 폴링하다가 허용되면 자동 등록 (앱 재시작 불필요)
        [self waitForAccessibility];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    [self removeEventMonitor];
}

#pragma mark IBAction

- (IBAction)statusPreferences:(id)sender {
    if (![self.windowController.window isVisible]) {
        [self.windowController showWindow:self];
    }
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}

#pragma mark Timer

- (void) addTimer:(NSString *) keyCodeKey andWith:(NSString *) delayKey {
    NSUInteger delay = [[self.keyConfig valueForKey:delayKey] unsignedIntegerValue];
    NSUInteger keyCode = [[self.keyConfig valueForKey:keyCodeKey] unsignedIntegerValue];
    BOOL mouseLeftKey = [@"mouseLeftKey" isEqualToString:keyCodeKey] ? YES : NO;
    BOOL mouseRightKey = [@"mouseRightKey" isEqualToString:keyCodeKey] ? YES : NO;
    if (delay > 0) {
        if (delay < 100) {
            delay = 100;
        }
        NSTimeInterval interval = delay*1.0 / 1000;
        NSDictionary *userInfo = @{
                                   @"keyCode":[NSNumber numberWithUnsignedInteger:keyCode],
                                   @"delay":[NSNumber numberWithUnsignedInteger:delay],
                                   @"mouseLeftKey": [NSNumber numberWithBool:mouseLeftKey],
                                   @"mouseRightKey": [NSNumber numberWithBool:mouseRightKey]
                                   };
        NSLog(@"add timer - userinfo: %@, interval: %f", userInfo, interval);
        [self fireEvent:userInfo];
        MSWeakTimer *timer = [MSWeakTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(timerFireMethod:) userInfo:userInfo repeats:YES dispatchQueue:self.timersQueue];
        [self.timers addObject:timer];
    }
}

- (void) startTimer {
    NSLog(@"start timers");

    // 시작 시점의 최전면 앱을 타깃으로 고정 — 게임에서 다른 앱으로 전환하면 발송 중단
    _targetPid = [[NSWorkspace sharedWorkspace] frontmostApplication].processIdentifier;

    for (int i = 1; i < 7; i++) {
        [self addTimer:[NSString stringWithFormat:@"skillKey%d", i] andWith:[NSString stringWithFormat:@"skillDelay%d", i]];
    }
    [self addTimer:@"mouseLeftKey" andWith:@"mouseLeftDelay"];
    [self addTimer:@"mouseRightKey" andWith:@"mouseRightDelay"];
}

- (void) stopTimer {
    NSLog(@"stop timer");
    for (NSTimer *t in self.timers) {
        [t invalidate];
    }
    [self.timers removeAllObjects];
}

- (BOOL) isTimerRunning {
    return [self.timers count];
}

// add by latem
- (void) postMouseEvent:(CGMouseButton) button eventType:(CGEventType) type
{
    CGEventRef mouseEvent = CGEventCreate(NULL);
    CGPoint mouseLoc = CGEventGetLocation(mouseEvent);
    CFRelease(mouseEvent);
    
    CGEventRef theEvent = CGEventCreateMouseEvent(NULL, type, mouseLoc, button);
    CGEventSetType(theEvent, type);
    CGEventPost(kCGHIDEventTap, theEvent);
    CFRelease(theEvent);
}

- (void) rightClick
{
    [self postMouseEvent:kCGMouseButtonRight eventType: kCGEventRightMouseDown];
    usleep(10);
    [self postMouseEvent:kCGMouseButtonRight eventType: kCGEventRightMouseUp];
}

- (void) leftClick
{
    [self postMouseEvent:kCGMouseButtonLeft eventType: kCGEventLeftMouseDown];
    usleep(10);
    [self postMouseEvent:kCGMouseButtonLeft eventType: kCGEventLeftMouseUp];
}

- (void) fireEvent:(NSDictionary *) userInfo {
    NSUInteger keyCode = [[userInfo objectForKey:@"keyCode"] unsignedIntegerValue];
    NSUInteger delay = [[userInfo objectForKey:@"delay"] unsignedIntegerValue];
    BOOL mouseLeftKey = [[userInfo objectForKey:@"mouseLeftKey"] boolValue];
    BOOL mouseRightKey = [[userInfo objectForKey:@"mouseRightKey"] boolValue];
    
    // 시작 시점에 고정한 타깃 앱이 최전면일 때만 발송 (다른 앱으로 키 입력이 새는 것 방지)
    // GPTK/Wine 게임은 블리자드 번들 ID가 없으므로 pid로 비교
    // Sequoia 15.6+에서 PSN/PID 타깃 주입(CGEventPostToPSN)이 동작하지 않아
    // 마우스 이벤트와 동일한 CGEventPost(HID tap) 방식으로 통일
    NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (front.processIdentifier == _targetPid) {
        // mouse event
        if (mouseRightKey) {
            NSLog(@"fire event: mouseRightKey, %tu", delay);
            [self rightClick];
        } else if (mouseLeftKey) {
            NSLog(@"fire event: mouseLeftKey, %tu", delay);
            [self leftClick];
        } else {
            NSLog(@"fire event: %@, %tu", [[D3KeyConfigService sharedService] stringWithKeycode:keyCode], delay);
            // see HIToolbox/Events.h for key codes
            CGEventRef qKeyDown = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)keyCode, true);
            CGEventRef qKeyUp = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)keyCode, false);

            CGEventPost(kCGHIDEventTap, qKeyDown);
            CGEventPost(kCGHIDEventTap, qKeyUp);

            CFRelease(qKeyDown);
            CFRelease(qKeyUp);
        }
    }
}

- (void)timerFireMethod:(NSTimer *)timer {
    [self fireEvent:timer.userInfo];
}

#pragma mark notification observer

- (void) addNotificationObserver {
    [[NSNotificationCenter defaultCenter] addObserverForName:kD3KeyStartStopNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * note) {
        NSString *action = [note.userInfo objectForKey:@"action"];
        if ([action isEqualToString:@"start"]) {
            // start operation
            [self startTimer];
        } else if ([action isEqualToString:@"stop"]) {
            // stop operation
            [self stopTimer];
        }
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kD3KeyConfigChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * note) {
        self.keyConfig = [[D3KeyConfigService sharedService] loadConfig:[note.userInfo objectForKey:@"configId"]];
        NSLog(@"config changed: %@", [note.userInfo objectForKey:@"configId"]);
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kD3KeyActivatedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * note) {
        NSLog(@"activate event monitor");
        [self registerEventMonitor];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kD3KeyDeactivatedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * note) {
        NSLog(@"deactivate event monitor");
        [self removeEventMonitor];
    }];
}

- (void) waitForAccessibility {
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (AXIsProcessTrusted()) {
            NSLog(@"accessibility granted");
            [weakSelf registerEventMonitor];
        } else {
            [weakSelf waitForAccessibility];
        }
    });
}

#pragma mark event monitor

- (void) registerEventMonitor {
    if (_gEvent) {
        NSLog(@"global key event monitor already registered");
        return;
    }
    NSLog(@"register global key event monitor");
    _gEvent = [NSEvent addGlobalMonitorForEventsMatchingMask:(NSKeyDownMask|NSFlagsChangedMask) handler:^(NSEvent *event) {

        if (event.keyCode == 0x7A || event.keyCode == 0x78 || event.keyCode == 0x63 || event.keyCode == 0x76 || event.keyCode == 0x60) {
            // F1, F2, F3, F4, F5, change preset
            NSInteger presetNum = 0;
            switch (event.keyCode) {
                case 0x7A:
                    presetNum = 0;
                    break;
                case 0x78:
                    presetNum = 1;
                    break;
                case 0x63:
                    presetNum = 2;
                    break;
                case 0x76:
                    presetNum = 3;
                    break;
                case 0x60:
                    presetNum = 4;
                    break;
            }
            [self.windowController changePreset:presetNum];
        }

        // 디아블로3 실행 여부 게이트 제거 — GPTK/Wine으로 실행한 D4는
        // com.blizzard.* 번들 ID가 없어 감지 불가. 대신 시작 시점의 최전면 앱을 타깃으로 고정함.
        NSUInteger keyCode = event.keyCode;
        if (![self isTimerRunning] && [self.keyConfig isStartKey:keyCode]) {
            // send start noti
            [[NSNotificationCenter defaultCenter] postNotificationName:kD3KeyStartStopNotification object:nil userInfo:@{@"action": @"start"}];
            return;
        }
        if ([self isTimerRunning] && [self.keyConfig isStopKey:keyCode]) {
            // send end noti
            [[NSNotificationCenter defaultCenter] postNotificationName:kD3KeyStartStopNotification object:nil userInfo:@{@"action": @"stop"}];
            return;
        }
    }];
}

- (void) removeEventMonitor {
    if (_gEvent) {
        NSLog(@"remove global key event monitor");
        [NSEvent removeMonitor:_gEvent];
        _gEvent = nil;
    }
}

@end
