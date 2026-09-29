//
//  D3KeyConfig.m
//  d3key
//
//  Created by sunghyuk-imac on 2016. 3. 2..
//  Updated for Diablo Helper Evolution.
//

#import "D3KeyConfig.h"
#import <Carbon/Carbon.h>
#include "const.h"

@implementation D3KeyConfig

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _memo = @"";
        _startInputKey = [D3InputKey emptyKey];
        _stopInputKey = [D3InputKey emptyKey];
        
        _inventoryKey = [D3InputKey emptyKey];
        _skillsMenuKey = [D3InputKey emptyKey];
        _followerKey = [D3InputKey emptyKey];
        _mapKey = [D3InputKey emptyKey];
        _worldMapKey = [D3InputKey emptyKey];
        _portalKey = [D3InputKey emptyKey];
        _chatKey = [D3InputKey emptyKey];
        _whisperKey = [D3InputKey emptyKey];
        
        _skillInputKey1 = [D3InputKey emptyKey];
        _skillInputKey2 = [D3InputKey emptyKey];
        _skillInputKey3 = [D3InputKey emptyKey];
        _skillInputKey4 = [D3InputKey emptyKey];
        _skillInputKey5 = [D3InputKey emptyKey];
        _skillInputKey6 = [D3InputKey emptyKey];
        _skillInputKey7 = [D3InputKey emptyKey];
        _skillInputKey8 = [D3InputKey emptyKey];
        
        _skillCheck1 = YES;
        _skillCheck2 = YES;
        _skillCheck3 = YES;
        _skillCheck4 = YES;
        _skillCheck5 = YES;
        _skillCheck6 = YES;
        _skillCheck7 = YES;
        _skillCheck8 = YES;
        
        _skillHold1 = NO;
        _skillHold2 = NO;
        _skillHold3 = NO;
        _skillHold4 = NO;
        _skillHold5 = NO;
        _skillHold6 = NO;
        _skillHold7 = NO;
        _skillHold8 = NO;
        
        // 9. 오프너 시퀀스 초기화 (5단계)
        _openerEnabled = NO;
        _openerTriggerKey = [D3InputKey emptyKey];
        _openerSteps = [NSMutableArray array];
        for (int i = 0; i < 5; i++) {
            [_openerSteps addObject:[D3OpenerStep stepWithKey:[D3InputKey emptyKey] delayMs:150 repeatCount:1 description:@""]];
        }
        
        // 10. 연계 콤보 사이클 초기화
        _comboEnabled = NO;
        _comboGeneratorKey = [D3InputKey emptyKey];
        _comboGeneratorCount = 3;
        _comboSpenderKey = [D3InputKey emptyKey];
        _comboSpenderCount = 1;
        _comboInterval = 150;
        
        _specialKey1 = [D3InputKey emptyKey];
        _specialKey2 = [D3InputKey emptyKey];
        _specialKey3 = [D3InputKey emptyKey];
        
        _singleRepeatToggle1 = [D3InputKey emptyKey];
        _singleRepeatAction1 = [D3InputKey emptyKey];
        _singleRepeatToggle2 = [D3InputKey emptyKey];
        _singleRepeatAction2 = [D3InputKey emptyKey];
        _singleRepeatToggle3 = [D3InputKey emptyKey];
        _singleRepeatAction3 = [D3InputKey emptyKey];
        
        _questKey = [D3InputKey emptyKey];
        _speedModKey = [D3InputKey emptyKey];
        _speedModOffset = 0;
        
        _antiDisturbanceEnabled = YES;
        _selectedResolution = @"자동 감지 (현재 디스플레이)";
        
        _startKey = 0xFE;
        _stopKey1 = 0xFE; _stopKey2 = 0xFE; _stopKey3 = 0xFE; _stopKey4 = 0xFE; _stopKey5 = 0xFE;
        _skillKey1 = 0xFE; _skillKey2 = 0xFE; _skillKey3 = 0xFE; _skillKey4 = 0xFE; _skillKey5 = 0xFE; _skillKey6 = 0xFE;
        _mouseLeftKey = kCGMouseButtonLeft;
        _mouseRightKey = kCGMouseButtonRight;
    }
    return self;
}

- (void)setStartInputKey:(D3InputKey *)startInputKey {
    _startInputKey = startInputKey ?: [D3InputKey emptyKey];
    if (_startInputKey.type == D3InputTypeKeyboard && ![_startInputKey isEmpty]) {
        _startKey = _startInputKey.keyCode;
    } else {
        _startKey = 0xFE;
    }
}

+ (D3KeyConfig *)defaultKeyConfig {
    D3KeyConfig *config = [[D3KeyConfig alloc] init];
    config.memo = @"기본 설정";
    
    // 시작/종료키 기본값: `[` 키 (단일반복 `~` 키와의 충돌 방지 및 게임용 표준 단축키)
    config.startInputKey = [D3InputKey keyWithKeyCode:kVK_ANSI_LeftBracket]; // [
    config.stopInputKey = [D3InputKey keyWithKeyCode:kVK_ANSI_LeftBracket];
    
    // 인게임 종료 단축키 (D4 친화적: 소지품, 지도, 포탈, 채팅만 기본 등록. WASD 'S', 상호작용 'F', 스킬 'R' 등은 전투 방해 방지를 위해 기본 비움)
    config.inventoryKey = [D3InputKey keyWithKeyCode:kVK_ANSI_I];
    config.skillsMenuKey = [D3InputKey emptyKey];
    config.followerKey = [D3InputKey emptyKey];
    config.mapKey = [D3InputKey keyWithKeyCode:kVK_ANSI_M];
    config.worldMapKey = [D3InputKey emptyKey];
    config.portalKey = [D3InputKey keyWithKeyCode:kVK_ANSI_T];
    config.chatKey = [D3InputKey keyWithKeyCode:kVK_Return];
    config.whisperKey = [D3InputKey emptyKey];
    
    // 기술키 기본값: 1, 2, 3, 4 (1000ms)
    config.skillInputKey1 = [D3InputKey keyWithKeyCode:kVK_ANSI_1];
    config.skillDelay1 = 1000;
    config.skillCheck1 = YES;
    
    config.skillInputKey2 = [D3InputKey keyWithKeyCode:kVK_ANSI_2];
    config.skillDelay2 = 1000;
    config.skillCheck2 = YES;
    
    config.skillInputKey3 = [D3InputKey keyWithKeyCode:kVK_ANSI_3];
    config.skillDelay3 = 1000;
    config.skillCheck3 = YES;
    
    config.skillInputKey4 = [D3InputKey keyWithKeyCode:kVK_ANSI_4];
    config.skillDelay4 = 1000;
    config.skillCheck4 = YES;
    
    // 단일반복키 실전 세팅 (매뉴얼 2 명세: 아이템 자동 줍기 & 카달라 겜블)
    config.singleRepeatToggle1 = [D3InputKey keyWithKeyCode:kVK_ANSI_Grave]; // ` (Hold 시 좌클릭 연타 - 아이템 자동 줍기/포탈)
    config.singleRepeatAction1 = [D3InputKey keyWithMouseButton:kCGMouseButtonLeft];
    config.singleRepeatDelay1 = 50;
    
    config.singleRepeatToggle2 = [D3InputKey keyWithKeyCode:kVK_Tab]; // Tab (Hold 시 우클릭 연타 - 카달라 겜블)
    config.singleRepeatAction2 = [D3InputKey keyWithMouseButton:kCGMouseButtonRight];
    config.singleRepeatDelay2 = 60;
    
    config.speedModToggleMode = YES;  // 신단 버프용 토글 모드 기본 활성화
    config.soundFeedbackEnabled = YES; // 시작/종료 효과음 기본 활성화
    
    // 레거시 필드 채우기 (전투 조작 방해 방지를 위해 Space 등은 미할당)
    config.startKey = kVK_ANSI_LeftBracket;
    config.stopKey1 = 0xFE;
    config.stopKey2 = 0xFE;
    config.stopKey3 = 0xFE;
    config.stopKey4 = 0xFE;
    config.stopKey5 = 0xFE;
    config.skillKey1 = kVK_ANSI_1;
    config.skillKey2 = kVK_ANSI_2;
    config.skillKey3 = kVK_ANSI_3;
    config.skillKey4 = kVK_ANSI_4;
    
    return config;
}

#pragma mark Class Presets for Diablo 4

+ (NSArray<NSString *> *)availablePresetNames {
    return @[
        @"기본 헬퍼 (디아3/4 표준)",
        @"악마술사 (타오르는 비명 & 탈태 오프너)",
        @"원소술사 (보호막 & 번개창/탈라샤)",
        @"강령술사 (골렘/저주 & 시폭/뼈창)",
        @"야만용사 (3함성 & 소용돌이 홀드)",
        @"도적 (3콤보 포인트 연타)",
        @"혼령사 (태세 버프 & 제압 사이클)"
    ];
}

+ (D3KeyConfig *)presetWithName:(NSString *)name {
    if ([name containsString:@"악마술사"] || [name containsString:@"워록"]) return [self presetForWarlock];
    if ([name containsString:@"원소술사"]) return [self presetForSorcerer];
    if ([name containsString:@"강령술사"]) return [self presetForNecromancer];
    if ([name containsString:@"야만용사"]) return [self presetForBarbarian];
    if ([name containsString:@"도적"]) return [self presetForRogue];
    if ([name containsString:@"혼령사"]) return [self presetForSpiritborn];
    return [self presetForStandard];
}

+ (D3KeyConfig *)presetForStandard {
    return [self defaultKeyConfig];
}

+ (D3KeyConfig *)presetForWarlock {
    D3KeyConfig *config = [self defaultKeyConfig];
    config.memo = @"[악마술사] 타오르는 비명(Blazing Scream) & 탈태/인장 오프너 & 화염 폭딜";
    config.openerEnabled = YES;
    config.openerTriggerKey = [D3InputKey keyWithKeyCode:kVK_F1];
    
    // 오프너 단계: 1단계 아보디안 지배 -> 2단계 탈태(악마 형상/지배력) -> 3단계 어둠의 감옥 -> 4단계 전복의 인장
    config.openerSteps[0] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_4] delayMs:150 repeatCount:1 description:@"아보디안 지배 (시너지 소환)"];
    config.openerSteps[1] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_3] delayMs:150 repeatCount:1 description:@"탈태 (악마 형상/지배력 확보)"];
    config.openerSteps[2] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_2] delayMs:150 repeatCount:1 description:@"어둠의 감옥 (군중 제어/디버프)"];
    config.openerSteps[3] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_1] delayMs:120 repeatCount:1 description:@"인장 기술 (이동/화염 버프)"];
    
    // 본 전투 스킬: 버프/CC 유지 + 우클릭 타오르는 비명 고속 연타 난사
    config.skillInputKey1 = [D3InputKey keyWithKeyCode:kVK_ANSI_1]; config.skillDelay1 = 5000; // 인장 버프 주기적 갱신
    config.skillInputKey2 = [D3InputKey keyWithKeyCode:kVK_ANSI_2]; config.skillDelay2 = 3000; // 어둠의 감옥 CC
    config.skillInputKey3 = [D3InputKey keyWithKeyCode:kVK_ANSI_3]; config.skillDelay3 = 6000; // 탈태 지속 유지
    config.skillInputKey4 = [D3InputKey keyWithKeyCode:kVK_ANSI_4]; config.skillDelay4 = 1500; // 녹아내린 폭탄/시너지
    config.skillInputKey5 = [D3InputKey keyWithMouseButton:kCGMouseButtonRight]; config.skillDelay5 = 120; // 타오르는 비명 주력 난사
    return config;
}

+ (D3KeyConfig *)presetForSorcerer {
    D3KeyConfig *config = [self defaultKeyConfig];
    config.memo = @"[원소술사] 4원소 탈라샤/구현 스택 오프너 & 번개창/연쇄번개";
    config.openerEnabled = YES;
    config.openerTriggerKey = [D3InputKey keyWithKeyCode:kVK_F1];
    
    // 오프너 단계: 1단계 얼음갑옷(보호막) -> 2단계 순간이동 -> 3단계 번개창 -> 4단계 평타 3회(탈라샤 스택)
    config.openerSteps[0] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_1] delayMs:120 repeatCount:1 description:@"얼음 갑옷 (보호막)"];
    config.openerSteps[1] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_2] delayMs:150 repeatCount:1 description:@"순간이동 (진입)"];
    config.openerSteps[2] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_3] delayMs:200 repeatCount:1 description:@"번개창 (구현 소환)"];
    config.openerSteps[3] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_4] delayMs:150 repeatCount:3 description:@"화염탄 (4원소 스택 누적)"];
    
    // 본 전투 스킬
    config.skillInputKey1 = [D3InputKey keyWithKeyCode:kVK_ANSI_1]; config.skillDelay1 = 6000; // 얼음갑옷 쿨마다
    config.skillInputKey2 = [D3InputKey keyWithKeyCode:kVK_ANSI_2]; config.skillDelay2 = 4000; // 순간이동 쿨마다
    config.skillInputKey3 = [D3InputKey keyWithKeyCode:kVK_ANSI_3]; config.skillDelay3 = 2500; // 번개창
    config.skillInputKey4 = [D3InputKey keyWithKeyCode:kVK_ANSI_4]; config.skillDelay4 = 250;  // 기본기
    config.skillInputKey5 = [D3InputKey keyWithMouseButton:kCGMouseButtonRight]; config.skillDelay5 = 150; // 주력 연쇄번개
    return config;
}

+ (D3KeyConfig *)presetForNecromancer {
    D3KeyConfig *config = [self defaultKeyConfig];
    config.memo = @"[강령술사] 골렘/저주/촉수 오프너 & 시폭/뼈창 폭딜";
    config.openerEnabled = YES;
    config.openerTriggerKey = [D3InputKey keyWithKeyCode:kVK_F1];
    
    // 오프너 단계: 1단계 골렘 사용 -> 2단계 노화 저주 -> 3단계 시체 촉수
    config.openerSteps[0] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_1] delayMs:150 repeatCount:1 description:@"골렘 활성화"];
    config.openerSteps[1] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_2] delayMs:150 repeatCount:1 description:@"노화 저주 광역 부여"];
    config.openerSteps[2] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_3] delayMs:200 repeatCount:1 description:@"시체 촉수 군중제어"];
    
    // 본 전투 스킬
    config.skillInputKey1 = [D3InputKey keyWithKeyCode:kVK_ANSI_4]; config.skillDelay1 = 200; // 뼈창
    config.skillInputKey2 = [D3InputKey keyWithMouseButton:kCGMouseButtonRight]; config.skillDelay2 = 120; // 시체 폭발
    config.skillInputKey3 = [D3InputKey keyWithKeyCode:kVK_ANSI_2]; config.skillDelay3 = 6000; // 저주 유지
    return config;
}

+ (D3KeyConfig *)presetForBarbarian {
    D3KeyConfig *config = [self defaultKeyConfig];
    config.memo = @"[야만용사] 3함성 오프너 & 소용돌이 지속 회전(홀드)";
    config.openerEnabled = YES;
    config.openerTriggerKey = [D3InputKey keyWithKeyCode:kVK_F1];
    
    // 오프너 단계: 3중 함성 순차 시전
    config.openerSteps[0] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_1] delayMs:100 repeatCount:1 description:@"집결의 함성 (자원 생성)"];
    config.openerSteps[1] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_2] delayMs:100 repeatCount:1 description:@"도전의 외침 (피해 감소)"];
    config.openerSteps[2] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_3] delayMs:120 repeatCount:1 description:@"전장의 함성 (광폭화 진입)"];
    
    // 본 전투 스킬: 함성 쿨마다 유지 + 소용돌이 채널링 홀드 모드
    config.skillInputKey1 = [D3InputKey keyWithKeyCode:kVK_ANSI_1]; config.skillDelay1 = 7500;
    config.skillInputKey2 = [D3InputKey keyWithKeyCode:kVK_ANSI_2]; config.skillDelay2 = 7500;
    config.skillInputKey3 = [D3InputKey keyWithKeyCode:kVK_ANSI_3]; config.skillDelay3 = 7500;
    config.skillInputKey4 = [D3InputKey keyWithMouseButton:kCGMouseButtonRight];
    config.skillHold4 = YES; // 소용돌이 홀드 모드!
    return config;
}

+ (D3KeyConfig *)presetForRogue {
    D3KeyConfig *config = [self defaultKeyConfig];
    config.memo = @"[도적] 주입 오프너 & 3콤보 포인트(평타 3회 -> 회전칼날 1회) 사이클";
    config.openerEnabled = YES;
    config.openerTriggerKey = [D3InputKey keyWithKeyCode:kVK_F1];
    
    config.openerSteps[0] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_1] delayMs:120 repeatCount:1 description:@"암흑 주입 강화"];
    config.openerSteps[1] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_2] delayMs:150 repeatCount:1 description:@"그림자 걸음 (진입)"];
    
    // 도적 연계 콤보 사이클: 평타 3회 -> 회전칼날 1회
    config.comboEnabled = YES;
    config.comboGeneratorKey = [D3InputKey keyWithKeyCode:kVK_ANSI_3]; // 구멍 뚫기
    config.comboGeneratorCount = 3;
    config.comboSpenderKey = [D3InputKey keyWithMouseButton:kCGMouseButtonRight]; // 회전 칼날
    config.comboSpenderCount = 1;
    config.comboInterval = 130;
    
    config.skillInputKey1 = [D3InputKey keyWithKeyCode:kVK_ANSI_1]; config.skillDelay1 = 6000; // 암흑 주입
    config.skillInputKey2 = [D3InputKey keyWithKeyCode:kVK_ANSI_4]; config.skillDelay2 = 8000; // 질주/은신
    return config;
}

+ (D3KeyConfig *)presetForSpiritborn {
    D3KeyConfig *config = [self defaultKeyConfig];
    config.memo = @"[혼령사] 태세 버프 오프너 & 콤보 제압 사이클";
    config.openerEnabled = YES;
    config.openerTriggerKey = [D3InputKey keyWithKeyCode:kVK_F1];
    
    config.openerSteps[0] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_1] delayMs:120 repeatCount:1 description:@"태세 버프 가동"];
    config.openerSteps[1] = [D3OpenerStep stepWithKey:[D3InputKey keyWithKeyCode:kVK_ANSI_2] delayMs:150 repeatCount:1 description:@"결의 스택 누적"];
    
    config.comboEnabled = YES;
    config.comboGeneratorKey = [D3InputKey keyWithKeyCode:kVK_ANSI_3]; // 깃털 투척
    config.comboGeneratorCount = 3;
    config.comboSpenderKey = [D3InputKey keyWithMouseButton:kCGMouseButtonRight]; // 제압 폭딜기
    config.comboSpenderCount = 1;
    config.comboInterval = 140;
    
    config.skillInputKey1 = [D3InputKey keyWithKeyCode:kVK_ANSI_1]; config.skillDelay1 = 8000;
    config.skillInputKey2 = [D3InputKey keyWithKeyCode:kVK_ANSI_4]; config.skillDelay2 = 25000; // 궁극기
    return config;
}

#pragma mark Key Matching

- (BOOL)isStartKey:(D3InputKey *)key {
    if (!key || [key isEmpty]) return NO;
    // 마우스 좌클릭은 시작키로 절대 허용하지 않음 (게임 조작 및 창 클릭 간섭 방지)
    if (key.type == D3InputTypeMouseButton && key.mouseButton == kCGMouseButtonLeft) return NO;
    
    // 1. 명시적 시작키 매칭
    if (![self.startInputKey isEmpty] && [self.startInputKey isEqualToInputKey:key]) {
        return YES;
    }
    
    // 2. 레거시 지원 (startInputKey가 비어있고 레거시 startKey가 설정된 경우)
    if ([self.startInputKey isEmpty] && key.type == D3InputTypeKeyboard && self.startKey != 0 && self.startKey != 0xFE && key.keyCode == self.startKey) {
        return YES;
    }
    
    return NO;
}

- (BOOL)isStopKey:(D3InputKey *)key {
    if (!key || [key isEmpty]) return NO;
    // 마우스 좌클릭은 종료키로 허용하지 않음 (매 이동/공격 시 헬퍼 정지 방지)
    if (key.type == D3InputTypeMouseButton && key.mouseButton == kCGMouseButtonLeft) return NO;
    
    // 1. 명시적 종료키 매칭
    if (![self.stopInputKey isEmpty] && [self.stopInputKey isEqualToInputKey:key]) {
        return YES;
    }
    
    // 2. 미설정 시 기본값 '[' (33) 매칭
    if ([self.stopInputKey isEmpty] && key.type == D3InputTypeKeyboard && key.keyCode == kVK_ANSI_LeftBracket) {
        return YES;
    }
    
    
    // 4. 인게임 연동 종료키 (8개)
    if (![self.inventoryKey isEmpty] && [self.inventoryKey isEqualToInputKey:key]) return YES;
    if (![self.skillsMenuKey isEmpty] && [self.skillsMenuKey isEqualToInputKey:key]) return YES;
    if (![self.followerKey isEmpty] && [self.followerKey isEqualToInputKey:key]) return YES;
    if (![self.mapKey isEmpty] && [self.mapKey isEqualToInputKey:key]) return YES;
    if (![self.worldMapKey isEmpty] && [self.worldMapKey isEqualToInputKey:key]) return YES;
    if (![self.portalKey isEmpty] && [self.portalKey isEqualToInputKey:key]) return YES;
    if (![self.chatKey isEmpty] && [self.chatKey isEqualToInputKey:key]) return YES;
    if (![self.whisperKey isEmpty] && [self.whisperKey isEqualToInputKey:key]) return YES;
    
    return NO;
}

- (BOOL)isLegacyStartKey:(CGKeyCode)keyCode {
    return [self isStartKey:[D3InputKey keyWithKeyCode:keyCode]];
}

- (BOOL)isLegacyStopKey:(CGKeyCode)keyCode {
    return [self isStopKey:[D3InputKey keyWithKeyCode:keyCode]];
}

#pragma mark Index Accessors

- (D3InputKey *)skillInputKeyAtIndex:(NSInteger)index {
    switch (index) {
        case 1: return self.skillInputKey1;
        case 2: return self.skillInputKey2;
        case 3: return self.skillInputKey3;
        case 4: return self.skillInputKey4;
        case 5: return self.skillInputKey5;
        case 6: return self.skillInputKey6;
        case 7: return self.skillInputKey7;
        case 8: return self.skillInputKey8;
        default: return [D3InputKey emptyKey];
    }
}

- (NSUInteger)skillDelayAtIndex:(NSInteger)index {
    switch (index) {
        case 1: return self.skillDelay1;
        case 2: return self.skillDelay2;
        case 3: return self.skillDelay3;
        case 4: return self.skillDelay4;
        case 5: return self.skillDelay5;
        case 6: return self.skillDelay6;
        case 7: return self.skillDelay7;
        case 8: return self.skillDelay8;
        default: return 0;
    }
}

- (BOOL)skillCheckAtIndex:(NSInteger)index {
    switch (index) {
        case 1: return self.skillCheck1;
        case 2: return self.skillCheck2;
        case 3: return self.skillCheck3;
        case 4: return self.skillCheck4;
        case 5: return self.skillCheck5;
        case 6: return self.skillCheck6;
        case 7: return self.skillCheck7;
        case 8: return self.skillCheck8;
        default: return NO;
    }
}

- (BOOL)skillHoldAtIndex:(NSInteger)index {
    switch (index) {
        case 1: return self.skillHold1;
        case 2: return self.skillHold2;
        case 3: return self.skillHold3;
        case 4: return self.skillHold4;
        case 5: return self.skillHold5;
        case 6: return self.skillHold6;
        case 7: return self.skillHold7;
        case 8: return self.skillHold8;
        default: return NO;
    }
}

- (void)setSkillHold:(BOOL)hold atIndex:(NSInteger)index {
    switch (index) {
        case 1: self.skillHold1 = hold; break;
        case 2: self.skillHold2 = hold; break;
        case 3: self.skillHold3 = hold; break;
        case 4: self.skillHold4 = hold; break;
        case 5: self.skillHold5 = hold; break;
        case 6: self.skillHold6 = hold; break;
        case 7: self.skillHold7 = hold; break;
        case 8: self.skillHold8 = hold; break;
    }
}

- (D3OpenerStep *)openerStepAtIndex:(NSInteger)index {
    NSInteger i = index - 1;
    if (i >= 0 && i < self.openerSteps.count) {
        return self.openerSteps[i];
    }
    return [D3OpenerStep stepWithKey:[D3InputKey emptyKey] delayMs:150 repeatCount:1 description:@""];
}

- (void)setOpenerStep:(D3OpenerStep *)step atIndex:(NSInteger)index {
    NSInteger i = index - 1;
    if (i >= 0 && i < 5) {
        while (self.openerSteps.count <= i) {
            [self.openerSteps addObject:[D3OpenerStep stepWithKey:[D3InputKey emptyKey] delayMs:150 repeatCount:1 description:@""]];
        }
        self.openerSteps[i] = step ?: [D3OpenerStep stepWithKey:[D3InputKey emptyKey] delayMs:150 repeatCount:1 description:@""];
    }
}

- (D3InputKey *)specialKeyAtIndex:(NSInteger)index {
    switch (index) {
        case 1: return self.specialKey1;
        case 2: return self.specialKey2;
        case 3: return self.specialKey3;
        default: return [D3InputKey emptyKey];
    }
}

- (BOOL)specialKeyCooldownAtIndex:(NSInteger)index {
    switch (index) {
        case 1: return self.specialKeyCooldown1;
        case 2: return self.specialKeyCooldown2;
        case 3: return self.specialKeyCooldown3;
        default: return NO;
    }
}

- (D3InputKey *)singleRepeatToggleAtIndex:(NSInteger)index {
    switch (index) {
        case 1: return self.singleRepeatToggle1;
        case 2: return self.singleRepeatToggle2;
        case 3: return self.singleRepeatToggle3;
        default: return [D3InputKey emptyKey];
    }
}

- (D3InputKey *)singleRepeatActionAtIndex:(NSInteger)index {
    switch (index) {
        case 1: return self.singleRepeatAction1;
        case 2: return self.singleRepeatAction2;
        case 3: return self.singleRepeatAction3;
        default: return [D3InputKey emptyKey];
    }
}

- (NSUInteger)singleRepeatDelayAtIndex:(NSInteger)index {
    switch (index) {
        case 1: return self.singleRepeatDelay1;
        case 2: return self.singleRepeatDelay2;
        case 3: return self.singleRepeatDelay3;
        default: return 0;
    }
}

#pragma mark Dictionary Serialization

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"memo"] = self.memo ?: @"";
    dict[@"startInputKey"] = [self.startInputKey toDictionary];
    dict[@"stopInputKey"] = [self.stopInputKey toDictionary];
    
    dict[@"inventoryKey"] = [self.inventoryKey toDictionary];
    dict[@"skillsMenuKey"] = [self.skillsMenuKey toDictionary];
    dict[@"followerKey"] = [self.followerKey toDictionary];
    dict[@"mapKey"] = [self.mapKey toDictionary];
    dict[@"worldMapKey"] = [self.worldMapKey toDictionary];
    dict[@"portalKey"] = [self.portalKey toDictionary];
    dict[@"chatKey"] = [self.chatKey toDictionary];
    dict[@"whisperKey"] = [self.whisperKey toDictionary];
    
    for (int i = 1; i <= 8; i++) {
        dict[[NSString stringWithFormat:@"skillKey%d", i]] = [[self skillInputKeyAtIndex:i] toDictionary];
        dict[[NSString stringWithFormat:@"skillDelay%d", i]] = @([self skillDelayAtIndex:i]);
        dict[[NSString stringWithFormat:@"skillCheck%d", i]] = @([self skillCheckAtIndex:i]);
        dict[[NSString stringWithFormat:@"skillHold%d", i]] = @([self skillHoldAtIndex:i]);
    }
    
    for (int i = 1; i <= 3; i++) {
        dict[[NSString stringWithFormat:@"specialKey%d", i]] = [[self specialKeyAtIndex:i] toDictionary];
        dict[[NSString stringWithFormat:@"specialCooldown%d", i]] = @([self specialKeyCooldownAtIndex:i]);
        
        dict[[NSString stringWithFormat:@"singleToggle%d", i]] = [[self singleRepeatToggleAtIndex:i] toDictionary];
        dict[[NSString stringWithFormat:@"singleAction%d", i]] = [[self singleRepeatActionAtIndex:i] toDictionary];
        dict[[NSString stringWithFormat:@"singleDelay%d", i]] = @([self singleRepeatDelayAtIndex:i]);
    }
    
    dict[@"questKey"] = [self.questKey toDictionary];
    dict[@"speedModKey"] = [self.speedModKey toDictionary];
    dict[@"speedModOffset"] = @(self.speedModOffset);
    dict[@"speedModToggleMode"] = @(self.speedModToggleMode);
    dict[@"soundFeedbackEnabled"] = @(self.soundFeedbackEnabled);
    dict[@"antiDisturbanceEnabled"] = @(self.antiDisturbanceEnabled);
    dict[@"selectedResolution"] = self.selectedResolution ?: @"자동 감지 (현재 디스플레이)";
    
    // D4 오프너 및 연계 콤보 저장
    dict[@"openerEnabled"] = @(self.openerEnabled);
    dict[@"openerTriggerKey"] = [self.openerTriggerKey toDictionary];
    NSMutableArray *openerArray = [NSMutableArray array];
    for (D3OpenerStep *s in self.openerSteps) {
        [openerArray addObject:[s toDictionary]];
    }
    dict[@"openerSteps"] = openerArray;
    
    dict[@"comboEnabled"] = @(self.comboEnabled);
    dict[@"comboGeneratorKey"] = [self.comboGeneratorKey toDictionary];
    dict[@"comboGeneratorCount"] = @(self.comboGeneratorCount);
    dict[@"comboSpenderKey"] = [self.comboSpenderKey toDictionary];
    dict[@"comboSpenderCount"] = @(self.comboSpenderCount);
    dict[@"comboInterval"] = @(self.comboInterval);
    
    return dict;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (!dict) return [self defaultKeyConfig];
    D3KeyConfig *config = [[self alloc] init];
    config.memo = dict[@"memo"] ?: @"";
    
    config.startInputKey = [D3InputKey fromDictionary:dict[@"startInputKey"]];
    config.stopInputKey = [D3InputKey fromDictionary:dict[@"stopInputKey"]];
    
    config.inventoryKey = [D3InputKey fromDictionary:dict[@"inventoryKey"]];
    config.skillsMenuKey = [D3InputKey fromDictionary:dict[@"skillsMenuKey"]];
    config.followerKey = [D3InputKey fromDictionary:dict[@"followerKey"]];
    config.mapKey = [D3InputKey fromDictionary:dict[@"mapKey"]];
    config.worldMapKey = [D3InputKey fromDictionary:dict[@"worldMapKey"]];
    config.portalKey = [D3InputKey fromDictionary:dict[@"portalKey"]];
    config.chatKey = [D3InputKey fromDictionary:dict[@"chatKey"]];
    config.whisperKey = [D3InputKey fromDictionary:dict[@"whisperKey"]];
    
    config.skillInputKey1 = [D3InputKey fromDictionary:dict[@"skillKey1"]];
    config.skillDelay1 = [dict[@"skillDelay1"] unsignedIntegerValue];
    config.skillCheck1 = dict[@"skillCheck1"] ? [dict[@"skillCheck1"] boolValue] : YES;
    
    config.skillInputKey2 = [D3InputKey fromDictionary:dict[@"skillKey2"]];
    config.skillDelay2 = [dict[@"skillDelay2"] unsignedIntegerValue];
    config.skillCheck2 = dict[@"skillCheck2"] ? [dict[@"skillCheck2"] boolValue] : YES;
    
    config.skillInputKey3 = [D3InputKey fromDictionary:dict[@"skillKey3"]];
    config.skillDelay3 = [dict[@"skillDelay3"] unsignedIntegerValue];
    config.skillCheck3 = dict[@"skillCheck3"] ? [dict[@"skillCheck3"] boolValue] : YES;
    
    config.skillInputKey4 = [D3InputKey fromDictionary:dict[@"skillKey4"]];
    config.skillDelay4 = [dict[@"skillDelay4"] unsignedIntegerValue];
    config.skillCheck4 = dict[@"skillCheck4"] ? [dict[@"skillCheck4"] boolValue] : YES;
    
    config.skillInputKey5 = [D3InputKey fromDictionary:dict[@"skillKey5"]];
    config.skillDelay5 = [dict[@"skillDelay5"] unsignedIntegerValue];
    config.skillCheck5 = dict[@"skillCheck5"] ? [dict[@"skillCheck5"] boolValue] : YES;
    
    config.skillInputKey6 = [D3InputKey fromDictionary:dict[@"skillKey6"]];
    config.skillDelay6 = [dict[@"skillDelay6"] unsignedIntegerValue];
    config.skillCheck6 = dict[@"skillCheck6"] ? [dict[@"skillCheck6"] boolValue] : YES;
    
    config.skillInputKey7 = [D3InputKey fromDictionary:dict[@"skillKey7"]];
    config.skillDelay7 = [dict[@"skillDelay7"] unsignedIntegerValue];
    config.skillCheck7 = dict[@"skillCheck7"] ? [dict[@"skillCheck7"] boolValue] : YES;
    
    config.skillInputKey8 = [D3InputKey fromDictionary:dict[@"skillKey8"]];
    config.skillDelay8 = [dict[@"skillDelay8"] unsignedIntegerValue];
    config.skillCheck8 = dict[@"skillCheck8"] ? [dict[@"skillCheck8"] boolValue] : YES;
    
    config.specialKey1 = [D3InputKey fromDictionary:dict[@"specialKey1"]];
    config.specialKeyCooldown1 = [dict[@"specialCooldown1"] boolValue];
    config.specialKey2 = [D3InputKey fromDictionary:dict[@"specialKey2"]];
    config.specialKeyCooldown2 = [dict[@"specialCooldown2"] boolValue];
    config.specialKey3 = [D3InputKey fromDictionary:dict[@"specialKey3"]];
    config.specialKeyCooldown3 = [dict[@"specialCooldown3"] boolValue];
    
    config.singleRepeatToggle1 = [D3InputKey fromDictionary:dict[@"singleToggle1"]];
    config.singleRepeatAction1 = [D3InputKey fromDictionary:dict[@"singleAction1"]];
    config.singleRepeatDelay1 = [dict[@"singleDelay1"] unsignedIntegerValue];
    
    config.singleRepeatToggle2 = [D3InputKey fromDictionary:dict[@"singleToggle2"]];
    config.singleRepeatAction2 = [D3InputKey fromDictionary:dict[@"singleAction2"]];
    config.singleRepeatDelay2 = [dict[@"singleDelay2"] unsignedIntegerValue];
    
    config.singleRepeatToggle3 = [D3InputKey fromDictionary:dict[@"singleToggle3"]];
    config.singleRepeatAction3 = [D3InputKey fromDictionary:dict[@"singleAction3"]];
    config.singleRepeatDelay3 = [dict[@"singleDelay3"] unsignedIntegerValue];
    
    config.questKey = [D3InputKey fromDictionary:dict[@"questKey"]];
    config.speedModKey = [D3InputKey fromDictionary:dict[@"speedModKey"]];
    config.speedModOffset = [dict[@"speedModOffset"] integerValue];
    config.speedModToggleMode = dict[@"speedModToggleMode"] ? [dict[@"speedModToggleMode"] boolValue] : YES;
    config.soundFeedbackEnabled = dict[@"soundFeedbackEnabled"] ? [dict[@"soundFeedbackEnabled"] boolValue] : YES;
    config.antiDisturbanceEnabled = dict[@"antiDisturbanceEnabled"] ? [dict[@"antiDisturbanceEnabled"] boolValue] : YES;
    config.selectedResolution = dict[@"selectedResolution"] ?: @"자동 감지 (현재 디스플레이)";
    
    for (int i = 1; i <= 8; i++) {
        [config setSkillHold:[dict[[NSString stringWithFormat:@"skillHold%d", i]] boolValue] atIndex:i];
    }
    
    config.openerEnabled = [dict[@"openerEnabled"] boolValue];
    config.openerTriggerKey = [D3InputKey fromDictionary:dict[@"openerTriggerKey"]];
    NSArray *openerArr = dict[@"openerSteps"];
    if (openerArr && [openerArr isKindOfClass:[NSArray class]] && openerArr.count > 0) {
        [config.openerSteps removeAllObjects];
        for (NSDictionary *stepDict in openerArr) {
            [config.openerSteps addObject:[D3OpenerStep fromDictionary:stepDict]];
        }
    }
    
    config.comboEnabled = [dict[@"comboEnabled"] boolValue];
    config.comboGeneratorKey = [D3InputKey fromDictionary:dict[@"comboGeneratorKey"]];
    id genCount = dict[@"comboGeneratorCount"];
    config.comboGeneratorCount = genCount ? [genCount unsignedIntegerValue] : 3;
    if (config.comboGeneratorCount == 0) config.comboGeneratorCount = 3;
    
    config.comboSpenderKey = [D3InputKey fromDictionary:dict[@"comboSpenderKey"]];
    id spCount = dict[@"comboSpenderCount"];
    config.comboSpenderCount = spCount ? [spCount unsignedIntegerValue] : 1;
    if (config.comboSpenderCount == 0) config.comboSpenderCount = 1;
    
    id interval = dict[@"comboInterval"];
    config.comboInterval = interval ? [interval unsignedIntegerValue] : 150;
    if (config.comboInterval == 0) config.comboInterval = 150;
    
    // Sync legacy values
    if (config.startInputKey.type == D3InputTypeKeyboard) {
        config.startKey = config.startInputKey.keyCode;
    }
    
    [config sanitize];
    
    return config;
}

- (void)sanitize {
    // 1. 시작키 및 종료키 유효성 검사 (마우스 좌클릭 및 Command 오염 원천 차단)
    if (self.startInputKey == nil) {
        self.startInputKey = [D3InputKey keyWithKeyCode:kVK_ANSI_LeftBracket];
    } else if (self.startInputKey.type == D3InputTypeMouseButton && self.startInputKey.mouseButton == kCGMouseButtonLeft) {
        self.startInputKey = [D3InputKey keyWithKeyCode:kVK_ANSI_LeftBracket];
    } else if (self.startInputKey.type == D3InputTypeKeyboard && (self.startInputKey.keyCode == 55 || self.startInputKey.keyCode == 54)) {
        self.startInputKey = [D3InputKey keyWithKeyCode:kVK_ANSI_LeftBracket];
    }
    
    if (self.startInputKey.type == D3InputTypeKeyboard && ![self.startInputKey isEmpty]) {
        self.startKey = self.startInputKey.keyCode;
    } else {
        self.startKey = 0xFE;
    }
    
    if (self.stopInputKey == nil) {
        self.stopInputKey = [D3InputKey keyWithKeyCode:kVK_ANSI_LeftBracket];
    } else if (self.stopInputKey.type == D3InputTypeMouseButton && self.stopInputKey.mouseButton == kCGMouseButtonLeft) {
        self.stopInputKey = [D3InputKey keyWithKeyCode:kVK_ANSI_LeftBracket];
    } else if (self.stopInputKey.type == D3InputTypeKeyboard && (self.stopInputKey.keyCode == 55 || self.stopInputKey.keyCode == 54)) {
        self.stopInputKey = [D3InputKey keyWithKeyCode:kVK_ANSI_LeftBracket];
    }
    
    if (self.openerTriggerKey == nil) {
        self.openerTriggerKey = [D3InputKey emptyKey];
    } else if ((self.openerTriggerKey.type == D3InputTypeMouseButton && self.openerTriggerKey.mouseButton == kCGMouseButtonLeft) ||
               (self.openerTriggerKey.type == D3InputTypeKeyboard && (self.openerTriggerKey.keyCode == 55 || self.openerTriggerKey.keyCode == 54 || self.openerTriggerKey.keyCode == 63))) {
        self.openerTriggerKey = [D3InputKey emptyKey];
    }
    
    // 2. 단일반복키 유효성 검사 (마우스 좌클릭 및 Command/Fn 오염 시 emptyKey로 안전하게 초기화)
    if (self.singleRepeatToggle1.type == D3InputTypeMouseButton && self.singleRepeatToggle1.mouseButton == kCGMouseButtonLeft) {
        self.singleRepeatToggle1 = [D3InputKey emptyKey];
    } else if (self.singleRepeatToggle1.type == D3InputTypeKeyboard && (self.singleRepeatToggle1.keyCode == 55 || self.singleRepeatToggle1.keyCode == 54 || self.singleRepeatToggle1.keyCode == 63)) {
        self.singleRepeatToggle1 = [D3InputKey emptyKey];
    }
    
    if (self.singleRepeatToggle2.type == D3InputTypeMouseButton && self.singleRepeatToggle2.mouseButton == kCGMouseButtonLeft) {
        self.singleRepeatToggle2 = [D3InputKey emptyKey];
    } else if (self.singleRepeatToggle2.type == D3InputTypeKeyboard && (self.singleRepeatToggle2.keyCode == 55 || self.singleRepeatToggle2.keyCode == 54 || self.singleRepeatToggle2.keyCode == 63)) {
        self.singleRepeatToggle2 = [D3InputKey emptyKey];
    }
    
    if (self.singleRepeatToggle3.type == D3InputTypeMouseButton && self.singleRepeatToggle3.mouseButton == kCGMouseButtonLeft) {
        self.singleRepeatToggle3 = [D3InputKey emptyKey];
    } else if (self.singleRepeatToggle3.type == D3InputTypeKeyboard && (self.singleRepeatToggle3.keyCode == 55 || self.singleRepeatToggle3.keyCode == 54 || self.singleRepeatToggle3.keyCode == 63)) {
        self.singleRepeatToggle3 = [D3InputKey emptyKey];
    }
    
    if (self.singleRepeatAction1.type == D3InputTypeKeyboard && (self.singleRepeatAction1.keyCode == 55 || self.singleRepeatAction1.keyCode == 54 || self.singleRepeatAction1.keyCode == 63)) {
        self.singleRepeatAction1 = [D3InputKey emptyKey];
    }
    if (self.singleRepeatAction2.type == D3InputTypeKeyboard && (self.singleRepeatAction2.keyCode == 55 || self.singleRepeatAction2.keyCode == 54 || self.singleRepeatAction2.keyCode == 63)) {
        self.singleRepeatAction2 = [D3InputKey emptyKey];
    }
    if (self.singleRepeatAction3.type == D3InputTypeKeyboard && (self.singleRepeatAction3.keyCode == 55 || self.singleRepeatAction3.keyCode == 54 || self.singleRepeatAction3.keyCode == 63)) {
        self.singleRepeatAction3 = [D3InputKey emptyKey];
    }
    
    // 4. 오프너 단계 수 최소 5개 보장
    if (self.openerSteps == nil) {
        self.openerSteps = [NSMutableArray array];
    }
    while (self.openerSteps.count < 5) {
        [self.openerSteps addObject:[D3OpenerStep stepWithKey:[D3InputKey emptyKey] delayMs:150 repeatCount:1 description:@""]];
    }
    if (self.comboGeneratorCount == 0) self.comboGeneratorCount = 3;
    if (self.comboSpenderCount == 0) self.comboSpenderCount = 1;
    if (self.comboInterval == 0) self.comboInterval = 150;
}

#pragma mark NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeBool:YES forKey:@"v2_format"];
    [aCoder encodeObject:self.memo forKey:@"memo"];
    [aCoder encodeBool:self.speedModToggleMode forKey:@"speedModToggleMode"];
    [aCoder encodeBool:self.soundFeedbackEnabled forKey:@"soundFeedbackEnabled"];
    [aCoder encodeObject:self.startInputKey forKey:@"startInputKey"];
    [aCoder encodeObject:self.stopInputKey forKey:@"stopInputKey"];
    
    [aCoder encodeObject:self.inventoryKey forKey:@"inventoryKey"];
    [aCoder encodeObject:self.skillsMenuKey forKey:@"skillsMenuKey"];
    [aCoder encodeObject:self.followerKey forKey:@"followerKey"];
    [aCoder encodeObject:self.mapKey forKey:@"mapKey"];
    [aCoder encodeObject:self.worldMapKey forKey:@"worldMapKey"];
    [aCoder encodeObject:self.portalKey forKey:@"portalKey"];
    [aCoder encodeObject:self.chatKey forKey:@"chatKey"];
    [aCoder encodeObject:self.whisperKey forKey:@"whisperKey"];
    
    [aCoder encodeObject:self.skillInputKey1 forKey:@"skillInputKey1"];
    [aCoder encodeObject:self.skillInputKey2 forKey:@"skillInputKey2"];
    [aCoder encodeObject:self.skillInputKey3 forKey:@"skillInputKey3"];
    [aCoder encodeObject:self.skillInputKey4 forKey:@"skillInputKey4"];
    [aCoder encodeObject:self.skillInputKey5 forKey:@"skillInputKey5"];
    [aCoder encodeObject:self.skillInputKey6 forKey:@"skillInputKey6"];
    [aCoder encodeObject:self.skillInputKey7 forKey:@"skillInputKey7"];
    [aCoder encodeObject:self.skillInputKey8 forKey:@"skillInputKey8"];
    
    [aCoder encodeInteger:self.skillDelay1 forKey:@"skillDelay1"];
    [aCoder encodeInteger:self.skillDelay2 forKey:@"skillDelay2"];
    [aCoder encodeInteger:self.skillDelay3 forKey:@"skillDelay3"];
    [aCoder encodeInteger:self.skillDelay4 forKey:@"skillDelay4"];
    [aCoder encodeInteger:self.skillDelay5 forKey:@"skillDelay5"];
    [aCoder encodeInteger:self.skillDelay6 forKey:@"skillDelay6"];
    [aCoder encodeInteger:self.skillDelay7 forKey:@"skillDelay7"];
    [aCoder encodeInteger:self.skillDelay8 forKey:@"skillDelay8"];
    
    [aCoder encodeBool:self.skillCheck1 forKey:@"skillCheck1"];
    [aCoder encodeBool:self.skillCheck2 forKey:@"skillCheck2"];
    [aCoder encodeBool:self.skillCheck3 forKey:@"skillCheck3"];
    [aCoder encodeBool:self.skillCheck4 forKey:@"skillCheck4"];
    [aCoder encodeBool:self.skillCheck5 forKey:@"skillCheck5"];
    [aCoder encodeBool:self.skillCheck6 forKey:@"skillCheck6"];
    [aCoder encodeBool:self.skillCheck7 forKey:@"skillCheck7"];
    [aCoder encodeBool:self.skillCheck8 forKey:@"skillCheck8"];
    
    [aCoder encodeObject:self.specialKey1 forKey:@"specialKey1"];
    [aCoder encodeObject:self.specialKey2 forKey:@"specialKey2"];
    [aCoder encodeObject:self.specialKey3 forKey:@"specialKey3"];
    [aCoder encodeBool:self.specialKeyCooldown1 forKey:@"specialKeyCooldown1"];
    [aCoder encodeBool:self.specialKeyCooldown2 forKey:@"specialKeyCooldown2"];
    [aCoder encodeBool:self.specialKeyCooldown3 forKey:@"specialKeyCooldown3"];
    
    [aCoder encodeObject:self.singleRepeatToggle1 forKey:@"singleRepeatToggle1"];
    [aCoder encodeObject:self.singleRepeatAction1 forKey:@"singleRepeatAction1"];
    [aCoder encodeInteger:self.singleRepeatDelay1 forKey:@"singleRepeatDelay1"];
    
    [aCoder encodeObject:self.singleRepeatToggle2 forKey:@"singleRepeatToggle2"];
    [aCoder encodeObject:self.singleRepeatAction2 forKey:@"singleRepeatAction2"];
    [aCoder encodeInteger:self.singleRepeatDelay2 forKey:@"singleRepeatDelay2"];
    
    [aCoder encodeObject:self.singleRepeatToggle3 forKey:@"singleRepeatToggle3"];
    [aCoder encodeObject:self.singleRepeatAction3 forKey:@"singleRepeatAction3"];
    [aCoder encodeInteger:self.singleRepeatDelay3 forKey:@"singleRepeatDelay3"];
    
    [aCoder encodeObject:self.questKey forKey:@"questKey"];
    [aCoder encodeObject:self.speedModKey forKey:@"speedModKey"];
    [aCoder encodeInteger:self.speedModOffset forKey:@"speedModOffset"];
    [aCoder encodeBool:self.antiDisturbanceEnabled forKey:@"antiDisturbanceEnabled"];
    [aCoder encodeObject:self.selectedResolution forKey:@"selectedResolution"];
    
    // D4 features encode
    for (int i = 1; i <= 8; i++) {
        [aCoder encodeBool:[self skillHoldAtIndex:i] forKey:[NSString stringWithFormat:@"skillHold%d", i]];
    }
    [aCoder encodeBool:self.openerEnabled forKey:@"openerEnabled"];
    [aCoder encodeObject:self.openerTriggerKey forKey:@"openerTriggerKey"];
    [aCoder encodeObject:self.openerSteps forKey:@"openerSteps"];
    [aCoder encodeBool:self.comboEnabled forKey:@"comboEnabled"];
    [aCoder encodeObject:self.comboGeneratorKey forKey:@"comboGeneratorKey"];
    [aCoder encodeInteger:self.comboGeneratorCount forKey:@"comboGeneratorCount"];
    [aCoder encodeObject:self.comboSpenderKey forKey:@"comboSpenderKey"];
    [aCoder encodeInteger:self.comboSpenderCount forKey:@"comboSpenderCount"];
    [aCoder encodeInteger:self.comboInterval forKey:@"comboInterval"];
    
    // Legacy fields
    [aCoder encodeInteger:self.startKey forKey:@"startKey"];
    [aCoder encodeInteger:self.stopKey1 forKey:@"stopKey1"];
    [aCoder encodeInteger:self.stopKey2 forKey:@"stopKey2"];
    [aCoder encodeInteger:self.stopKey3 forKey:@"stopKey3"];
    [aCoder encodeInteger:self.stopKey4 forKey:@"stopKey4"];
    [aCoder encodeInteger:self.stopKey5 forKey:@"stopKey5"];
    [aCoder encodeInteger:self.skillKey1 forKey:@"skillKey1"];
    [aCoder encodeInteger:self.skillKey2 forKey:@"skillKey2"];
    [aCoder encodeInteger:self.skillKey3 forKey:@"skillKey3"];
    [aCoder encodeInteger:self.skillKey4 forKey:@"skillKey4"];
    [aCoder encodeInteger:self.skillKey5 forKey:@"skillKey5"];
    [aCoder encodeInteger:self.skillKey6 forKey:@"skillKey6"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super init])) {
        BOOL isV2 = [aDecoder decodeBoolForKey:@"v2_format"];
        
        self.memo = [aDecoder decodeObjectForKey:@"memo"] ?: @"";
        self.startInputKey = [aDecoder decodeObjectForKey:@"startInputKey"] ?: [D3InputKey emptyKey];
        self.stopInputKey = [aDecoder decodeObjectForKey:@"stopInputKey"] ?: [D3InputKey emptyKey];
        
        self.inventoryKey = [aDecoder decodeObjectForKey:@"inventoryKey"] ?: [D3InputKey emptyKey];
        self.skillsMenuKey = [aDecoder decodeObjectForKey:@"skillsMenuKey"] ?: [D3InputKey emptyKey];
        self.followerKey = [aDecoder decodeObjectForKey:@"followerKey"] ?: [D3InputKey emptyKey];
        self.mapKey = [aDecoder decodeObjectForKey:@"mapKey"] ?: [D3InputKey emptyKey];
        self.worldMapKey = [aDecoder decodeObjectForKey:@"worldMapKey"] ?: [D3InputKey emptyKey];
        self.portalKey = [aDecoder decodeObjectForKey:@"portalKey"] ?: [D3InputKey emptyKey];
        self.chatKey = [aDecoder decodeObjectForKey:@"chatKey"] ?: [D3InputKey emptyKey];
        self.whisperKey = [aDecoder decodeObjectForKey:@"whisperKey"] ?: [D3InputKey emptyKey];
        
        self.skillInputKey1 = [aDecoder decodeObjectForKey:@"skillInputKey1"] ?: [D3InputKey emptyKey];
        self.skillInputKey2 = [aDecoder decodeObjectForKey:@"skillInputKey2"] ?: [D3InputKey emptyKey];
        self.skillInputKey3 = [aDecoder decodeObjectForKey:@"skillInputKey3"] ?: [D3InputKey emptyKey];
        self.skillInputKey4 = [aDecoder decodeObjectForKey:@"skillInputKey4"] ?: [D3InputKey emptyKey];
        self.skillInputKey5 = [aDecoder decodeObjectForKey:@"skillInputKey5"] ?: [D3InputKey emptyKey];
        self.skillInputKey6 = [aDecoder decodeObjectForKey:@"skillInputKey6"] ?: [D3InputKey emptyKey];
        self.skillInputKey7 = [aDecoder decodeObjectForKey:@"skillInputKey7"] ?: [D3InputKey emptyKey];
        self.skillInputKey8 = [aDecoder decodeObjectForKey:@"skillInputKey8"] ?: [D3InputKey emptyKey];
        
        if (isV2) {
            self.skillDelay1 = [aDecoder decodeIntegerForKey:@"skillDelay1"];
            self.skillDelay2 = [aDecoder decodeIntegerForKey:@"skillDelay2"];
            self.skillDelay3 = [aDecoder decodeIntegerForKey:@"skillDelay3"];
            self.skillDelay4 = [aDecoder decodeIntegerForKey:@"skillDelay4"];
            self.skillDelay5 = [aDecoder decodeIntegerForKey:@"skillDelay5"];
            self.skillDelay6 = [aDecoder decodeIntegerForKey:@"skillDelay6"];
            self.skillDelay7 = [aDecoder decodeIntegerForKey:@"skillDelay7"];
            self.skillDelay8 = [aDecoder decodeIntegerForKey:@"skillDelay8"];
        } else {
            id d1 = [aDecoder decodeObjectForKey:@"skillDelay1"];
            self.skillDelay1 = d1 ? [d1 unsignedIntegerValue] : [aDecoder decodeIntegerForKey:@"skillDelay1"];
            id d2 = [aDecoder decodeObjectForKey:@"skillDelay2"];
            self.skillDelay2 = d2 ? [d2 unsignedIntegerValue] : [aDecoder decodeIntegerForKey:@"skillDelay2"];
            id d3 = [aDecoder decodeObjectForKey:@"skillDelay3"];
            self.skillDelay3 = d3 ? [d3 unsignedIntegerValue] : [aDecoder decodeIntegerForKey:@"skillDelay3"];
            id d4 = [aDecoder decodeObjectForKey:@"skillDelay4"];
            self.skillDelay4 = d4 ? [d4 unsignedIntegerValue] : [aDecoder decodeIntegerForKey:@"skillDelay4"];
            id d5 = [aDecoder decodeObjectForKey:@"skillDelay5"];
            self.skillDelay5 = d5 ? [d5 unsignedIntegerValue] : [aDecoder decodeIntegerForKey:@"skillDelay5"];
            id d6 = [aDecoder decodeObjectForKey:@"skillDelay6"];
            self.skillDelay6 = d6 ? [d6 unsignedIntegerValue] : [aDecoder decodeIntegerForKey:@"skillDelay6"];
            id d7 = [aDecoder decodeObjectForKey:@"skillDelay7"];
            self.skillDelay7 = d7 ? [d7 unsignedIntegerValue] : [aDecoder decodeIntegerForKey:@"skillDelay7"];
            id d8 = [aDecoder decodeObjectForKey:@"skillDelay8"];
            self.skillDelay8 = d8 ? [d8 unsignedIntegerValue] : [aDecoder decodeIntegerForKey:@"skillDelay8"];
        }
        
        self.skillCheck1 = [aDecoder containsValueForKey:@"skillCheck1"] ? [aDecoder decodeBoolForKey:@"skillCheck1"] : YES;
        self.skillCheck2 = [aDecoder containsValueForKey:@"skillCheck2"] ? [aDecoder decodeBoolForKey:@"skillCheck2"] : YES;
        self.skillCheck3 = [aDecoder containsValueForKey:@"skillCheck3"] ? [aDecoder decodeBoolForKey:@"skillCheck3"] : YES;
        self.skillCheck4 = [aDecoder containsValueForKey:@"skillCheck4"] ? [aDecoder decodeBoolForKey:@"skillCheck4"] : YES;
        self.skillCheck5 = [aDecoder containsValueForKey:@"skillCheck5"] ? [aDecoder decodeBoolForKey:@"skillCheck5"] : YES;
        self.skillCheck6 = [aDecoder containsValueForKey:@"skillCheck6"] ? [aDecoder decodeBoolForKey:@"skillCheck6"] : YES;
        self.skillCheck7 = [aDecoder containsValueForKey:@"skillCheck7"] ? [aDecoder decodeBoolForKey:@"skillCheck7"] : YES;
        self.skillCheck8 = [aDecoder containsValueForKey:@"skillCheck8"] ? [aDecoder decodeBoolForKey:@"skillCheck8"] : YES;
        
        for (int i = 1; i <= 8; i++) {
            NSString *holdKey = [NSString stringWithFormat:@"skillHold%d", i];
            [self setSkillHold:[aDecoder decodeBoolForKey:holdKey] atIndex:i];
        }
        
        self.specialKey1 = [aDecoder decodeObjectForKey:@"specialKey1"] ?: [D3InputKey emptyKey];
        self.specialKey2 = [aDecoder decodeObjectForKey:@"specialKey2"] ?: [D3InputKey emptyKey];
        self.specialKey3 = [aDecoder decodeObjectForKey:@"specialKey3"] ?: [D3InputKey emptyKey];
        self.specialKeyCooldown1 = [aDecoder decodeBoolForKey:@"specialKeyCooldown1"];
        self.specialKeyCooldown2 = [aDecoder decodeBoolForKey:@"specialKeyCooldown2"];
        self.specialKeyCooldown3 = [aDecoder decodeBoolForKey:@"specialKeyCooldown3"];
        
        self.singleRepeatToggle1 = [aDecoder decodeObjectForKey:@"singleRepeatToggle1"] ?: [D3InputKey emptyKey];
        self.singleRepeatAction1 = [aDecoder decodeObjectForKey:@"singleRepeatAction1"] ?: [D3InputKey emptyKey];
        self.singleRepeatDelay1 = [aDecoder decodeIntegerForKey:@"singleRepeatDelay1"];
        
        self.singleRepeatToggle2 = [aDecoder decodeObjectForKey:@"singleRepeatToggle2"] ?: [D3InputKey emptyKey];
        self.singleRepeatAction2 = [aDecoder decodeObjectForKey:@"singleRepeatAction2"] ?: [D3InputKey emptyKey];
        self.singleRepeatDelay2 = [aDecoder decodeIntegerForKey:@"singleRepeatDelay2"];
        
        self.singleRepeatToggle3 = [aDecoder decodeObjectForKey:@"singleRepeatToggle3"] ?: [D3InputKey emptyKey];
        self.singleRepeatAction3 = [aDecoder decodeObjectForKey:@"singleRepeatAction3"] ?: [D3InputKey emptyKey];
        self.singleRepeatDelay3 = [aDecoder decodeIntegerForKey:@"singleRepeatDelay3"];
        
        self.questKey = [aDecoder decodeObjectForKey:@"questKey"] ?: [D3InputKey emptyKey];
        self.speedModKey = [aDecoder decodeObjectForKey:@"speedModKey"] ?: [D3InputKey emptyKey];
        self.speedModOffset = [aDecoder decodeIntegerForKey:@"speedModOffset"];
        self.speedModToggleMode = [aDecoder containsValueForKey:@"speedModToggleMode"] ? [aDecoder decodeBoolForKey:@"speedModToggleMode"] : YES;
        self.soundFeedbackEnabled = [aDecoder containsValueForKey:@"soundFeedbackEnabled"] ? [aDecoder decodeBoolForKey:@"soundFeedbackEnabled"] : YES;
        self.antiDisturbanceEnabled = [aDecoder containsValueForKey:@"antiDisturbanceEnabled"] ? [aDecoder decodeBoolForKey:@"antiDisturbanceEnabled"] : YES;
        self.selectedResolution = [aDecoder decodeObjectForKey:@"selectedResolution"] ?: @"자동 감지 (현재 디스플레이)";
        
        // D4 features decode
        self.openerEnabled = [aDecoder decodeBoolForKey:@"openerEnabled"];
        self.openerTriggerKey = [aDecoder decodeObjectForKey:@"openerTriggerKey"] ?: [D3InputKey emptyKey];
        NSArray *savedSteps = [aDecoder decodeObjectForKey:@"openerSteps"];
        if (savedSteps && [savedSteps isKindOfClass:[NSArray class]] && savedSteps.count > 0) {
            self.openerSteps = [savedSteps mutableCopy];
        } else {
            self.openerSteps = [NSMutableArray array];
            for (int i = 0; i < 5; i++) {
                [self.openerSteps addObject:[D3OpenerStep stepWithKey:[D3InputKey emptyKey] delayMs:150 repeatCount:1 description:@""]];
            }
        }
        
        self.comboEnabled = [aDecoder decodeBoolForKey:@"comboEnabled"];
        self.comboGeneratorKey = [aDecoder decodeObjectForKey:@"comboGeneratorKey"] ?: [D3InputKey emptyKey];
        self.comboGeneratorCount = [aDecoder decodeIntegerForKey:@"comboGeneratorCount"];
        if (self.comboGeneratorCount == 0) self.comboGeneratorCount = 3;
        self.comboSpenderKey = [aDecoder decodeObjectForKey:@"comboSpenderKey"] ?: [D3InputKey emptyKey];
        self.comboSpenderCount = [aDecoder decodeIntegerForKey:@"comboSpenderCount"];
        if (self.comboSpenderCount == 0) self.comboSpenderCount = 1;
        self.comboInterval = [aDecoder decodeIntegerForKey:@"comboInterval"];
        if (self.comboInterval == 0) self.comboInterval = 150;
        
        // Legacy fallback
        if (isV2) {
            self.startKey = (CGKeyCode)[aDecoder decodeIntegerForKey:@"startKey"];
        } else {
            id sKeyObj = [aDecoder decodeObjectForKey:@"startKey"];
            self.startKey = sKeyObj ? [sKeyObj unsignedShortValue] : (CGKeyCode)[aDecoder decodeIntegerForKey:@"startKey"];
        }
        if (self.startKey != 0 && self.startKey != 0xFE && [self.startInputKey isEmpty]) {
            self.startInputKey = [D3InputKey keyWithKeyCode:self.startKey];
        }
        
        for (int i = 1; i <= 6; i++) {
            CGKeyCode code = 0xFE;
            if (isV2) {
                code = (CGKeyCode)[aDecoder decodeIntegerForKey:[NSString stringWithFormat:@"skillKey%d", i]];
            } else {
                NSString *kName = [NSString stringWithFormat:@"skillKey%d", i];
                id kObj = [aDecoder decodeObjectForKey:kName];
                code = kObj ? [kObj unsignedShortValue] : (CGKeyCode)[aDecoder decodeIntegerForKey:kName];
            }
            D3InputKey *currentKey = [self skillInputKeyAtIndex:i];
            if (code != 0 && code != 0xFE && [currentKey isEmpty]) {
                D3InputKey *newKey = [D3InputKey keyWithKeyCode:code];
                switch (i) {
                    case 1: self.skillInputKey1 = newKey; break;
                    case 2: self.skillInputKey2 = newKey; break;
                    case 3: self.skillInputKey3 = newKey; break;
                    case 4: self.skillInputKey4 = newKey; break;
                    case 5: self.skillInputKey5 = newKey; break;
                    case 6: self.skillInputKey6 = newKey; break;
                }
            }
        }
    }
    return self;
}

@end
