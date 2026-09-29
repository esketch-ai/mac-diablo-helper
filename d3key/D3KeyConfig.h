//
//  D3KeyConfig.h
//  d3key
//
//  Created by sunghyuk-imac on 2016. 3. 2..
//  Updated for Diablo Helper Evolution.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "D3InputKey.h"
#import "D3OpenerStep.h"

@interface D3KeyConfig : NSObject <NSCoding, NSSecureCoding>

@property (nonatomic, strong) NSString *memo;

// 1. 시작 / 종료 키
@property (nonatomic, strong) D3InputKey *startInputKey;
@property (nonatomic, strong) D3InputKey *stopInputKey;

// 2. 인게임 연동 종료 키 (8개)
@property (nonatomic, strong) D3InputKey *inventoryKey;   // 소지품 (I)
@property (nonatomic, strong) D3InputKey *skillsMenuKey;  // 기술 메뉴 (S)
@property (nonatomic, strong) D3InputKey *followerKey;    // 추종자 메뉴 (F)
@property (nonatomic, strong) D3InputKey *mapKey;        // 지도 (M)
@property (nonatomic, strong) D3InputKey *worldMapKey;   // 세계지도
@property (nonatomic, strong) D3InputKey *portalKey;     // 차원문 (T)
@property (nonatomic, strong) D3InputKey *chatKey;       // 채팅 (Enter)
@property (nonatomic, strong) D3InputKey *whisperKey;    // 귓속말 (R)

// 3. 기술키 8개 슬롯 (입력키, 딜레이ms, 특수키 연동 체크, 채널링/홀드 모드)
@property (nonatomic, strong) D3InputKey *skillInputKey1;
@property (nonatomic, strong) D3InputKey *skillInputKey2;
@property (nonatomic, strong) D3InputKey *skillInputKey3;
@property (nonatomic, strong) D3InputKey *skillInputKey4;
@property (nonatomic, strong) D3InputKey *skillInputKey5;
@property (nonatomic, strong) D3InputKey *skillInputKey6;
@property (nonatomic, strong) D3InputKey *skillInputKey7;
@property (nonatomic, strong) D3InputKey *skillInputKey8;

@property (nonatomic, assign) NSUInteger skillDelay1;
@property (nonatomic, assign) NSUInteger skillDelay2;
@property (nonatomic, assign) NSUInteger skillDelay3;
@property (nonatomic, assign) NSUInteger skillDelay4;
@property (nonatomic, assign) NSUInteger skillDelay5;
@property (nonatomic, assign) NSUInteger skillDelay6;
@property (nonatomic, assign) NSUInteger skillDelay7;
@property (nonatomic, assign) NSUInteger skillDelay8;

@property (nonatomic, assign) BOOL skillCheck1;
@property (nonatomic, assign) BOOL skillCheck2;
@property (nonatomic, assign) BOOL skillCheck3;
@property (nonatomic, assign) BOOL skillCheck4;
@property (nonatomic, assign) BOOL skillCheck5;
@property (nonatomic, assign) BOOL skillCheck6;
@property (nonatomic, assign) BOOL skillCheck7;
@property (nonatomic, assign) BOOL skillCheck8;

@property (nonatomic, assign) BOOL skillHold1;
@property (nonatomic, assign) BOOL skillHold2;
@property (nonatomic, assign) BOOL skillHold3;
@property (nonatomic, assign) BOOL skillHold4;
@property (nonatomic, assign) BOOL skillHold5;
@property (nonatomic, assign) BOOL skillHold6;
@property (nonatomic, assign) BOOL skillHold7;
@property (nonatomic, assign) BOOL skillHold8;

// 4. 특수키 (3개) & 쿨타임 대기 옵션
@property (nonatomic, strong) D3InputKey *specialKey1;
@property (nonatomic, strong) D3InputKey *specialKey2;
@property (nonatomic, strong) D3InputKey *specialKey3;
@property (nonatomic, assign) BOOL specialKeyCooldown1;
@property (nonatomic, assign) BOOL specialKeyCooldown2;
@property (nonatomic, assign) BOOL specialKeyCooldown3;

// 5. 단일반복키 (3개)
@property (nonatomic, strong) D3InputKey *singleRepeatToggle1;
@property (nonatomic, strong) D3InputKey *singleRepeatAction1;
@property (nonatomic, assign) NSUInteger singleRepeatDelay1;

@property (nonatomic, strong) D3InputKey *singleRepeatToggle2;
@property (nonatomic, strong) D3InputKey *singleRepeatAction2;
@property (nonatomic, assign) NSUInteger singleRepeatDelay2;

@property (nonatomic, strong) D3InputKey *singleRepeatToggle3;
@property (nonatomic, strong) D3InputKey *singleRepeatAction3;
@property (nonatomic, assign) NSUInteger singleRepeatDelay3;

// 6. 퀘스트키 & 시간조절키
@property (nonatomic, strong) D3InputKey *questKey;
@property (nonatomic, strong) D3InputKey *speedModKey;
@property (nonatomic, assign) NSInteger speedModOffset; // ms (양수: 느리게, 음수: 빠르게)
@property (nonatomic, assign) BOOL speedModToggleMode;  // YES: 신단 버프용 토글 모드, NO: 홀드 모드

// 7. 사운드 피드백
@property (nonatomic, assign) BOOL soundFeedbackEnabled; // 시작/종료 시 시스템 비프음 알림

// 8. 방해금지 모드 (기술키 좌클릭 시 UI 클릭 방지)
@property (nonatomic, assign) BOOL antiDisturbanceEnabled;
@property (nonatomic, strong) NSString *selectedResolution;

// 9. 디아블로4 초기 준비 / 스택 시퀀스 (Opener & Ramp-up)
@property (nonatomic, assign) BOOL openerEnabled;
@property (nonatomic, strong) D3InputKey *openerTriggerKey; // 수동 오프너 실행 단축키
@property (nonatomic, strong) NSMutableArray<D3OpenerStep *> *openerSteps;

// 10. 디아블로4 연계 콤보 사이클 (Generator -> Spender)
@property (nonatomic, assign) BOOL comboEnabled;
@property (nonatomic, strong) D3InputKey *comboGeneratorKey;
@property (nonatomic, assign) NSUInteger comboGeneratorCount;
@property (nonatomic, strong) D3InputKey *comboSpenderKey;
@property (nonatomic, assign) NSUInteger comboSpenderCount;
@property (nonatomic, assign) NSUInteger comboInterval;

// 레거시 호환 프로퍼티
@property (nonatomic, assign) CGKeyCode startKey;
@property (nonatomic, assign) CGKeyCode stopKey1;
@property (nonatomic, assign) CGKeyCode stopKey2;
@property (nonatomic, assign) CGKeyCode stopKey3;
@property (nonatomic, assign) CGKeyCode stopKey4;
@property (nonatomic, assign) CGKeyCode stopKey5;
@property (nonatomic, assign) CGKeyCode skillKey1;
@property (nonatomic, assign) CGKeyCode skillKey2;
@property (nonatomic, assign) CGKeyCode skillKey3;
@property (nonatomic, assign) CGKeyCode skillKey4;
@property (nonatomic, assign) CGKeyCode skillKey5;
@property (nonatomic, assign) CGKeyCode skillKey6;
@property (nonatomic, assign) CGKeyCode mouseLeftKey;
@property (nonatomic, assign) CGKeyCode mouseRightKey;
@property (nonatomic, assign) NSUInteger mouseLeftDelay;
@property (nonatomic, assign) NSUInteger mouseRightDelay;

+ (D3KeyConfig *)defaultKeyConfig;

// 직업별 프리셋 팩토리
+ (D3KeyConfig *)presetForWarlock;
+ (D3KeyConfig *)presetForSorcerer;
+ (D3KeyConfig *)presetForNecromancer;
+ (D3KeyConfig *)presetForBarbarian;
+ (D3KeyConfig *)presetForRogue;
+ (D3KeyConfig *)presetForSpiritborn;
+ (D3KeyConfig *)presetForStandard;
+ (NSArray<NSString *> *)availablePresetNames;
+ (D3KeyConfig *)presetWithName:(NSString *)name;

- (BOOL)isStartKey:(D3InputKey *)key;
- (BOOL)isStopKey:(D3InputKey *)key;
- (BOOL)isLegacyStartKey:(CGKeyCode)keyCode;
- (BOOL)isLegacyStopKey:(CGKeyCode)keyCode;

// 헬퍼 메소드
- (D3InputKey *)skillInputKeyAtIndex:(NSInteger)index;
- (NSUInteger)skillDelayAtIndex:(NSInteger)index;
- (BOOL)skillCheckAtIndex:(NSInteger)index;
- (BOOL)skillHoldAtIndex:(NSInteger)index;
- (void)setSkillHold:(BOOL)hold atIndex:(NSInteger)index;

- (D3OpenerStep *)openerStepAtIndex:(NSInteger)index;
- (void)setOpenerStep:(D3OpenerStep *)step atIndex:(NSInteger)index;

- (D3InputKey *)specialKeyAtIndex:(NSInteger)index;
- (BOOL)specialKeyCooldownAtIndex:(NSInteger)index;

- (D3InputKey *)singleRepeatToggleAtIndex:(NSInteger)index;
- (D3InputKey *)singleRepeatActionAtIndex:(NSInteger)index;
- (NSUInteger)singleRepeatDelayAtIndex:(NSInteger)index;

- (void)sanitize;

- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end
