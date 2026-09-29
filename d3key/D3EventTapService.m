//
//  D3EventTapService.m
//  d3key
//
//  Created for Diablo Helper Evolution.
//

#import "D3EventTapService.h"
#import <Carbon/Carbon.h>
#import <AppKit/AppKit.h>
#import "const.h"

@interface D3EventTapService ()
{
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _runLoopSource;
    NSMutableSet<D3InputKey *> *_pressedKeys;
    CGEventFlags _lastModifierFlags;
    id _globalEventMonitor;
}

- (void)handleCGEvent:(CGEventRef)event ofType:(CGEventType)type;

@end

static CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    D3EventTapService *service = (__bridge D3EventTapService *)refcon;
    [service handleCGEvent:event ofType:type];
    return event;
}

@implementation D3EventTapService

+ (instancetype)sharedService {
    static D3EventTapService *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _pressedKeys = [NSMutableSet set];
        _lastModifierFlags = 0;
    }
    return self;
}

- (BOOL)startEventTap {
    if (_eventTap != NULL || _globalEventMonitor != nil) {
        return YES;
    }
    
    CGEventMask eventMask = (1ULL << kCGEventKeyDown) |
                            (1ULL << kCGEventKeyUp) |
                            (1ULL << kCGEventFlagsChanged) |
                            (1ULL << kCGEventLeftMouseDown) |
                            (1ULL << kCGEventLeftMouseUp) |
                            (1ULL << kCGEventRightMouseDown) |
                            (1ULL << kCGEventRightMouseUp) |
                            (1ULL << kCGEventOtherMouseDown) |
                            (1ULL << kCGEventOtherMouseUp) |
                            (1ULL << kCGEventScrollWheel);
    
    _eventTap = CGEventTapCreate(
        kCGHIDEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionListenOnly,
        eventMask,
        eventTapCallback,
        (__bridge void *)(self)
    );
    
    // HID tap 실패 시 Session tap으로 대체 시도
    if (!_eventTap) {
        _eventTap = CGEventTapCreate(
            kCGSessionEventTap,
            kCGHeadInsertEventTap,
            kCGEventTapOptionListenOnly,
            eventMask,
            eventTapCallback,
            (__bridge void *)(self)
        );
    }
    
    if (_eventTap) {
        _runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetMain(), _runLoopSource, kCFRunLoopCommonModes);
        CGEventTapEnable(_eventTap, true);
    }
    
    // NSEvent 글로벌 모니터 추가 (전체화면 게임 및 Wine/CrossOver 환경에서 완벽한 단축키 수신 보장)
    if (!_globalEventMonitor) {
        __weak typeof(self) weakSelf = self;
        _globalEventMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:(NSEventMaskKeyDown | NSEventMaskKeyUp | NSEventMaskFlagsChanged) handler:^(NSEvent *event) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            // 0. 가상 매크로 이벤트 무시
            CGEventRef cgEvent = [event CGEvent];
            if (cgEvent) {
                int64_t tag = CGEventGetIntegerValueField(cgEvent, kCGEventSourceUserData);
                if (tag == kD3SyntheticEventMagicTag) {
                    return;
                }
            }
            
            CGKeyCode code = event.keyCode;
            D3InputKey *inputKey = [D3InputKey keyWithKeyCode:code];
            BOOL isDown = (event.type == NSEventTypeKeyDown);
            if (event.type == NSEventTypeFlagsChanged) {
                NSEventModifierFlags flags = event.modifierFlags;
                switch (code) {
                    case 56: case 60: isDown = (flags & NSEventModifierFlagShift) != 0; break;
                    case 59: case 62: isDown = (flags & NSEventModifierFlagControl) != 0; break;
                    case 58: case 61: isDown = (flags & NSEventModifierFlagOption) != 0; break;
                    case 55: case 54: isDown = (flags & NSEventModifierFlagCommand) != 0; break;
                    case 57: isDown = (flags & NSEventModifierFlagCapsLock) != 0; break;
                    default: isDown = YES; break;
                }
            }
            
            BOOL isRepeat = (event.type == NSEventTypeKeyDown && event.isARepeat);
            
            // 키 캡처 모드
            if (strongSelf.keyCaptureHandler && isDown) {
                // Command(55, 54) 및 Fn(63) 단독 키는 단축키로 등록하지 않음 (Cmd+Tab, Cmd+Space 오등록 방지)
                if (inputKey.type == D3InputTypeKeyboard && (inputKey.keyCode == 55 || inputKey.keyCode == 54 || inputKey.keyCode == 63)) {
                    // 무시
                } else {
                    void (^handler)(D3InputKey *) = strongSelf.keyCaptureHandler;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(inputKey);
                    });
                    return;
                }
            }
            
            // Update pressed keys set
            @synchronized (strongSelf->_pressedKeys) {
                if (isDown) {
                    [strongSelf->_pressedKeys addObject:inputKey];
                } else {
                    [strongSelf->_pressedKeys removeObject:inputKey];
                }
            }
            
            if (strongSelf.listener && [strongSelf.listener respondsToSelector:@selector(onInputEvent:isDown:isRepeat:)]) {
                [strongSelf.listener onInputEvent:inputKey isDown:isDown isRepeat:isRepeat];
            }
        }];
    }
    
    BOOL success = (_eventTap != NULL || _globalEventMonitor != nil);
    if (!success) {
        NSLog(@"Failed to start event tap / monitor. Ensure Accessibility permissions are granted.");
        return NO;
    }
    
    NSLog(@"Event tap & NSEvent global monitor started successfully (eventTap=%p, globalMonitor=%@).", _eventTap, _globalEventMonitor);
    return YES;
}

- (void)stopEventTap {
    if (_globalEventMonitor) {
        [NSEvent removeMonitor:_globalEventMonitor];
        _globalEventMonitor = nil;
    }
    if (_eventTap) {
        CGEventTapEnable(_eventTap, false);
        if (_runLoopSource) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), _runLoopSource, kCFRunLoopCommonModes);
            CFRelease(_runLoopSource);
            _runLoopSource = NULL;
        }
        CFRelease(_eventTap);
        _eventTap = NULL;
        [_pressedKeys removeAllObjects];
        NSLog(@"CGEventTap stopped.");
    }
}

- (BOOL)isRunning {
    return (_eventTap != NULL || _globalEventMonitor != nil);
}

- (BOOL)isKeyPressed:(D3InputKey *)key {
    if (!key || [key isEmpty]) return NO;
    @synchronized (_pressedKeys) {
        return [_pressedKeys containsObject:key];
    }
}

- (NSSet<D3InputKey *> *)pressedKeys {
    @synchronized (_pressedKeys) {
        return [_pressedKeys copy];
    }
}

- (void)startCapturingKeyWithHandler:(void (^)(D3InputKey *capturedKey))handler {
    self.keyCaptureHandler = handler;
}

- (void)stopCapturingKey {
    self.keyCaptureHandler = nil;
}

#pragma mark Event Handling

- (void)handleCGEvent:(CGEventRef)event ofType:(CGEventType)type {
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (_eventTap) {
            CGEventTapEnable(_eventTap, true);
        }
        return;
    }
    
    if (!event) {
        return;
    }
    
    // 0. 무한 루프 및 자체 키 간섭 방지: 우리 앱이 생성한 가상 매크로 이벤트는 무시
    int64_t tag = CGEventGetIntegerValueField(event, kCGEventSourceUserData);
    if (tag == kD3SyntheticEventMagicTag) {
        return;
    }
    
    D3InputKey *inputKey = nil;
    BOOL isDown = NO;
    BOOL isRepeat = NO;
    
    if (type == kCGEventKeyDown) {
        CGKeyCode code = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        inputKey = [D3InputKey keyWithKeyCode:code];
        isDown = YES;
        isRepeat = (CGEventGetIntegerValueField(event, kCGKeyboardEventAutorepeat) != 0);
    } else if (type == kCGEventKeyUp) {
        CGKeyCode code = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        inputKey = [D3InputKey keyWithKeyCode:code];
        isDown = NO;
    } else if (type == kCGEventFlagsChanged) {
        CGKeyCode code = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        CGEventFlags flags = CGEventGetFlags(event);
        inputKey = [D3InputKey keyWithKeyCode:code];
        
        // 플래그 비트마스크 기반 정확한 Up/Down 판별 (반전 오류 방지)
        switch (code) {
            case 56: case 60: // Left / Right Shift
                isDown = (flags & kCGEventFlagMaskShift) != 0;
                break;
            case 59: case 62: // Left / Right Control
                isDown = (flags & kCGEventFlagMaskControl) != 0;
                break;
            case 58: case 61: // Left / Right Option
                isDown = (flags & kCGEventFlagMaskAlternate) != 0;
                break;
            case 55: case 54: // Left / Right Command
                isDown = (flags & kCGEventFlagMaskCommand) != 0;
                break;
            case 57: // Caps Lock
                isDown = (flags & kCGEventFlagMaskAlphaShift) != 0;
                break;
            case 63: // Function (fn)
                isDown = (flags & kCGEventFlagMaskSecondaryFn) != 0;
                break;
            default: {
                BOOL wasDown = NO;
                @synchronized (_pressedKeys) {
                    wasDown = [_pressedKeys containsObject:inputKey];
                }
                isDown = !wasDown;
                break;
            }
        }
        _lastModifierFlags = flags;
    } else if (type == kCGEventLeftMouseDown) {
        inputKey = [D3InputKey keyWithMouseButton:kCGMouseButtonLeft];
        isDown = YES;
    } else if (type == kCGEventLeftMouseUp) {
        inputKey = [D3InputKey keyWithMouseButton:kCGMouseButtonLeft];
        isDown = NO;
    } else if (type == kCGEventRightMouseDown) {
        inputKey = [D3InputKey keyWithMouseButton:kCGMouseButtonRight];
        isDown = YES;
    } else if (type == kCGEventRightMouseUp) {
        inputKey = [D3InputKey keyWithMouseButton:kCGMouseButtonRight];
        isDown = NO;
    } else if (type == kCGEventOtherMouseDown) {
        int64_t btn = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
        inputKey = [D3InputKey keyWithMouseButton:(CGMouseButton)btn];
        isDown = YES;
    } else if (type == kCGEventOtherMouseUp) {
        int64_t btn = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
        inputKey = [D3InputKey keyWithMouseButton:(CGMouseButton)btn];
        isDown = NO;
    } else if (type == kCGEventScrollWheel) {
        int64_t delta = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
        if (delta > 0) {
            inputKey = [D3InputKey keyWithWheelDirection:D3WheelDirectionUp];
            isDown = YES;
        } else if (delta < 0) {
            inputKey = [D3InputKey keyWithWheelDirection:D3WheelDirectionDown];
            isDown = YES;
        }
    }
    
    if (!inputKey || [inputKey isEmpty]) {
        return;
    }
    
    // Update pressed keys set
    @synchronized (_pressedKeys) {
        if (isDown) {
            [_pressedKeys addObject:inputKey];
        } else {
            [_pressedKeys removeObject:inputKey];
        }
    }
    
    // Handle key capture mode if active
    if (self.keyCaptureHandler && isDown) {
        // 1. 마우스 좌클릭은 전역 탭에서 캡처하지 않음 (UI 컨트롤 및 메뉴 클릭 보호)
        if (inputKey.type == D3InputTypeMouseButton && inputKey.mouseButton == kCGMouseButtonLeft) {
            // 좌클릭은 캡처하지 않고 일반 OS/UI 클릭 동작으로 통과
        } else if (inputKey.type == D3InputTypeKeyboard && (inputKey.keyCode == 55 || inputKey.keyCode == 54 || inputKey.keyCode == 63)) {
            // Command 및 Fn 단독 키는 단축키로 등록하지 않음 (Cmd+Tab, Cmd+Space 오등록 방지)
        } else {
            void (^handler)(D3InputKey *) = self.keyCaptureHandler;
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(inputKey);
            });
            return;
        }
    }
    
    // Notify listener
    if (self.listener) {
        if ([self.listener respondsToSelector:@selector(onInputEvent:isDown:isRepeat:)]) {
            [self.listener onInputEvent:inputKey isDown:isDown isRepeat:isRepeat];
        } else if ([self.listener respondsToSelector:@selector(onInputEvent:isDown:)]) {
            [self.listener onInputEvent:inputKey isDown:isDown];
        }
    }
}

@end

