//
//  D3KeyTextField.m
//  d3key
//
//  Created by sunghyuk-imac on 2016. 3. 4..
//  Updated for Diablo Helper Evolution.
//

#import "D3KeyTextField.h"
#import "D3EventTapService.h"
#import <Carbon/Carbon.h>

@interface D3KeyTextField ()
{
    id _localMonitor;
    D3InputKey *_previousKey;
}

@property (nonatomic, assign, readwrite) BOOL isCapturing;

@end

@implementation D3KeyTextField

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _inputKey = [D3InputKey emptyKey];
        _isCapturing = NO;
        _allowMouseLeft = YES;
        self.editable = NO;
        self.selectable = NO;
    }
    return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _inputKey = [D3InputKey emptyKey];
        _isCapturing = NO;
        _allowMouseLeft = YES;
        self.editable = NO;
        self.selectable = NO;
    }
    return self;
}

- (void)setInputKey:(D3InputKey *)inputKey {
    _inputKey = inputKey ?: [D3InputKey emptyKey];
    self.stringValue = [_inputKey displayString];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)canBecomeKeyView {
    return YES;
}

- (BOOL)becomeFirstResponder {
    self.isCapturing = YES;
    _previousKey = [self.inputKey copy];
    
    // 시각적 피드백: 입력 대기 중임을 파란색 텍스트로 명확하게 표시
    self.stringValue = @"<키 입력 대기 (ESC/Del: 비움)>";
    self.textColor = [NSColor systemBlueColor];
    
    // 1. 앱 내부 로컬 이벤트 모니터 (접근성 권한 여부와 무관하게 100% 즉시 동작)
    [self startLocalMonitoring];
    
    // 2. 전역 EventTap 캡처 핸들러 병행 (마우스 사이드 버튼 등 시스템 전역 이벤트 수신)
    __weak typeof(self) weakSelf = self;
    [[D3EventTapService sharedService] startCapturingKeyWithHandler:^(D3InputKey *capturedKey) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.isCapturing) return;
        [strongSelf handleCapturedKey:capturedKey];
    }];
    
    return YES;
}

- (BOOL)resignFirstResponder {
    if (self.isCapturing) {
        self.isCapturing = NO;
        // 키 입력 없이 다른 곳을 클릭해 포커스를 벗어난 경우 기존 키 복원
        [self setInputKey:_previousKey];
    }
    self.textColor = [NSColor textColor];
    [self stopLocalMonitoring];
    [[D3EventTapService sharedService] stopCapturingKey];
    return [super resignFirstResponder];
}

- (void)mouseDown:(NSEvent *)event {
    if (!self.isCapturing) {
        [self.window makeFirstResponder:self];
    }
    // 마우스 좌클릭 더블클릭으로 의도치 않게 키가 오염되는 현상 원천 차단
}

- (void)rightMouseDown:(NSEvent *)event {
    NSMenu *menu = [self contextMenu];
    [NSMenu popUpContextMenu:menu withEvent:event forView:self];
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
    return [self contextMenu];
}

- (NSMenu *)contextMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"마우스 키 선택"];
    
    if (self.allowMouseLeft) {
        NSMenuItem *itemLeft = [[NSMenuItem alloc] initWithTitle:@"🖱️ 마우스 좌클릭 (Mouse Left)" action:@selector(selectMouseAction:) keyEquivalent:@""];
        itemLeft.target = self;
        itemLeft.tag = 100;
        [menu addItem:itemLeft];
    }
    
    NSMenuItem *itemRight = [[NSMenuItem alloc] initWithTitle:@"🖱️ 마우스 우클릭 (Mouse Right)" action:@selector(selectMouseAction:) keyEquivalent:@""];
    itemRight.target = self;
    itemRight.tag = 101;
    [menu addItem:itemRight];
    
    NSMenuItem *itemWheelClick = [[NSMenuItem alloc] initWithTitle:@"🖱️ 마우스 휠 클릭 (Wheel Click)" action:@selector(selectMouseAction:) keyEquivalent:@""];
    itemWheelClick.target = self;
    itemWheelClick.tag = 102;
    [menu addItem:itemWheelClick];
    
    NSMenuItem *itemWheelUp = [[NSMenuItem alloc] initWithTitle:@"📜 마우스 휠 위로 (Wheel Up)" action:@selector(selectMouseAction:) keyEquivalent:@""];
    itemWheelUp.target = self;
    itemWheelUp.tag = 103;
    [menu addItem:itemWheelUp];
    
    NSMenuItem *itemWheelDown = [[NSMenuItem alloc] initWithTitle:@"📜 마우스 휠 아래로 (Wheel Down)" action:@selector(selectMouseAction:) keyEquivalent:@""];
    itemWheelDown.target = self;
    itemWheelDown.tag = 104;
    [menu addItem:itemWheelDown];
    
    NSMenuItem *itemBtn4 = [[NSMenuItem alloc] initWithTitle:@"🔘 사이드 버튼 4 (Button 4)" action:@selector(selectMouseAction:) keyEquivalent:@""];
    itemBtn4.target = self;
    itemBtn4.tag = 105;
    [menu addItem:itemBtn4];
    
    NSMenuItem *itemBtn5 = [[NSMenuItem alloc] initWithTitle:@"🔘 사이드 버튼 5 (Button 5)" action:@selector(selectMouseAction:) keyEquivalent:@""];
    itemBtn5.target = self;
    itemBtn5.tag = 106;
    [menu addItem:itemBtn5];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *itemClear = [[NSMenuItem alloc] initWithTitle:@"❌ 설정 해제 (없음)" action:@selector(selectMouseAction:) keyEquivalent:@""];
    itemClear.target = self;
    itemClear.tag = 999;
    [menu addItem:itemClear];
    
    return menu;
}

- (void)selectMouseAction:(NSMenuItem *)sender {
    D3InputKey *key = nil;
    switch (sender.tag) {
        case 100:
            if (self.allowMouseLeft) key = [D3InputKey keyWithMouseButton:kCGMouseButtonLeft];
            break;
        case 101:
            key = [D3InputKey keyWithMouseButton:kCGMouseButtonRight];
            break;
        case 102:
            key = [D3InputKey keyWithMouseButton:kCGMouseButtonCenter];
            break;
        case 103:
            key = [D3InputKey keyWithWheelDirection:D3WheelDirectionUp];
            break;
        case 104:
            key = [D3InputKey keyWithWheelDirection:D3WheelDirectionDown];
            break;
        case 105:
            key = [D3InputKey keyWithMouseButton:3];
            break;
        case 106:
            key = [D3InputKey keyWithMouseButton:4];
            break;
        case 999:
            key = [D3InputKey emptyKey];
            break;
        default:
            break;
    }
    if (key) {
        [self handleCapturedKey:key];
    }
}

- (void)startLocalMonitoring {
    [self stopLocalMonitoring];
    
    NSEventMask mask = NSEventMaskKeyDown | NSEventMaskFlagsChanged |
                       NSEventMaskRightMouseDown | NSEventMaskOtherMouseDown |
                       NSEventMaskScrollWheel;
    
    __weak typeof(self) weakSelf = self;
    _localMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.isCapturing) return event;
        
        // 1. 키보드 KeyDown (F1~F12, Tab, Space, 1~9, A~Z, ESC, Delete 등 전체 지원)
        if (event.type == NSEventTypeKeyDown) {
            CGKeyCode code = event.keyCode;
            
            // ESC: 키 설정 해제 (비우기)
            if (code == kVK_Escape) {
                [strongSelf handleCapturedKey:[D3InputKey emptyKey]];
                return nil;
            }
            
            // Delete (Mac Backspace 51 / 0x33) 또는 Forward Delete (117 / 0x75): 키 설정 해제 (비우기)
            if (code == kVK_Delete || code == 0x75) {
                [strongSelf handleCapturedKey:[D3InputKey emptyKey]];
                return nil;
            }
            
            // Cmd+Q, Cmd+W, Cmd+Tab, Cmd+Space 등 시스템 단축키 조합 통과
            if ((event.modifierFlags & NSEventModifierFlagCommand) && (code == kVK_ANSI_Q || code == kVK_ANSI_W || code == kVK_Tab || code == kVK_Space)) {
                return event;
            }
            
            D3InputKey *key = [D3InputKey keyWithKeyCode:code];
            [strongSelf handleCapturedKey:key];
            return nil;
        }
        
        // 2. 모디파이어 키 (Shift, Ctrl, Alt, CapsLock)
        if (event.type == NSEventTypeFlagsChanged) {
            CGKeyCode code = event.keyCode;
            // Command(55, 54) 및 Fn(63) 단독 키는 단축키로 등록하지 않음 (시스템 조합키 오등록 방지)
            if (code == 55 || code == 54 || code == 63) {
                return event;
            }
            
            BOOL isDown = NO;
            switch (code) {
                case 56: case 60: isDown = (event.modifierFlags & NSEventModifierFlagShift) != 0; break;
                case 59: case 62: isDown = (event.modifierFlags & NSEventModifierFlagControl) != 0; break;
                case 58: case 61: isDown = (event.modifierFlags & NSEventModifierFlagOption) != 0; break;
                case 57: isDown = (event.modifierFlags & NSEventModifierFlagCapsLock) != 0; break;
            }
            if (isDown) {
                D3InputKey *key = [D3InputKey keyWithKeyCode:code];
                [strongSelf handleCapturedKey:key];
                return nil;
            }
            return event;
        }
        
        // 3. 우클릭
        if (event.type == NSEventTypeRightMouseDown) {
            NSPoint loc = [strongSelf convertPoint:event.locationInWindow fromView:nil];
            if (NSPointInRect(loc, strongSelf.bounds)) {
                // 필드 내부 우클릭 시 컨텍스트 메뉴 표시
                NSMenu *menu = [strongSelf contextMenu];
                [NSMenu popUpContextMenu:menu withEvent:event forView:strongSelf];
                return nil;
            }
            return event;
        }
        
        // 4. 기타 마우스 버튼 (휠 클릭 / 4, 5번 사이드 버튼)
        if (event.type == NSEventTypeOtherMouseDown) {
            CGMouseButton btn = (CGMouseButton)event.buttonNumber;
            [strongSelf handleCapturedKey:[D3InputKey keyWithMouseButton:btn]];
            return nil;
        }
        
        // 5. 마우스 휠
        if (event.type == NSEventTypeScrollWheel) {
            if (event.deltaY > 0.1) {
                [strongSelf handleCapturedKey:[D3InputKey keyWithWheelDirection:D3WheelDirectionUp]];
                return nil;
            } else if (event.deltaY < -0.1) {
                [strongSelf handleCapturedKey:[D3InputKey keyWithWheelDirection:D3WheelDirectionDown]];
                return nil;
            }
            return event;
        }
        
        return event;
    }];
}

- (void)stopLocalMonitoring {
    if (_localMonitor) {
        [NSEvent removeMonitor:_localMonitor];
        _localMonitor = nil;
    }
}

- (void)handleCapturedKey:(D3InputKey *)capturedKey {
    if (!capturedKey) capturedKey = [D3InputKey emptyKey];
    
    // 마우스 좌클릭 금지 필드 검사
    if (!self.allowMouseLeft && capturedKey.type == D3InputTypeMouseButton && capturedKey.mouseButton == kCGMouseButtonLeft) {
        // 좌클릭 금지 필드에 좌클릭이 들어온 경우 값을 변경하거나 포커스를 풀지 않고, 단순 무시하여 키 입력을 계속 대기
        return;
    }
    
    self.isCapturing = NO;
    
    [self stopLocalMonitoring];
    [[D3EventTapService sharedService] stopCapturingKey];
    
    [self setInputKey:capturedKey];
    self.textColor = [NSColor textColor];
    
    // 델리게이트 또는 알림 센터에 변경 사항 전파하여 즉시 자동 저장 트리거 (중복 호출 방지)
    NSNotification *notif = [NSNotification notificationWithName:NSControlTextDidChangeNotification object:self];
    if (self.delegate && [self.delegate respondsToSelector:@selector(controlTextDidChange:)]) {
        [(id)self.delegate controlTextDidChange:notif];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:self];
    }
    
    [self.window makeFirstResponder:nil];
}

@end
