//
//  D3GoogleSheetService.h
//  DM_Helper
//
//  Created by sunghyuk on 2026. 9. 29.
//  Copyright © 2026 sunghyuk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "D3PresetItem.h"

extern NSString *const kD3GoogleSheetPresetsChangedNotification;

@interface D3GoogleSheetService : NSObject

@property (nonatomic, copy) NSString *sheetUrl;
@property (nonatomic, copy) NSString *webAppUrl;
@property (nonatomic, copy) NSString *lastAuthor;
@property (nonatomic, readonly) NSArray<D3PresetItem *> *cachedPresets;

+ (instancetype)sharedService;

// 구글 시트 프리셋 원격 동기화 (GViz / CSV / Web App)
- (void)fetchPresetsWithCompletion:(void(^)(NSArray<D3PresetItem *> *presets, NSError *error))completion;

// 신규 프리셋 등록 및 구글 시트 공유
- (void)publishPreset:(D3PresetItem *)preset
           completion:(void(^)(BOOL success, NSString *message))completion;

// 구글 시트 클립보드 복사용 TSV 생성
- (NSString *)copyPresetRowToClipboard:(D3PresetItem *)preset;

// 필터링 유틸리티
- (NSArray<D3PresetItem *> *)filterPresetsWithSeason:(NSString *)season
                                      characterClass:(NSString *)charClass
                                             keyword:(NSString *)keyword;

// 구글 시트 브라우저에서 열기
- (void)openSheetInBrowser;

// 앱스크립트 템플릿 코드 반환 (유저가 본인 시트에 적용할 때 사용)
- (NSString *)googleAppsScriptTemplateCode;

@end
