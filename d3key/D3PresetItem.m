//
//  D3PresetItem.m
//  DM_Helper
//
//  Created by sunghyuk on 2026. 9. 29.
//  Copyright © 2026 sunghyuk. All rights reserved.
//

#import "D3PresetItem.h"

@implementation D3PresetItem

+ (instancetype)presetWithAuthor:(NSString *)author
                          season:(NSString *)season
                  characterClass:(NSString *)charClass
                       buildName:(NSString *)buildName
                     description:(NSString *)desc
                          config:(D3KeyConfig *)config {
    D3PresetItem *item = [[D3PresetItem alloc] init];
    item.presetId = [[NSUUID UUID] UUIDString];
    item.author = author.length > 0 ? author : @"익명 유저";
    item.season = season.length > 0 ? season : @"시즌 6 (증오의 그릇)";
    item.characterClass = charClass.length > 0 ? charClass : @"공통";
    item.buildName = buildName.length > 0 ? buildName : @"새 프리셋";
    item.presetDescription = desc.length > 0 ? desc : @"";
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm";
    item.createdAt = [formatter stringFromDate:[NSDate date]];
    
    if (config) {
        NSDictionary *dict = [config toDictionary];
        NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
        if (data) {
            item.configJson = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
    }
    if (!item.configJson) {
        item.configJson = @"{}";
    }
    return item;
}

- (NSDictionary *)toDictionary {
    return @{
        @"presetId": self.presetId ?: @"",
        @"author": self.author ?: @"",
        @"season": self.season ?: @"",
        @"characterClass": self.characterClass ?: @"",
        @"buildName": self.buildName ?: @"",
        @"presetDescription": self.presetDescription ?: @"",
        @"createdAt": self.createdAt ?: @"",
        @"configJson": self.configJson ?: @"{}"
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    D3PresetItem *item = [[D3PresetItem alloc] init];
    item.presetId = dict[@"presetId"] ?: [[NSUUID UUID] UUIDString];
    item.author = dict[@"author"] ?: @"익명";
    item.season = dict[@"season"] ?: @"시즌 6";
    item.characterClass = dict[@"characterClass"] ?: @"공통";
    item.buildName = dict[@"buildName"] ?: @"프리셋";
    item.presetDescription = dict[@"presetDescription"] ?: @"";
    item.createdAt = dict[@"createdAt"] ?: @"";
    item.configJson = dict[@"configJson"] ?: @"{}";
    return item;
}

+ (NSString *)extractCellValue:(id)cell {
    if (!cell || [cell isKindOfClass:[NSNull class]]) return @"";
    if ([cell isKindOfClass:[NSString class]]) return (NSString *)cell;
    if ([cell isKindOfClass:[NSNumber class]]) return [(NSNumber *)cell stringValue];
    if ([cell isKindOfClass:[NSDictionary class]]) {
        NSDictionary *cellDict = (NSDictionary *)cell;
        id val = cellDict[@"f"] ?: cellDict[@"v"];
        if (val && ![val isKindOfClass:[NSNull class]]) {
            return [NSString stringWithFormat:@"%@", val];
        }
    }
    return [NSString stringWithFormat:@"%@", cell];
}

+ (instancetype)fromGoogleSheetRow:(NSArray *)row {
    if (!row || ![row isKindOfClass:[NSArray class]] || row.count < 5) return nil;
    
    // 시트 컬럼 규격:
    // 0: 일시, 1: 작성자, 2: 시즌, 3: 직업, 4: 빌드명, 5: 설명, 6: 설정JSON
    D3PresetItem *item = [[D3PresetItem alloc] init];
    item.presetId = [[NSUUID UUID] UUIDString];
    item.createdAt = [self extractCellValue:row[0]];
    item.author = [self extractCellValue:row[1]];
    item.season = [self extractCellValue:row[2]];
    item.characterClass = [self extractCellValue:row[3]];
    item.buildName = [self extractCellValue:row[4]];
    
    if (row.count > 5) {
        item.presetDescription = [self extractCellValue:row[5]];
    } else {
        item.presetDescription = @"";
    }
    
    if (row.count > 6) {
        item.configJson = [self extractCellValue:row[6]];
    } else {
        item.configJson = @"{}";
    }
    
    // 헤더 행 필터링 ("작성자" or "시즌" or "Author" 등이면 건너뜀)
    if ([item.author isEqualToString:@"작성자"] || [item.author isEqualToString:@"Author"] ||
        [item.season isEqualToString:@"시즌"] || [item.season isEqualToString:@"Season"]) {
        return nil;
    }
    
    return item;
}

- (NSArray<NSString *> *)toGoogleSheetRow {
    return @[
        self.createdAt ?: @"",
        self.author ?: @"",
        self.season ?: @"",
        self.characterClass ?: @"",
        self.buildName ?: @"",
        self.presetDescription ?: @"",
        self.configJson ?: @"{}"
    ];
}

- (NSString *)toGoogleSheetTSV {
    // 탭 및 개행 문자 치환 (시트 깨짐 방지)
    NSString *cleanDesc = [self.presetDescription stringByReplacingOccurrencesOfString:@"\t" withString:@" "];
    cleanDesc = [cleanDesc stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    cleanDesc = [cleanDesc stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    
    NSString *cleanJson = [self.configJson stringByReplacingOccurrencesOfString:@"\t" withString:@" "];
    cleanJson = [cleanJson stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    cleanJson = [cleanJson stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    
    return [NSString stringWithFormat:@"%@\t%@\t%@\t%@\t%@\t%@\t%@\n",
            self.createdAt ?: @"",
            self.author ?: @"",
            self.season ?: @"",
            self.characterClass ?: @"",
            self.buildName ?: @"",
            cleanDesc ?: @"",
            cleanJson ?: @"{}"];
}

- (D3KeyConfig *)createKeyConfig {
    if (!self.configJson || self.configJson.length == 0) {
        return [D3KeyConfig defaultKeyConfig];
    }
    NSData *data = [self.configJson dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return [D3KeyConfig defaultKeyConfig];
    
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (dict && [dict isKindOfClass:[NSDictionary class]]) {
        D3KeyConfig *config = [D3KeyConfig fromDictionary:dict];
        if (config.memo.length == 0 && self.buildName.length > 0) {
            config.memo = [NSString stringWithFormat:@"[%@] %@", self.characterClass, self.buildName];
        }
        return config;
    }
    return [D3KeyConfig defaultKeyConfig];
}

- (NSString *)summaryText {
    D3KeyConfig *config = [self createKeyConfig];
    NSMutableArray *parts = [NSMutableArray array];
    
    // 1. 오프너 정보
    if (config.openerEnabled && config.openerSteps.count > 0) {
        NSMutableArray *stepDescs = [NSMutableArray array];
        for (int i = 0; i < config.openerSteps.count; i++) {
            D3OpenerStep *s = config.openerSteps[i];
            if (![s.inputKey isEmpty]) {
                [stepDescs addObject:[NSString stringWithFormat:@"%d단계:[%@ %lums]", i + 1, s.inputKey.description, (unsigned long)s.delayMs]];
            }
        }
        if (stepDescs.count > 0) {
            [parts addObject:[NSString stringWithFormat:@"⚡️ 준비 시퀀스(%lu단계): %@", (unsigned long)stepDescs.count, [stepDescs componentsJoinedByString:@" → "]]];
        }
    }
    
    // 2. 주요 스킬
    NSMutableArray *skillDescs = [NSMutableArray array];
    for (int i = 1; i <= 8; i++) {
        D3InputKey *key = [config skillInputKeyAtIndex:i];
        if (![key isEmpty] && [config skillCheckAtIndex:i]) {
            NSString *mode = [config skillHoldAtIndex:i] ? @"(홀드)" : @"";
            [skillDescs addObject:[NSString stringWithFormat:@"%@[%lums%@]", key.description, (unsigned long)[config skillDelayAtIndex:i], mode]];
        }
    }
    if (skillDescs.count > 0) {
        [parts addObject:[NSString stringWithFormat:@"🎮 메인 스킬: %@", [skillDescs componentsJoinedByString:@", "]]];
    }
    
    // 3. 콤보 정보
    if (config.comboEnabled && ![config.comboGeneratorKey isEmpty] && ![config.comboSpenderKey isEmpty]) {
        [parts addObject:[NSString stringWithFormat:@"🔄 콤보 사이클: [%@ %lu회] ↔ [%@ %lu회] (%lums 주기)",
                          config.comboGeneratorKey.description, (unsigned long)config.comboGeneratorCount,
                          config.comboSpenderKey.description, (unsigned long)config.comboSpenderCount,
                          (unsigned long)config.comboInterval]];
    }
    
    // 4. 단일반복
    NSMutableArray *repeatDescs = [NSMutableArray array];
    for (int i = 1; i <= 3; i++) {
        D3InputKey *toggle = [config singleRepeatToggleAtIndex:i];
        D3InputKey *act = [config singleRepeatActionAtIndex:i];
        if (![toggle isEmpty] && ![act isEmpty]) {
            [repeatDescs addObject:[NSString stringWithFormat:@"%@ 누름 ➔ %@(%lums)", toggle.description, act.description, (unsigned long)[config singleRepeatDelayAtIndex:i]]];
        }
    }
    if (repeatDescs.count > 0) {
        [parts addObject:[NSString stringWithFormat:@"💎 단일 반복: %@", [repeatDescs componentsJoinedByString:@" | "]]];
    }
    
    return [parts componentsJoinedByString:@"\n"];
}

@end
