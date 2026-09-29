//
//  D3EventPoster.m
//  d3key
//
//  Created for Diablo Helper Evolution.
//

#import "D3EventPoster.h"
#import "D3EventTapService.h"
#import <AppKit/AppKit.h>
#import <unistd.h>
#import "const.h"

static pid_t sMyPid = 0;
static NSString *sMyBundleId = nil;

@implementation D3EventPoster

+ (void)initialize {
    if (self == [D3EventPoster class]) {
        sMyPid = [NSRunningApplication currentApplication].processIdentifier;
        sMyBundleId = [[NSBundle mainBundle] bundleIdentifier];
    }
}

+ (pid_t)findDiabloPid {
    for (NSRunningApplication *app in [[NSWorkspace sharedWorkspace] runningApplications]) {
        NSString *name = app.localizedName;
        NSString *bundleId = app.bundleIdentifier;
        if (name && [name rangeOfString:@"AutoFill" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            continue;
        }
        if ((name && [name rangeOfString:@"diablo" options:NSCaseInsensitiveSearch].location != NSNotFound) ||
            (bundleId && [bundleId rangeOfString:@"diablo" options:NSCaseInsensitiveSearch].location != NSNotFound)) {
            return app.processIdentifier;
        }
    }
    return 0;
}

static void dispatchCGEvent(CGEventRef event, pid_t targetPid) {
    if (!event) return;
    // 1. HID 전역 탭에 게시 (macOS 전체화면 게임 표준 경로)
    CGEventPost(kCGHIDEventTap, event);
    
    // 2. 타깃 PID가 유효한 경우, 해당 프로세스(Diablo IV.exe 등)의 이벤트 포트에 직접 주입 (듀얼 전달)
    if (targetPid > 0) {
        CGEventPostToPid(targetPid, event);
    }
}

+ (void)postInputKey:(D3InputKey *)inputKey targetPid:(pid_t)targetPid {
    if (!inputKey || [inputKey isEmpty]) {
        return;
    }
    
    // 헬퍼 앱 자체(설정 창 등)가 활성 창일 때는 매크로 키를 전송하지 않아 텍스트 입력창 간섭 방지
    NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (front && (front.processIdentifier == sMyPid || [front.bundleIdentifier isEqualToString:sMyBundleId])) {
        return;
    }
    
    pid_t actualTargetPid = targetPid;
    if (actualTargetPid == 0 && front) {
        actualTargetPid = front.processIdentifier;
    }
    
    switch (inputKey.type) {
        case D3InputTypeKeyboard: {
            CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
            CGEventRef keyDown = CGEventCreateKeyboardEvent(source, inputKey.keyCode, true);
            CGEventRef keyUp = CGEventCreateKeyboardEvent(source, inputKey.keyCode, false);
            if (source) CFRelease(source);
            
            if (keyDown && keyUp) {
                CGEventSetIntegerValueField(keyDown, kCGEventSourceUserData, kD3SyntheticEventMagicTag);
                CGEventSetIntegerValueField(keyUp, kCGEventSourceUserData, kD3SyntheticEventMagicTag);
                
                // 1. KeyDown 전송 (HID 전역 + PID 직접 주입)
                dispatchCGEvent(keyDown, actualTargetPid);
                
                // DirectX/DirectInput 게임(디아블로4 등)을 위한 키 누름 지속 시간 (25ms)
                usleep(25000);
                
                // 2. KeyUp 전송
                dispatchCGEvent(keyUp, actualTargetPid);
                
                CFRelease(keyDown);
                CFRelease(keyUp);
            }
            break;
        }
            
        case D3InputTypeMouseButton:
            [self postMouseButtonClick:inputKey.mouseButton targetPid:actualTargetPid];
            break;
            
        case D3InputTypeMouseWheel:
            [self postWheelScroll:inputKey.wheelDirection targetPid:actualTargetPid];
            break;
            
        case D3InputTypeNone:
        default:
            break;
    }
}

+ (void)postKeyDown:(D3InputKey *)inputKey targetPid:(pid_t)targetPid {
    if (!inputKey || [inputKey isEmpty]) return;
    pid_t pid = targetPid;
    if (pid == 0) {
        NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
        pid = front ? front.processIdentifier : 0;
    }
    
    if (inputKey.type == D3InputTypeKeyboard && inputKey.keyCode != 0xFE) {
        CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
        CGEventRef keyDown = CGEventCreateKeyboardEvent(source, inputKey.keyCode, true);
        if (source) CFRelease(source);
        if (keyDown) {
            CGEventSetIntegerValueField(keyDown, kCGEventSourceUserData, kD3SyntheticEventMagicTag);
            dispatchCGEvent(keyDown, pid);
            CFRelease(keyDown);
        }
    } else if (inputKey.type == D3InputTypeMouseButton) {
        CGEventRef temp = CGEventCreate(NULL);
        if (!temp) return;
        CGPoint loc = CGEventGetLocation(temp);
        CFRelease(temp);
        
        CGEventType downType = (inputKey.mouseButton == kCGMouseButtonLeft) ? kCGEventLeftMouseDown :
                               ((inputKey.mouseButton == kCGMouseButtonRight) ? kCGEventRightMouseDown : kCGEventOtherMouseDown);
        CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
        CGEventRef down = CGEventCreateMouseEvent(source, downType, loc, inputKey.mouseButton);
        if (source) CFRelease(source);
        if (down) {
            if (inputKey.mouseButton >= 2) {
                CGEventSetIntegerValueField(down, kCGMouseEventButtonNumber, inputKey.mouseButton);
            }
            CGEventSetIntegerValueField(down, kCGEventSourceUserData, kD3SyntheticEventMagicTag);
            dispatchCGEvent(down, pid);
            CFRelease(down);
        }
    }
}

+ (void)postKeyUp:(D3InputKey *)inputKey targetPid:(pid_t)targetPid {
    if (!inputKey || [inputKey isEmpty]) return;
    pid_t pid = targetPid;
    if (pid == 0) {
        NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
        pid = front ? front.processIdentifier : 0;
    }
    
    if (inputKey.type == D3InputTypeKeyboard && inputKey.keyCode != 0xFE) {
        CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
        CGEventRef keyUp = CGEventCreateKeyboardEvent(source, inputKey.keyCode, false);
        if (source) CFRelease(source);
        if (keyUp) {
            CGEventSetIntegerValueField(keyUp, kCGEventSourceUserData, kD3SyntheticEventMagicTag);
            dispatchCGEvent(keyUp, pid);
            CFRelease(keyUp);
        }
    } else if (inputKey.type == D3InputTypeMouseButton) {
        CGEventRef temp = CGEventCreate(NULL);
        if (!temp) return;
        CGPoint loc = CGEventGetLocation(temp);
        CFRelease(temp);
        
        CGEventType upType = (inputKey.mouseButton == kCGMouseButtonLeft) ? kCGEventLeftMouseUp :
                             ((inputKey.mouseButton == kCGMouseButtonRight) ? kCGEventRightMouseUp : kCGEventOtherMouseUp);
        CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
        CGEventRef up = CGEventCreateMouseEvent(source, upType, loc, inputKey.mouseButton);
        if (source) CFRelease(source);
        if (up) {
            if (inputKey.mouseButton >= 2) {
                CGEventSetIntegerValueField(up, kCGMouseEventButtonNumber, inputKey.mouseButton);
            }
            CGEventSetIntegerValueField(up, kCGEventSourceUserData, kD3SyntheticEventMagicTag);
            dispatchCGEvent(up, pid);
            CFRelease(up);
        }
    }
}

+ (void)postKeyDown:(D3InputKey *)inputKey {
    [self postKeyDown:inputKey targetPid:0];
}

+ (void)postKeyUp:(D3InputKey *)inputKey {
    [self postKeyUp:inputKey targetPid:0];
}

+ (void)postMouseButtonClick:(CGMouseButton)button {
    [self postMouseButtonClick:button targetPid:0];
}

+ (void)postMouseButtonClick:(CGMouseButton)button targetPid:(pid_t)targetPid {
    NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
    pid_t actualTargetPid = targetPid;
    if (actualTargetPid == 0 && front) {
        actualTargetPid = front.processIdentifier;
    }
    
    CGEventRef tempEvent = CGEventCreate(NULL);
    if (!tempEvent) return;
    CGPoint mouseLoc = CGEventGetLocation(tempEvent);
    CFRelease(tempEvent);
    
    CGEventType downType;
    CGEventType upType;
    
    if (button == kCGMouseButtonLeft) {
        downType = kCGEventLeftMouseDown;
        upType = kCGEventLeftMouseUp;
    } else if (button == kCGMouseButtonRight) {
        downType = kCGEventRightMouseDown;
        upType = kCGEventRightMouseUp;
    } else {
        downType = kCGEventOtherMouseDown;
        upType = kCGEventOtherMouseUp;
    }
    
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    CGEventRef downEvent = CGEventCreateMouseEvent(source, downType, mouseLoc, button);
    CGEventRef upEvent = CGEventCreateMouseEvent(source, upType, mouseLoc, button);
    if (source) CFRelease(source);
    
    if (button >= 2) {
        CGEventSetIntegerValueField(downEvent, kCGMouseEventButtonNumber, button);
        CGEventSetIntegerValueField(upEvent, kCGMouseEventButtonNumber, button);
    }
    
    BOOL wasPhysicallyPressed = [[D3EventTapService sharedService] isKeyPressed:[D3InputKey keyWithMouseButton:button]];
    
    if (downEvent && upEvent) {
        CGEventSetIntegerValueField(downEvent, kCGEventSourceUserData, kD3SyntheticEventMagicTag);
        CGEventSetIntegerValueField(upEvent, kCGEventSourceUserData, kD3SyntheticEventMagicTag);
        
        // 1. MouseDown 전송
        dispatchCGEvent(downEvent, actualTargetPid);
        
        // 마우스 클릭 지속 시간 (25ms)
        usleep(25000);
        
        // 2. MouseUp 전송
        dispatchCGEvent(upEvent, actualTargetPid);
        
        // 사용자가 물리적으로 마우스 버튼을 누르고 있는 상태라면 즉시 누름 복원
        if (wasPhysicallyPressed) {
            dispatchCGEvent(downEvent, actualTargetPid);
        }
        
        CFRelease(downEvent);
        CFRelease(upEvent);
    }
}

+ (void)postLeftClick {
    [self postMouseButtonClick:kCGMouseButtonLeft];
}

+ (void)postRightClick {
    [self postMouseButtonClick:kCGMouseButtonRight];
}

+ (void)postMiddleClick {
    [self postMouseButtonClick:kCGMouseButtonCenter];
}

+ (void)postWheelScroll:(D3WheelDirection)direction {
    [self postWheelScroll:direction targetPid:0];
}

+ (void)postWheelScroll:(D3WheelDirection)direction targetPid:(pid_t)targetPid {
    NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
    pid_t actualTargetPid = targetPid;
    if (actualTargetPid == 0 && front) {
        actualTargetPid = front.processIdentifier;
    }
    
    int32_t delta = (direction == D3WheelDirectionUp) ? 3 : -3;
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    CGEventRef wheelEvent = CGEventCreateScrollWheelEvent(source, kCGScrollEventUnitLine, 1, delta);
    if (source) CFRelease(source);
    
    if (wheelEvent) {
        CGEventSetIntegerValueField(wheelEvent, kCGEventSourceUserData, kD3SyntheticEventMagicTag);
        dispatchCGEvent(wheelEvent, actualTargetPid);
        CFRelease(wheelEvent);
    }
}

@end

