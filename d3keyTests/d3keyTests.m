//
//  d3keyTests.m
//  d3keyTests
//
//  Created by sunghyuk-imac on 2016. 2. 12..
//  Updated for Diablo Helper Evolution.
//

#import <XCTest/XCTest.h>
#import "../d3key/D3InputKey.h"
#import "../d3key/D3KeyConfig.h"
#import "../d3key/D3DeadzoneFilter.h"
#import "../d3key/D3PresetItem.h"
#import "../d3key/D3GoogleSheetService.h"
#import "../d3key/D3LocalizationManager.h"
#import "../d3key/MainWindowController.h"
#import <Carbon/Carbon.h>

@interface d3keyTests : XCTestCase

@end

@implementation d3keyTests

- (void)testD3InputKeyParsing {
    // 1. Mouse buttons
    D3InputKey *middle = [D3InputKey keyWithString:@"Mouse Middle"];
    XCTAssertEqual(middle.type, D3InputTypeMouseButton);
    XCTAssertEqual(middle.mouseButton, kCGMouseButtonCenter);
    XCTAssertEqualObjects([middle displayString], @"Mouse Middle");
    
    D3InputKey *xbtn1 = [D3InputKey keyWithString:@"XButton1"];
    XCTAssertEqual(xbtn1.type, D3InputTypeMouseButton);
    XCTAssertEqual(xbtn1.mouseButton, (CGMouseButton)3);
    
    // 2. Mouse Wheel
    D3InputKey *wheelUp = [D3InputKey keyWithString:@"Wheel Up"];
    XCTAssertEqual(wheelUp.type, D3InputTypeMouseWheel);
    XCTAssertEqual(wheelUp.wheelDirection, D3WheelDirectionUp);
    XCTAssertEqualObjects([wheelUp displayString], @"Wheel Up");
    
    D3InputKey *wheelDown = [D3InputKey keyWithString:@"Wheel Down"];
    XCTAssertEqual(wheelDown.type, D3InputTypeMouseWheel);
    XCTAssertEqual(wheelDown.wheelDirection, D3WheelDirectionDown);
    XCTAssertEqualObjects([wheelDown displayString], @"Wheel Down");
    
    // 3. Keyboard
    D3InputKey *space = [D3InputKey keyWithString:@"Space"];
    XCTAssertEqual(space.type, D3InputTypeKeyboard);
    XCTAssertEqual(space.keyCode, (CGKeyCode)kVK_Space);
    XCTAssertEqualObjects([space displayString], @"Space");
    
    D3InputKey *key1 = [D3InputKey keyWithString:@"1"];
    XCTAssertEqual(key1.type, D3InputTypeKeyboard);
    XCTAssertEqual(key1.keyCode, (CGKeyCode)kVK_ANSI_1);
}

- (void)testD3KeyConfigSerialization {
    D3KeyConfig *config = [D3KeyConfig defaultKeyConfig];
    config.memo = @"테스트용 프로필";
    config.startInputKey = [D3InputKey keyWithString:@"Mouse Middle"];
    config.stopInputKey = [D3InputKey keyWithString:@"Mouse Middle"];
    
    config.skillInputKey1 = [D3InputKey keyWithString:@"3"];
    config.skillDelay1 = 1000;
    config.skillCheck1 = YES;
    
    config.skillInputKey5 = [D3InputKey keyWithString:@"Wheel Up"];
    config.skillDelay5 = 66;
    config.skillCheck5 = NO;
    
    config.singleRepeatToggle1 = [D3InputKey keyWithString:@"Tab"];
    config.singleRepeatAction1 = [D3InputKey keyWithString:@"Space"];
    config.singleRepeatDelay1 = 111;
    
    // 1. Dictionary serialization
    NSDictionary *dict = [config toDictionary];
    XCTAssertNotNil(dict);
    
    D3KeyConfig *restored = [D3KeyConfig fromDictionary:dict];
    XCTAssertEqualObjects(restored.memo, @"테스트용 프로필");
    XCTAssertTrue([restored.startInputKey isEqualToInputKey:config.startInputKey]);
    XCTAssertTrue([restored.skillInputKey5 isEqualToInputKey:config.skillInputKey5]);
    XCTAssertEqual(restored.skillDelay5, (NSUInteger)66);
    XCTAssertFalse(restored.skillCheck5);
    XCTAssertTrue([restored.singleRepeatToggle1 isEqualToInputKey:config.singleRepeatToggle1]);
    XCTAssertEqual(restored.singleRepeatDelay1, (NSUInteger)111);
    
    // 2. NSCoding
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:config];
    XCTAssertNotNil(data);
    D3KeyConfig *unarchived = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    XCTAssertEqualObjects(unarchived.memo, @"테스트용 프로필");
    XCTAssertTrue([unarchived.startInputKey isEqualToInputKey:config.startInputKey]);
    XCTAssertTrue([unarchived.skillInputKey5 isEqualToInputKey:config.skillInputKey5]);
}

- (void)testD3KeyConfigMatching {
    D3KeyConfig *config = [D3KeyConfig defaultKeyConfig];
    
    // Start key matching (Left Bracket [)
    D3InputKey *start = [D3InputKey keyWithKeyCode:kVK_ANSI_LeftBracket];
    XCTAssertTrue([config isStartKey:start]);
    
    // Ensure start key does NOT collide with single repeat 1 (~ Grave)
    D3InputKey *single1 = [config singleRepeatToggleAtIndex:1];
    XCTAssertFalse([config isStartKey:single1], @"Start key and single repeat 1 key must not collide!");
    
    // In-game stop key matching
    D3InputKey *inv = [D3InputKey keyWithKeyCode:kVK_ANSI_I];
    XCTAssertTrue([config isStopKey:inv]);
    
    D3InputKey *portal = [D3InputKey keyWithKeyCode:kVK_ANSI_T];
    XCTAssertTrue([config isStopKey:portal]);
    
    D3InputKey *chat = [D3InputKey keyWithKeyCode:kVK_Return];
    XCTAssertTrue([config isStopKey:chat]);
}

- (void)testDeadzoneFilter {
    NSArray<NSString *> *resolutions = [D3DeadzoneFilter supportedResolutions];
    XCTAssertTrue(resolutions.count >= 5);
    XCTAssertTrue([resolutions containsObject:@"1920 x 1080 (FHD)"]);
    XCTAssertTrue([resolutions containsObject:@"2560 x 1440 (QHD)"]);
    
    D3KeyConfig *config = [D3KeyConfig defaultKeyConfig];
    XCTAssertTrue(config.antiDisturbanceEnabled);
    XCTAssertNotNil(config.selectedResolution);
}

- (void)testSpecialKeysAndSingleRepeat {
    D3KeyConfig *config = [D3KeyConfig defaultKeyConfig];
    
    // 1. 특수키 설정 및 쿨타임 옵션
    config.specialKey1 = [D3InputKey keyWithString:@"Shift"];
    config.specialKeyCooldown1 = YES;
    
    XCTAssertTrue([[config specialKeyAtIndex:1] isEqualToInputKey:[D3InputKey keyWithString:@"Shift"]]);
    XCTAssertTrue([config specialKeyCooldownAtIndex:1]);
    
    // 2. 단일반복키 설정
    config.singleRepeatToggle2 = [D3InputKey keyWithString:@"Mouse Right"];
    config.singleRepeatAction2 = [D3InputKey keyWithString:@"1"];
    config.singleRepeatDelay2 = 50;
    
    XCTAssertTrue([[config singleRepeatToggleAtIndex:2] isEqualToInputKey:[D3InputKey keyWithString:@"Mouse Right"]]);
    XCTAssertTrue([[config singleRepeatActionAtIndex:2] isEqualToInputKey:[D3InputKey keyWithString:@"1"]]);
    XCTAssertEqual([config singleRepeatDelayAtIndex:2], (NSUInteger)50);
}

- (void)testDHelperManualFeatures {
    D3KeyConfig *config = [D3KeyConfig defaultKeyConfig];
    
    // 1. 단일반복키 기본 프리셋 검증 (아이템 줍기: 좌클릭 50ms, 카달라 겜블: 우클릭 60ms)
    XCTAssertTrue([[config singleRepeatActionAtIndex:1] isEqualToInputKey:[D3InputKey keyWithMouseButton:kCGMouseButtonLeft]]);
    XCTAssertEqual([config singleRepeatDelayAtIndex:1], (NSUInteger)50);
    
    XCTAssertTrue([[config singleRepeatActionAtIndex:2] isEqualToInputKey:[D3InputKey keyWithMouseButton:kCGMouseButtonRight]]);
    XCTAssertEqual([config singleRepeatDelayAtIndex:2], (NSUInteger)60);
    
    // 2. 신단 버프용 시간조절키 토글 모드 및 사운드 기본값 검증
    XCTAssertTrue(config.speedModToggleMode);
    XCTAssertTrue(config.soundFeedbackEnabled);
    
    // 3. 직렬화 검증
    NSDictionary *dict = [config toDictionary];
    XCTAssertEqualObjects(dict[@"speedModToggleMode"], @YES);
    XCTAssertEqualObjects(dict[@"soundFeedbackEnabled"], @YES);
    
    D3KeyConfig *restored = [D3KeyConfig fromDictionary:dict];
    XCTAssertTrue(restored.speedModToggleMode);
    XCTAssertTrue(restored.soundFeedbackEnabled);
}

- (void)testInterconnectedStability {
    D3KeyConfig *config = [D3KeyConfig defaultKeyConfig];
    
    // 1. 단축키 충돌 배제 검증: 시작/종료키(`[`)와 단일 반복키 1(`~`), 2(`Tab`)가 완전히 독립적인지 확인
    D3InputKey *startKey = config.startInputKey;
    D3InputKey *singleKey1 = [config singleRepeatToggleAtIndex:1];
    D3InputKey *singleKey2 = [config singleRepeatToggleAtIndex:2];
    
    XCTAssertFalse([startKey isEqualToInputKey:singleKey1]);
    XCTAssertFalse([startKey isEqualToInputKey:singleKey2]);
    XCTAssertFalse([singleKey1 isEqualToInputKey:singleKey2]);
    
    // 2. 인게임 정지 단축키(I, S, F, M, T, Return, R)와의 충돌 검증
    XCTAssertFalse([startKey isEqualToInputKey:config.inventoryKey]);
    XCTAssertFalse([startKey isEqualToInputKey:config.chatKey]);
    XCTAssertFalse([startKey isEqualToInputKey:config.portalKey]);
    XCTAssertFalse([singleKey1 isEqualToInputKey:config.inventoryKey]);
    XCTAssertFalse([singleKey1 isEqualToInputKey:config.chatKey]);
    XCTAssertFalse([singleKey2 isEqualToInputKey:config.inventoryKey]);
    XCTAssertFalse([singleKey2 isEqualToInputKey:config.chatKey]);
    
    // 3. 특수키 및 쿨다운 대기 모드 연계 동작 검증
    config.specialKey1 = [D3InputKey keyWithString:@"Shift"];
    config.specialKeyCooldown1 = YES;
    config.specialKey2 = [D3InputKey keyWithString:@"Control"];
    config.specialKeyCooldown2 = NO;
    
    XCTAssertTrue([config specialKeyCooldownAtIndex:1]);
    XCTAssertFalse([config specialKeyCooldownAtIndex:2]);
    
    // 4. 모디파이어 키 파싱 및 동일성 검증
    D3InputKey *shift1 = [D3InputKey keyWithKeyCode:56]; // Left Shift
    D3InputKey *shift2 = [D3InputKey keyWithKeyCode:56];
    XCTAssertTrue([shift1 isEqualToInputKey:shift2]);
    XCTAssertEqual([shift1 hash], [shift2 hash]);
}

- (void)testSanitizeAndMouseSafety {
    D3KeyConfig *config = [[D3KeyConfig alloc] init];
    D3InputKey *mouseLeft = [D3InputKey keyWithMouseButton:kCGMouseButtonLeft];
    
    // 1. 마우스 좌클릭이 시작/종료키에 주입되어도 isStartKey/isStopKey가 절대 트리거되지 않아야 함
    config.startInputKey = mouseLeft;
    config.stopInputKey = mouseLeft;
    XCTAssertFalse([config isStartKey:mouseLeft]);
    XCTAssertFalse([config isStopKey:mouseLeft]);
    
    // 2. 단일반복 토글에 마우스 좌클릭 오염 시나리오
    config.singleRepeatToggle1 = mouseLeft;
    config.singleRepeatAction1 = [D3InputKey emptyKey];
    config.singleRepeatDelay1 = 0;
    
    // 3. sanitize 호출 시 마우스 좌클릭 오염은 emptyKey로 안전하게 초기화되고 임의 키로 덮어쓰지 않음
    [config sanitize];
    XCTAssertFalse([config.startInputKey isEqualToInputKey:mouseLeft]);
    XCTAssertEqual(config.startInputKey.keyCode, (CGKeyCode)kVK_ANSI_LeftBracket);
    XCTAssertFalse([config.stopInputKey isEqualToInputKey:mouseLeft]);
    XCTAssertEqual(config.stopInputKey.keyCode, (CGKeyCode)kVK_ANSI_LeftBracket);
    
    XCTAssertTrue([config.singleRepeatToggle1 isEmpty]);
    XCTAssertTrue([config.singleRepeatAction1 isEmpty]);
    XCTAssertEqual(config.singleRepeatDelay1, (NSUInteger)0);
}

- (void)testSingleRepeatUserCustomizationPersistence {
    // 사용자가 커스텀 설정한 단일반복 토글/실행키가 sanitize 및 직렬화 후에도 절대 변질되지 않는지 검증
    D3KeyConfig *config = [D3KeyConfig defaultKeyConfig];
    
    // 1. 슬롯 1에 'E' 키와 우클릭 50ms 설정
    config.singleRepeatToggle1 = [D3InputKey keyWithKeyCode:kVK_ANSI_E];
    config.singleRepeatAction1 = [D3InputKey keyWithMouseButton:kCGMouseButtonRight];
    config.singleRepeatDelay1 = 50;
    
    // 2. 슬롯 2는 비움
    config.singleRepeatToggle2 = [D3InputKey emptyKey];
    config.singleRepeatAction2 = [D3InputKey emptyKey];
    config.singleRepeatDelay2 = 0;
    
    // 3. 슬롯 3에 마우스 휠 아래(Wheel Down)와 1번 키 설정
    config.singleRepeatToggle3 = [D3InputKey keyWithWheelDirection:D3WheelDirectionDown];
    config.singleRepeatAction3 = [D3InputKey keyWithKeyCode:kVK_ANSI_1];
    config.singleRepeatDelay3 = 100;
    
    [config sanitize];
    
    // Sanitize 후에도 사용자 설정이 100% 보존되는지 확인
    XCTAssertEqual(config.singleRepeatToggle1.keyCode, (CGKeyCode)kVK_ANSI_E);
    XCTAssertEqual(config.singleRepeatAction1.mouseButton, (CGMouseButton)kCGMouseButtonRight);
    XCTAssertEqual(config.singleRepeatDelay1, (NSUInteger)50);
    
    XCTAssertTrue([config.singleRepeatToggle2 isEmpty]);
    XCTAssertTrue([config.singleRepeatAction2 isEmpty]);
    XCTAssertEqual(config.singleRepeatDelay2, (NSUInteger)0);
    
    XCTAssertEqual(config.singleRepeatToggle3.wheelDirection, D3WheelDirectionDown);
    XCTAssertEqual(config.singleRepeatAction3.keyCode, (CGKeyCode)kVK_ANSI_1);
    XCTAssertEqual(config.singleRepeatDelay3, (NSUInteger)100);
    
    // 4. Dictionary 직렬화 / 역직렬화 후 보존 검증
    NSDictionary *dict = [config toDictionary];
    D3KeyConfig *restored = [D3KeyConfig fromDictionary:dict];
    
    XCTAssertEqual(restored.singleRepeatToggle1.keyCode, (CGKeyCode)kVK_ANSI_E);
    XCTAssertEqual(restored.singleRepeatAction1.mouseButton, (CGMouseButton)kCGMouseButtonRight);
    XCTAssertEqual(restored.singleRepeatDelay1, (NSUInteger)50);
    
    XCTAssertTrue([restored.singleRepeatToggle2 isEmpty]);
    XCTAssertTrue([restored.singleRepeatAction2 isEmpty]);
    XCTAssertEqual(restored.singleRepeatDelay2, (NSUInteger)0);
    
    XCTAssertEqual(restored.singleRepeatToggle3.wheelDirection, D3WheelDirectionDown);
    XCTAssertEqual(restored.singleRepeatAction3.keyCode, (CGKeyCode)kVK_ANSI_1);
    XCTAssertEqual(restored.singleRepeatDelay3, (NSUInteger)100);
    
    // 5. 단일반복키가 'E'일 때 '`' (Grave)를 눌러도 종료키로 간섭되지 않는지 검증
    config.stopInputKey = [D3InputKey keyWithKeyCode:kVK_ANSI_LeftBracket];
    D3InputKey *graveKey = [D3InputKey keyWithKeyCode:kVK_ANSI_Grave];
    XCTAssertFalse([config isStopKey:graveKey]);
}

- (void)testOpenerConfigurationAndSerialization {
    D3KeyConfig *config = [D3KeyConfig defaultKeyConfig];
    config.openerEnabled = YES;
    config.openerTriggerKey = [D3InputKey keyWithKeyCode:kVK_F1];
    
    D3OpenerStep *step1 = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_1] delayMs:120 repeatCount:1 description:@"얼음 갑옷"];
    D3OpenerStep *step2 = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_4] delayMs:150 repeatCount:3 description:@"평타 스택"];
    D3OpenerStep *step3 = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_2] delayMs:200 repeatCount:15 description:@"15회 반복"];
    D3OpenerStep *step4 = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_3] delayMs:250 repeatCount:20 description:@"20회 반복"];
    D3OpenerStep *step5 = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_5] delayMs:300 repeatCount:30 description:@"30회 반복"];
    
    [config setOpenerStep:step1 atIndex:1];
    [config setOpenerStep:step2 atIndex:2];
    [config setOpenerStep:step3 atIndex:3];
    [config setOpenerStep:step4 atIndex:4];
    [config setOpenerStep:step5 atIndex:5];
    
    XCTAssertTrue(config.openerEnabled);
    XCTAssertEqual([config openerStepAtIndex:1].delayMs, (NSUInteger)120);
    XCTAssertEqual([config openerStepAtIndex:1].repeatCount, (NSUInteger)1);
    XCTAssertEqualObjects([config openerStepAtIndex:1].stepDescription, @"얼음 갑옷");
    
    XCTAssertEqual([config openerStepAtIndex:2].delayMs, (NSUInteger)150);
    XCTAssertEqual([config openerStepAtIndex:2].repeatCount, (NSUInteger)3);
    XCTAssertEqualObjects([config openerStepAtIndex:2].stepDescription, @"평타 스택");

    XCTAssertEqual([config openerStepAtIndex:3].repeatCount, (NSUInteger)15);
    XCTAssertEqual([config openerStepAtIndex:4].repeatCount, (NSUInteger)20);
    XCTAssertEqual([config openerStepAtIndex:5].repeatCount, (NSUInteger)30);
    
    // Dictionary 직렬화 / 역직렬화 검증
    NSDictionary *dict = [config toDictionary];
    XCTAssertNotNil(dict);
    XCTAssertTrue([dict[@"openerEnabled"] boolValue]);
    
    D3KeyConfig *restored = [D3KeyConfig fromDictionary:dict];
    XCTAssertTrue(restored.openerEnabled);
    XCTAssertTrue([restored.openerTriggerKey isEqualToInputKey:config.openerTriggerKey]);
    XCTAssertEqual([restored openerStepAtIndex:1].delayMs, (NSUInteger)120);
    XCTAssertEqual([restored openerStepAtIndex:2].repeatCount, (NSUInteger)3);
    XCTAssertEqualObjects([restored openerStepAtIndex:2].stepDescription, @"평타 스택");
    XCTAssertEqual([restored openerStepAtIndex:3].repeatCount, (NSUInteger)15);
    XCTAssertEqual([restored openerStepAtIndex:4].repeatCount, (NSUInteger)20);
    XCTAssertEqual([restored openerStepAtIndex:5].repeatCount, (NSUInteger)30);
}

- (void)testOpenerRepeatCountUIIntegration {
    MainWindowController *controller = [[MainWindowController alloc] initWithWindowNibName:@"MainMenu"];
    (void)controller.window; // force window and UI load
    
    D3KeyConfig *config = [D3KeyConfig defaultKeyConfig];
    config.openerEnabled = YES;
    [config setOpenerStep:[D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_1] delayMs:100 repeatCount:10 description:@"10회"] atIndex:1];
    [config setOpenerStep:[D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_2] delayMs:150 repeatCount:15 description:@"15회"] atIndex:2];
    [config setOpenerStep:[D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_3] delayMs:200 repeatCount:20 description:@"20회"] atIndex:3];
    [config setOpenerStep:[D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_4] delayMs:250 repeatCount:30 description:@"30회"] atIndex:4];
    [config setOpenerStep:[D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_5] delayMs:300 repeatCount:1 description:@"1회"] atIndex:5];
    
    [controller setFieldValues:config];
    D3KeyConfig *readBack = [controller getFieldValues];
    
    XCTAssertEqual([readBack openerStepAtIndex:1].repeatCount, (NSUInteger)10);
    XCTAssertEqual([readBack openerStepAtIndex:2].repeatCount, (NSUInteger)15);
    XCTAssertEqual([readBack openerStepAtIndex:3].repeatCount, (NSUInteger)20);
    XCTAssertEqual([readBack openerStepAtIndex:4].repeatCount, (NSUInteger)30);
    XCTAssertEqual([readBack openerStepAtIndex:5].repeatCount, (NSUInteger)1);
    
    [controller close];
}

- (void)testOpenerTriggerKeyAndCheckboxBehavior {
    D3KeyConfig *config = [D3KeyConfig defaultKeyConfig];
    
    // 1. 오프너 트리거 키 변경 검증 (F2로 변경)
    config.openerTriggerKey = [D3InputKey keyWithKeyCode:kVK_F2];
    [config sanitize];
    XCTAssertEqual(config.openerTriggerKey.keyCode, (CGKeyCode)kVK_F2);
    
    // 2. 오프너 트리거 키 비우기 검증 (emptyKey로 설정 시 sanitize 후에도 유지)
    config.openerTriggerKey = [D3InputKey emptyKey];
    [config sanitize];
    XCTAssertTrue([config.openerTriggerKey isEmpty]);
    
    // 3. 오프너 비활성화 (체크박스 비선택) 검증
    config.openerEnabled = NO;
    NSDictionary *dictOff = [config toDictionary];
    D3KeyConfig *restoredOff = [D3KeyConfig fromDictionary:dictOff];
    XCTAssertFalse(restoredOff.openerEnabled);
    XCTAssertTrue([restoredOff.openerTriggerKey isEmpty]);
    
    // 4. 오프너 활성화 (체크박스 선택) 및 재직렬화 검증
    restoredOff.openerEnabled = YES;
    restoredOff.openerTriggerKey = [D3InputKey keyWithKeyCode:kVK_F1];
    NSDictionary *dictOn = [restoredOff toDictionary];
    D3KeyConfig *restoredOn = [D3KeyConfig fromDictionary:dictOn];
    XCTAssertTrue(restoredOn.openerEnabled);
    XCTAssertEqual(restoredOn.openerTriggerKey.keyCode, (CGKeyCode)kVK_F1);
    
    // 5. 마우스 좌클릭 및 Command 키 유입 시 안전하게 emptyKey로 리셋
    restoredOn.openerTriggerKey = [D3InputKey keyWithMouseButton:kCGMouseButtonLeft];
    [restoredOn sanitize];
    XCTAssertTrue([restoredOn.openerTriggerKey isEmpty]);
}

- (void)testComboConfigurationAndSerialization {
    D3KeyConfig *config = [D3KeyConfig defaultKeyConfig];
    config.comboEnabled = YES;
    config.comboGeneratorKey = [D3InputKey keyWithKeyCode:kVK_ANSI_3];
    config.comboGeneratorCount = 3;
    config.comboSpenderKey = [D3InputKey keyWithMouseButton:kCGMouseButtonRight];
    config.comboSpenderCount = 1;
    config.comboInterval = 135;
    
    NSDictionary *dict = [config toDictionary];
    XCTAssertNotNil(dict);
    XCTAssertTrue([dict[@"comboEnabled"] boolValue]);
    XCTAssertEqual([dict[@"comboGeneratorCount"] unsignedIntegerValue], (NSUInteger)3);
    XCTAssertEqual([dict[@"comboSpenderCount"] unsignedIntegerValue], (NSUInteger)1);
    XCTAssertEqual([dict[@"comboInterval"] unsignedIntegerValue], (NSUInteger)135);
    
    D3KeyConfig *restored = [D3KeyConfig fromDictionary:dict];
    XCTAssertTrue(restored.comboEnabled);
    XCTAssertTrue([restored.comboGeneratorKey isEqualToInputKey:config.comboGeneratorKey]);
    XCTAssertEqual(restored.comboGeneratorCount, (NSUInteger)3);
    XCTAssertTrue([restored.comboSpenderKey isEqualToInputKey:config.comboSpenderKey]);
    XCTAssertEqual(restored.comboSpenderCount, (NSUInteger)1);
    XCTAssertEqual(restored.comboInterval, (NSUInteger)135);
}

- (void)testSkillHoldModes {
    D3KeyConfig *config = [D3KeyConfig defaultKeyConfig];
    [config setSkillHold:YES atIndex:4]; // 4번 스킬 홀드 모드
    [config setSkillHold:NO atIndex:1];
    
    XCTAssertTrue([config skillHoldAtIndex:4]);
    XCTAssertFalse([config skillHoldAtIndex:1]);
    
    NSDictionary *dict = [config toDictionary];
    D3KeyConfig *restored = [D3KeyConfig fromDictionary:dict];
    XCTAssertTrue([restored skillHoldAtIndex:4]);
    XCTAssertFalse([restored skillHoldAtIndex:1]);
}

- (void)testClassPresets {
    // 1. 원소술사 프리셋
    D3KeyConfig *sorc = [D3KeyConfig presetForSorcerer];
    XCTAssertTrue(sorc.openerEnabled);
    XCTAssertTrue([sorc.openerTriggerKey isEqualToInputKey:[D3InputKey keyWithKeyCode:kVK_F1]]);
    XCTAssertEqual([sorc openerStepAtIndex:4].repeatCount, (NSUInteger)3); // 4원소 스택 3회
    XCTAssertTrue([sorc.memo containsString:@"원소술사"]);
    
    // 2. 강령술사 프리셋
    D3KeyConfig *necro = [D3KeyConfig presetForNecromancer];
    XCTAssertTrue(necro.openerEnabled);
    XCTAssertEqualObjects([necro openerStepAtIndex:1].stepDescription, @"골렘 활성화");
    
    // 3. 야만용사 프리셋
    D3KeyConfig *barb = [D3KeyConfig presetForBarbarian];
    XCTAssertTrue(barb.openerEnabled);
    XCTAssertTrue([barb skillHoldAtIndex:4]); // 소용돌이 홀드 모드
    
    // 4. 도적 프리셋
    D3KeyConfig *rogue = [D3KeyConfig presetForRogue];
    XCTAssertTrue(rogue.comboEnabled);
    XCTAssertEqual(rogue.comboGeneratorCount, (NSUInteger)3); // 3콤보 포인트
    XCTAssertEqual(rogue.comboSpenderCount, (NSUInteger)1);
    
    // 5. 혼령사 프리셋
    D3KeyConfig *spirit = [D3KeyConfig presetForSpiritborn];
    XCTAssertTrue(spirit.openerEnabled);
    XCTAssertTrue(spirit.comboEnabled);
    
    // 6. 악마술사 (타오르는 비명) 프리셋
    D3KeyConfig *warlock = [D3KeyConfig presetForWarlock];
    XCTAssertTrue(warlock.openerEnabled);
    XCTAssertTrue([warlock.memo containsString:@"타오르는 비명"]);
    XCTAssertEqual([warlock openerStepAtIndex:1].repeatCount, (NSUInteger)1);
    XCTAssertEqualObjects([warlock openerStepAtIndex:1].stepDescription, @"아보디안 지배 (시너지 소환)");
    XCTAssertEqualObjects([warlock openerStepAtIndex:2].stepDescription, @"탈태 (악마 형상/지배력 확보)");
    XCTAssertEqual(warlock.skillDelay5, (NSUInteger)120); // 타오르는 비명 120ms 연타
    
    // 7. 이름 매칭 프리셋
    D3KeyConfig *matched = [D3KeyConfig presetWithName:@"악마술사 (타오르는 비명 & 탈태 오프너)"];
    XCTAssertTrue([matched.memo containsString:@"악마술사"]);
}

- (void)testPresetItemSerializationAndGoogleSheetRow {
    D3KeyConfig *config = [D3KeyConfig presetForWarlock];
    D3PresetItem *item = [D3PresetItem presetWithAuthor:@"테스트유저"
                                                 season:@"시즌 6 (증오의 그릇)"
                                         characterClass:@"악마술사"
                                              buildName:@"타오르는 비명 테스트"
                                            description:@"오프너 실행 후 우클릭 난사"
                                                 config:config];
    
    XCTAssertEqualObjects(item.author, @"테스트유저");
    XCTAssertEqualObjects(item.season, @"시즌 6 (증오의 그릇)");
    XCTAssertEqualObjects(item.characterClass, @"악마술사");
    XCTAssertEqualObjects(item.buildName, @"타오르는 비명 테스트");
    XCTAssertTrue(item.configJson.length > 10);
    
    // 1. Dictionary 직렬화 및 역직렬화
    NSDictionary *dict = [item toDictionary];
    D3PresetItem *restored = [D3PresetItem fromDictionary:dict];
    XCTAssertEqualObjects(restored.author, @"테스트유저");
    XCTAssertEqualObjects(restored.buildName, @"타오르는 비명 테스트");
    
    // 2. 구글 시트 Row 변환 및 파싱
    NSArray *row = [item toGoogleSheetRow];
    XCTAssertGreaterThanOrEqual(row.count, (NSUInteger)7);
    D3PresetItem *fromRow = [D3PresetItem fromGoogleSheetRow:row];
    XCTAssertEqualObjects(fromRow.author, @"테스트유저");
    XCTAssertEqualObjects(fromRow.buildName, @"타오르는 비명 테스트");
    
    // 3. 구글 시트 TSV 생성 및 개행/탭 치환 검증
    NSString *tsv = [item toGoogleSheetTSV];
    XCTAssertTrue([tsv hasSuffix:@"\n"]);
    NSArray *tsvParts = [[tsv substringToIndex:tsv.length - 1] componentsSeparatedByString:@"\t"];
    XCTAssertEqual(tsvParts.count, (NSUInteger)7);
    
    // 4. Config 복원 검증
    D3KeyConfig *restoredConfig = [item createKeyConfig];
    XCTAssertTrue(restoredConfig.openerEnabled);
    XCTAssertEqual(restoredConfig.skillDelay5, (NSUInteger)120);
    
    // 5. 요약 텍스트 검증
    NSString *summary = [item summaryText];
    XCTAssertTrue([summary containsString:@"준비 시퀀스"]);
    XCTAssertTrue([summary containsString:@"메인 스킬"]);
}

- (void)testGoogleSheetServiceFilteringAndSeedPresets {
    D3GoogleSheetService *service = [D3GoogleSheetService sharedService];
    NSArray<D3PresetItem *> *all = service.cachedPresets;
    XCTAssertGreaterThanOrEqual(all.count, (NSUInteger)6);
    
    // 1. 시즌 필터링
    NSArray *s6 = [service filterPresetsWithSeason:@"시즌 6" characterClass:@"전체" keyword:@""];
    XCTAssertGreaterThan(s6.count, (NSUInteger)0);
    for (D3PresetItem *p in s6) {
        XCTAssertTrue([p.season containsString:@"시즌 6"]);
    }
    
    // 2. 직업 필터링
    NSArray *warlocks = [service filterPresetsWithSeason:@"전체" characterClass:@"악마술사" keyword:@""];
    XCTAssertGreaterThan(warlocks.count, (NSUInteger)0);
    for (D3PresetItem *p in warlocks) {
        XCTAssertTrue([p.characterClass containsString:@"악마술사"]);
    }
    
    // 3. 키워드 검색
    NSArray *screams = [service filterPresetsWithSeason:@"전체" characterClass:@"전체" keyword:@"비명"];
    XCTAssertGreaterThan(screams.count, (NSUInteger)0);
    for (D3PresetItem *p in screams) {
        BOOL match = [p.buildName containsString:@"비명"] || [p.presetDescription containsString:@"비명"] || [p.author containsString:@"비명"];
        XCTAssertTrue(match);
    }
    
    // 4. Apps Script 템플릿 코드 생성 검증
    NSString *templateCode = [service googleAppsScriptTemplateCode];
    XCTAssertTrue([templateCode containsString:@"doGet"]);
    XCTAssertTrue([templateCode containsString:@"doPost"]);
    XCTAssertTrue([templateCode containsString:@"SpreadsheetApp"]);
}

- (void)testStartKeySanitizationAndClearKey {
    // 1. emptyKey 검증
    D3InputKey *empty = [D3InputKey emptyKey];
    XCTAssertTrue([empty isEmpty]);
    XCTAssertEqualObjects([empty displayString], @"");
    
    // 2. isStartKey & isStopKey: 마우스 좌클릭 절대 불허 검증
    D3KeyConfig *config = [D3KeyConfig defaultKeyConfig];
    D3InputKey *mouseLeft = [D3InputKey keyWithMouseButton:kCGMouseButtonLeft];
    XCTAssertFalse([config isStartKey:mouseLeft]);
    XCTAssertFalse([config isStopKey:mouseLeft]);
    
    // 3. startInputKey가 비어있을 때 isStartKey가 NO 반환 검증 (수동 UI 시작만 허용)
    config.startInputKey = [D3InputKey emptyKey];
    D3InputKey *leftBracket = [D3InputKey keyWithKeyCode:kVK_ANSI_LeftBracket];
    XCTAssertFalse([config isStartKey:leftBracket]);
    XCTAssertFalse([config isStartKey:mouseLeft]);
    
    // 4. sanitize 검증: 마우스 좌클릭 및 Command 오염 시 기본키 '[' 복원, 빈 키는 보존
    config.startInputKey = mouseLeft;
    [config sanitize];
    XCTAssertEqualObjects([config.startInputKey displayString], @"[");
    
    config.startInputKey = [D3InputKey keyWithKeyCode:55]; // Command key
    [config sanitize];
    XCTAssertEqualObjects([config.startInputKey displayString], @"[");
    
    config.startInputKey = [D3InputKey emptyKey]; // 의도적 비우기
    [config sanitize];
    XCTAssertTrue([config.startInputKey isEmpty]); // 빈 키 유지 확인!
    
    config.stopInputKey = mouseLeft;
    [config sanitize];
    XCTAssertEqualObjects([config.stopInputKey displayString], @"[");
    
    config.openerTriggerKey = mouseLeft;
    [config sanitize];
    XCTAssertTrue([config.openerTriggerKey isEmpty]);
}

- (void)testLocalizationManager {
    D3LocalizationManager *manager = [D3LocalizationManager sharedManager];
    D3LanguageMode originalMode = manager.languageMode;
    
    // 1. Notification expectation
    __block BOOL notified = NO;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kD3LanguageChangedNotification
                                                                    object:nil
                                                                     queue:[NSOperationQueue mainQueue]
                                                                usingBlock:^(NSNotification * _Nonnull note) {
        notified = YES;
    }];
    
    // 2. Korean mode testing
    manager.languageMode = D3LanguageModeKorean;
    XCTAssertTrue(manager.isKorean);
    XCTAssertEqualObjects([manager currentLanguageCode], @"ko");
    XCTAssertEqualObjects(D3Loc(@"profile_label"), @"프로필");
    XCTAssertEqualObjects(D3Loc(@"tab_helper"), @"기본 헬퍼");
    XCTAssertEqualObjects(D3Loc(@"tab_rotation"), @"로테이션 & 준비 시퀀스");
    XCTAssertEqualObjects(D3Loc(@"tab_features"), @"단일반복 & 편의기능");
    XCTAssertEqualObjects(D3Loc(@"menu_start"), @"동작 시작");
    XCTAssertEqualObjects([manager localizedPresetName:@"원소술사 (번개창 & 탈 라샤)"], @"원소술사 (번개창 & 탈 라샤)");
    XCTAssertEqualObjects([manager localizedPresetName:@"악마술사 (타오르는 비명 & 탈태 오프너)"], @"악마술사 (타오르는 비명 & 탈태 오프너)");
    
    // 3. English mode testing
    notified = NO;
    manager.languageMode = D3LanguageModeEnglish;
    XCTAssertFalse(manager.isKorean);
    XCTAssertEqualObjects([manager currentLanguageCode], @"en");
    XCTAssertTrue(notified);
    XCTAssertEqualObjects(D3Loc(@"profile_label"), @"Profile");
    XCTAssertEqualObjects(D3Loc(@"tab_helper"), @"Basic Helper");
    XCTAssertEqualObjects(D3Loc(@"tab_rotation"), @"Rotation & Opener");
    XCTAssertEqualObjects(D3Loc(@"tab_features"), @"Single Repeat & Utility");
    XCTAssertEqualObjects(D3Loc(@"menu_start"), @"Start Helper");
    XCTAssertEqualObjects([manager localizedPresetName:@"원소술사 (번개창 & 탈 라샤)"], @"Sorcerer (Lightning Spear / Tal Rasha)");
    XCTAssertEqualObjects([manager localizedPresetName:@"악마술사 (타오르는 비명 & 탈태 오프너)"], @"Warlock (Fiery Scream)");
    XCTAssertEqualObjects([manager localizedPresetName:@"야만용사 (소용돌이 채널링)"], @"Barbarian (Whirlwind Channeling)");
    XCTAssertEqualObjects([manager localizedPresetName:@"도적 (3 콤보 포인트 연계)"], @"Rogue (3 Combo Points)");
    XCTAssertEqualObjects([manager localizedPresetName:@"강령술사 (뼈창 & 시체폭발)"], @"Necromancer (Bone Spear & Corpse Expl.)");
    XCTAssertEqualObjects([manager localizedPresetName:@"혼령사 (위상 연계 & 제압)"], @"Spiritborn (Aspect & Overpower)");
    
    // 4. Fallback testing
    XCTAssertEqualObjects([manager localizedStringForKey:@"non_existing_key" default:@"FallbackValue"], @"FallbackValue");
    XCTAssertEqualObjects([manager localizedStringForKey:@"non_existing_key"], @"non_existing_key");
    
    // Cleanup
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    manager.languageMode = originalMode;
}

@end
