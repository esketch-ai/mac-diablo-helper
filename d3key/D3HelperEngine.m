//
//  D3HelperEngine.m
//  d3key
//
//  Created for Diablo Helper Evolution.
//

#import "D3HelperEngine.h"
#import "D3EventPoster.h"
#import "D3DeadzoneFilter.h"
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import "const.h"

@interface D3HelperEngine ()
{
    dispatch_queue_t _engineQueue;
    dispatch_source_t _skillTimers[8];
    dispatch_source_t _singleTimers[3];
    D3InputKey *_singleActiveKey[3];
    
    BOOL _specialActive[3];
    BOOL _questActive;
    BOOL _speedModActive;
    
    uint64_t _lastFireTime[8];
    BOOL _skillHeld[8];
    
    // 연계 콤보 사이클
    dispatch_source_t _comboTimer;
    int _comboPhase;
    NSUInteger _comboCurrentCount;
    
    // 오프너 시퀀스 세대 식별자
    uint64_t _openerGeneration;
}

@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, assign, readwrite) BOOL isOpenerRunning;
@property (nonatomic, assign, readwrite) pid_t targetPid;

- (void)startLocked;
- (void)stopLocked;
- (void)stopAllSkillTimersLocked;
- (void)stopAllSingleTimersLocked;
- (void)restartSkillTimersLocked;
- (void)triggerOpenerLocked;
- (void)notifyOpenerStateChanged:(BOOL)isOpenerRunning;

@end

@implementation D3HelperEngine

+ (instancetype)sharedEngine {
    static D3HelperEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _engineQueue = dispatch_queue_create("com.dhelper.engineQueue", DISPATCH_QUEUE_SERIAL);
        _isRunning = NO;
        _isOpenerRunning = NO;
        _targetPid = 0;
        _comboTimer = NULL;
        _comboPhase = 0;
        _comboCurrentCount = 0;
        _openerGeneration = 0;
        
        for (int i = 0; i < 8; i++) {
            _skillTimers[i] = NULL;
            _lastFireTime[i] = 0;
            _skillHeld[i] = NO;
        }
        for (int i = 0; i < 3; i++) {
            _singleTimers[i] = NULL;
            _singleActiveKey[i] = nil;
            _specialActive[i] = NO;
        }
        _questActive = NO;
        _speedModActive = NO;
        
        [D3EventTapService sharedService].listener = self;
    }
    return self;
}

- (void)updateConfig:(D3KeyConfig *)newConfig {
    dispatch_async(_engineQueue, ^{
        self.config = newConfig;
        if (self.isRunning && !self.isOpenerRunning) {
            [self restartSkillTimersLocked];
        }
    });
}

#pragma mark Start / Stop

- (void)start {
    dispatch_async(_engineQueue, ^{
        [self startLocked];
    });
}

- (void)startLocked {
    if (self.isRunning) return;
    
    self.isRunning = YES;
    self.targetPid = 0; // 타깃 PID 리셋 (게임 창 활성화 시 즉시 자동 바인딩)
    _openerGeneration++;
    uint64_t gen = _openerGeneration;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(helperEngineStateChanged:)]) {
            [self.delegate helperEngineStateChanged:YES];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kD3EngineStateChangedNotification object:nil userInfo:@{@"isRunning": @YES}];
    });
    
    if (self.config.openerEnabled) {
        [self executeOpenerSequenceLockedWithGeneration:gen];
    } else {
        [self restartSkillTimersLocked];
    }
}

- (void)stop {
    dispatch_async(_engineQueue, ^{
        [self stopLocked];
    });
}

- (void)stopLocked {
    if (!self.isRunning) return;
    
    _openerGeneration++;
    self.isRunning = NO;
    if (self.isOpenerRunning) {
        self.isOpenerRunning = NO;
        [self notifyOpenerStateChanged:NO];
    }
    [self stopAllSkillTimersLocked];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(helperEngineStateChanged:)]) {
            [self.delegate helperEngineStateChanged:NO];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kD3EngineStateChangedNotification object:nil userInfo:@{@"isRunning": @NO}];
    });
}

- (void)toggle {
    dispatch_async(_engineQueue, ^{
        if (self.isRunning) {
            [self stopLocked];
        } else {
            [self startLocked];
        }
    });
}

- (void)triggerOpener {
    dispatch_async(_engineQueue, ^{
        [self triggerOpenerLocked];
    });
}

- (void)triggerOpenerLocked {
    [self stopAllSkillTimersLocked];
    _openerGeneration++;
    uint64_t gen = _openerGeneration;
    
    // 수동 오프너 실행 시 헬퍼 활성 상태로 시작
    self.isRunning = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(helperEngineStateChanged:)]) {
            [self.delegate helperEngineStateChanged:YES];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kD3EngineStateChangedNotification object:nil userInfo:@{@"isRunning": @YES}];
    });
    
    [self executeOpenerSequenceLockedWithGeneration:gen];
}

- (void)notifyOpenerStateChanged:(BOOL)isOpenerRunning {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(helperEngineOpenerStateChanged:)]) {
            [self.delegate helperEngineOpenerStateChanged:isOpenerRunning];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kD3EngineOpenerStateChangedNotification" object:nil userInfo:@{@"isOpenerRunning": @(isOpenerRunning)}];
    });
}

#pragma mark Opener Sequence Execution

- (void)executeOpenerSequenceLockedWithGeneration:(uint64_t)generation {
    if (!self.isRunning || !self.config || generation != _openerGeneration) {
        self.isOpenerRunning = NO;
        [self notifyOpenerStateChanged:NO];
        return;
    }
    
    NSMutableArray<D3OpenerStep *> *validSteps = [NSMutableArray array];
    for (int i = 1; i <= 5; i++) {
        D3OpenerStep *step = [self.config openerStepAtIndex:i];
        if (step && ![step isEmpty]) {
            [validSteps addObject:step];
        }
    }
    
    if (validSteps.count == 0) {
        self.isOpenerRunning = NO;
        [self notifyOpenerStateChanged:NO];
        [self restartSkillTimersLocked];
        return;
    }
    
    self.isOpenerRunning = YES;
    [self notifyOpenerStateChanged:YES];
    
    [self runOpenerStepAtIndex:0 steps:validSteps generation:generation];
}

- (void)runOpenerStepAtIndex:(NSUInteger)stepIndex steps:(NSArray<D3OpenerStep *> *)steps generation:(uint64_t)generation {
    if (!self.isRunning || generation != _openerGeneration) {
        self.isOpenerRunning = NO;
        [self notifyOpenerStateChanged:NO];
        return;
    }
    
    if (stepIndex >= steps.count) {
        self.isOpenerRunning = NO;
        [self notifyOpenerStateChanged:NO];
        if (self.isRunning) {
            [self restartSkillTimersLocked];
        }
        return;
    }
    
    D3OpenerStep *step = steps[stepIndex];
    [self runOpenerRepeatAtIndex:0 repeatCount:step.repeatCount forStep:step stepIndex:stepIndex steps:steps generation:generation];
}

- (void)runOpenerRepeatAtIndex:(NSUInteger)repeatIdx repeatCount:(NSUInteger)totalRepeats forStep:(D3OpenerStep *)step stepIndex:(NSUInteger)stepIndex steps:(NSArray<D3OpenerStep *> *)steps generation:(uint64_t)generation {
    if (!self.isRunning || generation != _openerGeneration) {
        self.isOpenerRunning = NO;
        [self notifyOpenerStateChanged:NO];
        return;
    }
    
    NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (front && front.processIdentifier != [NSRunningApplication currentApplication].processIdentifier) {
        self.targetPid = front.processIdentifier;
    }
    
    NSLog(@"[D3HelperEngine] Opener step %lu (%@) repeat %lu/%lu key=%@", (unsigned long)(stepIndex + 1), step.stepDescription, (unsigned long)(repeatIdx + 1), (unsigned long)totalRepeats, [step.inputKey displayString]);
    [D3EventPoster postInputKey:step.inputKey targetPid:self.targetPid];
    
    NSUInteger nextRepeat = repeatIdx + 1;
    uint64_t delayNs = (uint64_t)step.delayMs * NSEC_PER_MSEC;
    if (delayNs < 10 * NSEC_PER_MSEC) delayNs = 10 * NSEC_PER_MSEC;
    
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayNs), _engineQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (nextRepeat < totalRepeats) {
            [strongSelf runOpenerRepeatAtIndex:nextRepeat repeatCount:totalRepeats forStep:step stepIndex:stepIndex steps:steps generation:generation];
        } else {
            [strongSelf runOpenerStepAtIndex:(stepIndex + 1) steps:steps generation:generation];
        }
    });
}

#pragma mark Timer Management (Internal Queue)

- (void)stopAllSkillTimersLocked {
    for (int i = 0; i < 8; i++) {
        if (_skillTimers[i]) {
            dispatch_source_cancel(_skillTimers[i]);
            _skillTimers[i] = NULL;
        }
        // 채널링/홀드 모드 스킬 해제 (KeyUp)
        if (_skillHeld[i]) {
            D3InputKey *key = [self.config skillInputKeyAtIndex:(i + 1)];
            if (![key isEmpty]) {
                [D3EventPoster postKeyUp:key targetPid:self.targetPid];
            }
            _skillHeld[i] = NO;
        }
    }
    
    if (_comboTimer) {
        dispatch_source_cancel(_comboTimer);
        _comboTimer = NULL;
    }
    
    _speedModActive = NO;
    _questActive = NO;
    for (int i = 0; i < 3; i++) {
        _specialActive[i] = NO;
    }
}

- (void)stopAllSingleTimersLocked {
    for (int i = 0; i < 3; i++) {
        [self stopSingleRepeatLocked:i];
    }
}

- (void)restartSkillTimersLocked {
    [self stopAllSkillTimersLocked];
    if (!self.isRunning || !self.config) return;
    
    NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (front && front.processIdentifier != [NSRunningApplication currentApplication].processIdentifier) {
        self.targetPid = front.processIdentifier;
    }
    
    // 1. 일반 8개 스킬 슬롯 타이머 또는 홀드 모드 가동
    for (int i = 0; i < 8; i++) {
        NSInteger index = i + 1;
        D3InputKey *key = [self.config skillInputKeyAtIndex:index];
        NSUInteger delayMs = [self.config skillDelayAtIndex:index];
        BOOL isHold = [self.config skillHoldAtIndex:index];
        
        if ([key isEmpty]) {
            continue;
        }
        
        if (isHold) {
            // 채널링 지속 누르기 모드
            _skillHeld[i] = YES;
            [D3EventPoster postKeyDown:key targetPid:self.targetPid];
            continue;
        }
        
        if (delayMs == 0) continue;
        
        // 시간조절키가 활성화되어 있으면 딜레이 보정
        if (_speedModActive && self.config.speedModOffset != 0) {
            NSInteger adjusted = (NSInteger)delayMs + self.config.speedModOffset;
            if (adjusted < 10) adjusted = 10;
            delayMs = (NSUInteger)adjusted;
        }
        
        uint64_t intervalNs = (uint64_t)delayMs * NSEC_PER_MSEC;
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _engineQueue);
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), intervalNs, 1 * NSEC_PER_MSEC);
        
        __weak typeof(self) weakSelf = self;
        int slotIndex = i;
        dispatch_source_set_event_handler(timer, ^{
            [weakSelf fireSkillSlotLocked:slotIndex];
        });
        
        _skillTimers[i] = timer;
        dispatch_resume(timer);
    }
    
    // 2. 연계 콤보 사이클 가동 (Generator -> Spender)
    if (self.config.comboEnabled && (![self.config.comboGeneratorKey isEmpty] || ![self.config.comboSpenderKey isEmpty])) {
        NSUInteger intervalMs = self.config.comboInterval > 0 ? self.config.comboInterval : 150;
        _comboPhase = 0;
        _comboCurrentCount = 0;
        
        uint64_t intervalNs = (uint64_t)intervalMs * NSEC_PER_MSEC;
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _engineQueue);
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), intervalNs, 1 * NSEC_PER_MSEC);
        
        __weak typeof(self) weakSelf = self;
        dispatch_source_set_event_handler(timer, ^{
            [weakSelf fireComboStepLocked];
        });
        _comboTimer = timer;
        dispatch_resume(timer);
    }
}

- (void)fireComboStepLocked {
    if (!self.isRunning || !self.config || !self.config.comboEnabled) return;
    if (_questActive) return;
    
    BOOL anySpecialActive = (_specialActive[0] || _specialActive[1] || _specialActive[2]);
    if (anySpecialActive) return;
    
    NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (front && front.processIdentifier != [NSRunningApplication currentApplication].processIdentifier) {
        self.targetPid = front.processIdentifier;
    }
    
    if (_comboPhase == 0) {
        if (![self.config.comboGeneratorKey isEmpty]) {
            [D3EventPoster postInputKey:self.config.comboGeneratorKey targetPid:self.targetPid];
        }
        _comboCurrentCount++;
        if (_comboCurrentCount >= self.config.comboGeneratorCount) {
            _comboPhase = 1;
            _comboCurrentCount = 0;
        }
    } else {
        if (![self.config.comboSpenderKey isEmpty]) {
            [D3EventPoster postInputKey:self.config.comboSpenderKey targetPid:self.targetPid];
        }
        _comboCurrentCount++;
        if (_comboCurrentCount >= self.config.comboSpenderCount) {
            _comboPhase = 0;
            _comboCurrentCount = 0;
        }
    }
}

- (void)fireSkillSlotLocked:(int)slotIndex {
    if (!self.isRunning || !self.config) return;
    
    // 1. 퀘스트키가 활성화되어 있으면 모든 스킬 일시 정지
    if (_questActive) {
        return;
    }
    
    // 2. 특수키가 눌려 있고, 해당 스킬이 특수키 연동 체크되어 있으면 발송 건너뜀
    BOOL anySpecialActive = (_specialActive[0] || _specialActive[1] || _specialActive[2]);
    BOOL isChecked = [self.config skillCheckAtIndex:(slotIndex + 1)];
    if (anySpecialActive && isChecked) {
        return;
    }
    
    // 3. 타깃 PID 동적 갱신 (전면 앱 전환 시 즉시 반영)
    NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (front && front.processIdentifier != [NSRunningApplication currentApplication].processIdentifier) {
        self.targetPid = front.processIdentifier;
    }
    
    // 4. 발송
    D3InputKey *key = [self.config skillInputKeyAtIndex:(slotIndex + 1)];
    
    // 방해금지 모드: 좌클릭일 때 커서가 하단 UI 영역에 있으면 의도치 않은 UI 오픈 방지를 위해 발송 건너뜀
    if (key.type == D3InputTypeMouseButton && key.mouseButton == kCGMouseButtonLeft) {
        if (self.config.antiDisturbanceEnabled && [D3DeadzoneFilter isCursorInUIDeadzone:self.config.selectedResolution]) {
            return;
        }
    }
    
    _lastFireTime[slotIndex] = mach_absolute_time();
    NSLog(@"[D3HelperEngine] Firing slot %d: key=%@ to targetPid=%d", slotIndex + 1, [key displayString], self.targetPid);
    [D3EventPoster postInputKey:key targetPid:self.targetPid];
}

#pragma mark Single Repeat Management

- (void)startSingleRepeatLocked:(int)index withKey:(D3InputKey *)key {
    if (_singleTimers[index]) return;
    
    NSInteger slot = index + 1;
    D3InputKey *actionKey = [self.config singleRepeatActionAtIndex:slot];
    NSUInteger delayMs = [self.config singleRepeatDelayAtIndex:slot];
    
    if ([actionKey isEmpty] || delayMs == 0) return;
    if (delayMs < 10) delayMs = 10;
    
    _singleActiveKey[index] = key;
    
    // 타깃 앱 확인
    pid_t targetPid = self.targetPid;
    if (targetPid == 0) {
        targetPid = [[NSWorkspace sharedWorkspace] frontmostApplication].processIdentifier;
    }
    
    uint64_t intervalNs = (uint64_t)delayMs * NSEC_PER_MSEC;
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _engineQueue);
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), intervalNs, 1 * NSEC_PER_MSEC);
    
    __weak typeof(self) weakSelf = self;
    pid_t tPid = targetPid;
    dispatch_source_set_event_handler(timer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [D3EventPoster postInputKey:actionKey targetPid:tPid];
    });
    
    _singleTimers[index] = timer;
    dispatch_resume(timer);
}

- (void)stopSingleRepeatLocked:(int)index {
    if (_singleTimers[index]) {
        dispatch_source_cancel(_singleTimers[index]);
        _singleTimers[index] = NULL;
    }
    _singleActiveKey[index] = nil;
}

#pragma mark D3EventTapListener

- (void)onInputEvent:(D3InputKey *)inputKey isDown:(BOOL)isDown isRepeat:(BOOL)isRepeat {
    if (!self.config) return;
    
    dispatch_async(_engineQueue, ^{
        [self handleInputEventLocked:inputKey isDown:isDown isRepeat:isRepeat];
    });
}

- (void)onInputEvent:(D3InputKey *)inputKey isDown:(BOOL)isDown {
    [self onInputEvent:inputKey isDown:isDown isRepeat:NO];
}

- (void)handleInputEventLocked:(D3InputKey *)inputKey isDown:(BOOL)isDown isRepeat:(BOOL)isRepeat {
    NSLog(@"[D3HelperEngine] Input: key=%@ (code=%d, type=%d) isDown=%d isRepeat=%d (running=%d)", [inputKey displayString], (int)inputKey.keyCode, (int)inputKey.type, isDown, isRepeat, self.isRunning);
    
    // 1. 단일반복키 (1~3): 메인 헬퍼 활성 여부와 무관하게 동작
    for (int i = 0; i < 3; i++) {
        D3InputKey *toggleKey = [self.config singleRepeatToggleAtIndex:(i + 1)];
        BOOL matchesConfig = (![toggleKey isEmpty] && [toggleKey isEqualToInputKey:inputKey]);
        BOOL matchesActive = (_singleActiveKey[i] && [_singleActiveKey[i] isEqualToInputKey:inputKey]);
        
        if (inputKey.type == D3InputTypeMouseWheel && matchesConfig) {
            // 마우스 휠은 KeyUp이 없으므로 토글형 동작 (반복 입력 플래핑 방지)
            if (!isRepeat) {
                if (_singleTimers[i]) {
                    [self stopSingleRepeatLocked:i];
                } else {
                    [self startSingleRepeatLocked:i withKey:inputKey];
                }
            }
        } else if (matchesConfig || matchesActive) {
            if (isDown) {
                if (!_singleTimers[i]) {
                    [self startSingleRepeatLocked:i withKey:inputKey];
                }
            } else {
                [self stopSingleRepeatLocked:i];
            }
        }
    }
    
    // 2. 시작/종료키 판별
    BOOL isStart = [self.config isStartKey:inputKey];
    BOOL isStop = [self.config isStopKey:inputKey];
    
    // 시작키와 종료키가 동일하면 토글 (OS 키반복 무시하여 플래핑 방지 및 250ms 디바운스)
    static CFTimeInterval sLastToggleTime = 0;
    if (isStart && isStop) {
        if (isDown && !isRepeat) {
            CFTimeInterval now = CACurrentMediaTime();
            if (now - sLastToggleTime < 0.25) {
                return;
            }
            sLastToggleTime = now;
            if (self.isRunning) {
                NSLog(@"[D3HelperEngine] Toggle -> STOPPING");
                [self stopLocked];
            } else {
                NSLog(@"[D3HelperEngine] Toggle -> STARTING");
                [self startLocked];
            }
        }
        return;
    }
    
    if (isStart && isDown && !isRepeat && !self.isRunning) {
        sLastToggleTime = CACurrentMediaTime();
        NSLog(@"[D3HelperEngine] isStart matched -> STARTING");
        [self startLocked];
        return;
    }
    
    if (isStop && isDown && !isRepeat && self.isRunning) {
        sLastToggleTime = CACurrentMediaTime();
        NSLog(@"[D3HelperEngine] isStop matched on key=%@ -> STOPPING", [inputKey displayString]);
        [self stopLocked];
        return;
    }
    
    // 수동 오프너 단축키 감지 (전투 중 또는 단독 오프너 실행)
    if (![self.config.openerTriggerKey isEmpty] && [self.config.openerTriggerKey isEqualToInputKey:inputKey]) {
        if (isDown && !isRepeat) {
            NSLog(@"[D3HelperEngine] Opener trigger key matched -> executing opener");
            [self triggerOpenerLocked];
            return;
        }
    }
    
    if (!self.isRunning) {
        return;
    }
    
    // 3. 특수키 (1~3)
    for (int i = 0; i < 3; i++) {
        D3InputKey *specKey = [self.config specialKeyAtIndex:(i + 1)];
        if (![specKey isEmpty] && [specKey isEqualToInputKey:inputKey]) {
            if (_specialActive[i] == isDown) {
                return; // 상태 변화 없음 (중복 이벤트 필터링)
            }
            _specialActive[i] = isDown;
            
            // 홀드 모드 스킬들에 대한 특수키 처리 (체크된 기술은 일시 KeyUp / 해제 시 KeyDown)
            for (int s = 0; s < 8; s++) {
                if ([self.config skillHoldAtIndex:(s + 1)] && [self.config skillCheckAtIndex:(s + 1)]) {
                    D3InputKey *sKey = [self.config skillInputKeyAtIndex:(s + 1)];
                    if (![sKey isEmpty]) {
                        if (isDown && _skillHeld[s]) {
                            [D3EventPoster postKeyUp:sKey targetPid:self.targetPid];
                            _skillHeld[s] = NO;
                        } else if (!isDown && !_skillHeld[s]) {
                            _skillHeld[s] = YES;
                            [D3EventPoster postKeyDown:sKey targetPid:self.targetPid];
                        }
                    }
                }
            }
            
            if (!isDown) {
                // 다른 특수키가 아직 눌려있는지 확인
                BOOL anyOtherSpecialActive = NO;
                for (int other = 0; other < 3; other++) {
                    if (other != i && _specialActive[other]) {
                        anyOtherSpecialActive = YES;
                        break;
                    }
                }
                if (anyOtherSpecialActive) {
                    continue; // 다른 특수키가 누름 상태이면 스킬 억제 유지
                }
                
                // 특수키 해제 시: 쿨타임 대기 체크 여부에 따라 처리
                BOOL cooldownWait = [self.config specialKeyCooldownAtIndex:(i + 1)];
                if (!cooldownWait) {
                    // 체크 안 됨: 즉시 1회 발송하고, 타이머를 1주기 후로 재설정하여 중복 발사 버스트 방지
                    for (int s = 0; s < 8; s++) {
                        if ([self.config skillCheckAtIndex:(s + 1)] && ![self.config skillHoldAtIndex:(s + 1)]) {
                            D3InputKey *sKey = [self.config skillInputKeyAtIndex:(s + 1)];
                            if (![sKey isEmpty]) {
                                [D3EventPoster postInputKey:sKey targetPid:self.targetPid];
                            }
                            if (_skillTimers[s]) {
                                NSUInteger delayMs = [self.config skillDelayAtIndex:(s + 1)];
                                if (_speedModActive && self.config.speedModOffset != 0) {
                                    NSInteger adjusted = (NSInteger)delayMs + self.config.speedModOffset;
                                    if (adjusted < 10) adjusted = 10;
                                    delayMs = (NSUInteger)adjusted;
                                }
                                uint64_t intervalNs = (uint64_t)delayMs * NSEC_PER_MSEC;
                                dispatch_source_set_timer(_skillTimers[s], dispatch_time(DISPATCH_TIME_NOW, intervalNs), intervalNs, 1 * NSEC_PER_MSEC);
                            }
                        }
                    }
                } else {
                    // 쿨타임 대기: 손을 뗀 시점부터 해당 스킬의 딜레이만큼 대기 후 발송되도록 타이머 재설정
                    for (int s = 0; s < 8; s++) {
                        if ([self.config skillCheckAtIndex:(s + 1)] && ![self.config skillHoldAtIndex:(s + 1)] && _skillTimers[s]) {
                            NSUInteger delayMs = [self.config skillDelayAtIndex:(s + 1)];
                            if (_speedModActive && self.config.speedModOffset != 0) {
                                NSInteger adjusted = (NSInteger)delayMs + self.config.speedModOffset;
                                if (adjusted < 10) adjusted = 10;
                                delayMs = (NSUInteger)adjusted;
                            }
                            uint64_t intervalNs = (uint64_t)delayMs * NSEC_PER_MSEC;
                            dispatch_source_set_timer(_skillTimers[s], dispatch_time(DISPATCH_TIME_NOW, intervalNs), intervalNs, 1 * NSEC_PER_MSEC);
                        }
                    }
                }
            }
        }
    }
    
    // 4. 퀘스트키
    if (![self.config.questKey isEmpty] && [self.config.questKey isEqualToInputKey:inputKey]) {
        _questActive = isDown;
        for (int s = 0; s < 8; s++) {
            if ([self.config skillHoldAtIndex:(s + 1)]) {
                D3InputKey *sKey = [self.config skillInputKeyAtIndex:(s + 1)];
                if (![sKey isEmpty]) {
                    if (isDown && _skillHeld[s]) {
                        [D3EventPoster postKeyUp:sKey targetPid:self.targetPid];
                        _skillHeld[s] = NO;
                    } else if (!isDown && !_skillHeld[s]) {
                        _skillHeld[s] = YES;
                        [D3EventPoster postKeyDown:sKey targetPid:self.targetPid];
                    }
                }
            }
        }
    }
    
    // 5. 시간조절키 (매뉴얼 3 명세: 신단 버프 시 토글로 가속/감속 스위칭)
    if (![self.config.speedModKey isEmpty] && [self.config.speedModKey isEqualToInputKey:inputKey]) {
        if (self.config.speedModToggleMode) {
            static CFTimeInterval sLastSpeedToggleTime = 0;
            // 토글 모드: KeyDown 시 On/Off 스위칭 (OS 반복 무시)
            if (isDown && !isRepeat) {
                CFTimeInterval now = CACurrentMediaTime();
                if (now - sLastSpeedToggleTime < 0.25) {
                    return;
                }
                sLastSpeedToggleTime = now;
                _speedModActive = !_speedModActive;
                [self restartSkillTimersLocked];
            }
        } else {
            // 홀드 모드: 누르고 있는 동안만 적용
            if (_speedModActive != isDown) {
                _speedModActive = isDown;
                [self restartSkillTimersLocked];
            }
        }
    }
}

@end

