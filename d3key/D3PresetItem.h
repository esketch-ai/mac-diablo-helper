//
//  D3PresetItem.h
//  DM_Helper
//
//  Created by sunghyuk on 2026. 9. 29.
//  Copyright © 2026 sunghyuk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "D3KeyConfig.h"

@interface D3PresetItem : NSObject

@property (nonatomic, copy) NSString *presetId;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSString *season;
@property (nonatomic, copy) NSString *characterClass;
@property (nonatomic, copy) NSString *buildName;
@property (nonatomic, copy) NSString *presetDescription;
@property (nonatomic, copy) NSString *createdAt;
@property (nonatomic, copy) NSString *configJson;

+ (instancetype)presetWithAuthor:(NSString *)author
                          season:(NSString *)season
                  characterClass:(NSString *)charClass
                       buildName:(NSString *)buildName
                     description:(NSString *)desc
                          config:(D3KeyConfig *)config;

- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

// 구글 시트 연동 지원 (CSV / TSV / GViz Row 파싱)
+ (instancetype)fromGoogleSheetRow:(NSArray *)row;
- (NSArray<NSString *> *)toGoogleSheetRow;
- (NSString *)toGoogleSheetTSV;

// D3KeyConfig 인스턴스로 변환
- (D3KeyConfig *)createKeyConfig;

// UI 표시용 요약 텍스트
- (NSString *)summaryText;

@end
