//
//  D3GoogleSheetService.m
//  DM_Helper
//
//  Created by sunghyuk on 2026. 9. 29.
//  Copyright © 2026 sunghyuk. All rights reserved.
//

#import "D3GoogleSheetService.h"
#import <AppKit/AppKit.h>

NSString *const kD3GoogleSheetPresetsChangedNotification = @"kD3GoogleSheetPresetsChangedNotification";
static NSString *const kDefaultSheetUrl = @"https://docs.google.com/spreadsheets/d/1X5u2U3sR8t8_DMHelper_DiabloCommunity_Presets/edit";
static NSString *const kUserPrefSheetUrlKey = @"D3GoogleSheet_SheetUrl";
static NSString *const kUserPrefWebAppUrlKey = @"D3GoogleSheet_WebAppUrl";
static NSString *const kUserPrefLastAuthorKey = @"D3GoogleSheet_LastAuthor";
static NSString *const kUserPrefCachedPresetsKey = @"D3GoogleSheet_CachedPresets_v15";

@interface D3GoogleSheetService ()
@property (nonatomic, strong) NSMutableArray<D3PresetItem *> *mutablePresets;
@end

@implementation D3GoogleSheetService

+ (instancetype)sharedService {
    static D3GoogleSheetService *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[D3GoogleSheetService alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutablePresets = [NSMutableArray array];
        [self loadPreferencesAndCache];
        if (_mutablePresets.count == 0) {
            [self populateSeedPresets];
        }
    }
    return self;
}

- (NSArray<D3PresetItem *> *)cachedPresets {
    @synchronized (self) {
        return [_mutablePresets copy];
    }
}

- (void)loadPreferencesAndCache {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    _sheetUrl = [defs stringForKey:kUserPrefSheetUrlKey] ?: kDefaultSheetUrl;
    _webAppUrl = [defs stringForKey:kUserPrefWebAppUrlKey] ?: @"";
    _lastAuthor = [defs stringForKey:kUserPrefLastAuthorKey] ?: @"성역의용사";
    
    NSArray *saved = [defs arrayForKey:kUserPrefCachedPresetsKey];
    if (saved && [saved isKindOfClass:[NSArray class]]) {
        for (NSDictionary *d in saved) {
            D3PresetItem *item = [D3PresetItem fromDictionary:d];
            if (item) {
                [_mutablePresets addObject:item];
            }
        }
    }
}

- (void)savePreferencesAndCache {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setObject:_sheetUrl forKey:kUserPrefSheetUrlKey];
    [defs setObject:_webAppUrl forKey:kUserPrefWebAppUrlKey];
    [defs setObject:_lastAuthor forKey:kUserPrefLastAuthorKey];
    
    NSMutableArray *arr = [NSMutableArray array];
    @synchronized (self) {
        for (D3PresetItem *item in _mutablePresets) {
            [arr addObject:[item toDictionary]];
        }
    }
    [defs setObject:arr forKey:kUserPrefCachedPresetsKey];
    [defs synchronize];
}

- (void)setSheetUrl:(NSString *)sheetUrl {
    _sheetUrl = [sheetUrl copy];
    [self savePreferencesAndCache];
}

- (void)setWebAppUrl:(NSString *)webAppUrl {
    _webAppUrl = [webAppUrl copy];
    [self savePreferencesAndCache];
}

- (void)setLastAuthor:(NSString *)lastAuthor {
    _lastAuthor = [lastAuthor copy];
    [self savePreferencesAndCache];
}

#pragma mark Seed Presets

- (void)populateSeedPresets {
    NSArray *seeds = @[
        @{
            @"author": @"성역의네팔렘",
            @"season": @"시즌 6 (증오의 그릇)",
            @"class": @"악마술사",
            @"build": @"🔥 타오르는 비명 오토봄버 (나락150단)",
            @"desc": @"소환수 활성화 ➔ 탈태 지배력 버프 ➔ 감옥 CC ➔ 타오르는 비명(우클릭 120ms) 무한 폭격 빌드",
            @"presetName": @"악마술사 (타오르는 비명)"
        },
        @{
            @"author": @"원소의지배자",
            @"season": @"시즌 6 (증오의 그릇)",
            @"class": @"원소술사",
            @"build": @"🔮 번개창 & 탈라샤 4원소 폭풍",
            @"desc": @"얼음갑옷 + 순간이동 + 번개창 + 평타 3회로 4원소 탈라샤 스택 적재 후 본 공격 순환",
            @"presetName": @"원소술사 (번개창/탈라샤)"
        },
        @{
            @"author": @"휠윈드장인",
            @"season": @"시즌 6 (증오의 그릇)",
            @"class": @"야만용사",
            @"build": @"⚔️ 무한 소용돌이 3함성 채널링",
            @"desc": @"집결/도전/전장 3함성 순차 시전 ➔ 우클릭(소용돌이) [홀드(누름)] 모드로 무한 지속 회전",
            @"presetName": @"야만용사 (소용돌이)"
        },
        @{
            @"author": @"어둠의암살자",
            @"season": @"시즌 6 (증오의 그릇)",
            @"class": @"도적",
            @"build": @"🏹 3:1 연계 콤보 회전칼날",
            @"desc": @"암흑주입 진입 ➔ 구멍뚫기(생성기) 3회 ↔ 회전칼날(소모기) 1회 칼교대 자동 사이클",
            @"presetName": @"도적 (3콤보 포인트)"
        },
        @{
            @"author": @"시체조종사",
            @"season": @"시즌 6 (증오의 그릇)",
            @"class": @"강령술사",
            @"build": @"💀 시폭 & 뼈창 초고속 연타 폭딜",
            @"desc": @"골렘 진입 + 노화 저주 살포 + 시체 촉수 CC ➔ 뼈창(200ms)과 시체폭발(120ms) 고속 연타",
            @"presetName": @"강령술사 (시폭/뼈창)"
        },
        @{
            @"author": @"영혼수호자",
            @"season": @"시즌 6 (증오의 그릇)",
            @"class": @"혼령사",
            @"build": @"🦅 결의 스택 제압 강타 사이클",
            @"desc": @"태세 버프 유지 ➔ 깃털 투척 3회 ↔ 제압기 1회 (140ms 주기) 자동 연계 교대",
            @"presetName": @"혼령사 (태세/제압)"
        },
        @{
            @"author": @"불지옥술사",
            @"season": @"영원",
            @"class": @"악마술사",
            @"build": @"🌋 종말의 불길 원버튼 집중포화",
            @"desc": @"인장 설치 후 불길 집중 폭격과 감옥으로 몬스터 흡인 및 원거리 섬멸",
            @"presetName": @"악마술사 (타오르는 비명)"
        },
        @{
            @"author": @"클래식순례자",
            @"season": @"디아블로 3",
            @"class": @"디아3 전직업",
            @"build": @"⚡️ 정통 매크로 & 50ms 줍기/겜블",
            @"desc": @"Grave(`~`) 50ms 좌클릭 폭풍 줍기 + Tab 우클릭 핏빛파편 겜블 완벽 세팅",
            @"presetName": @""
        }
    ];
    
    for (NSDictionary *s in seeds) {
        D3KeyConfig *config = nil;
        NSString *pName = s[@"presetName"];
        if (pName.length > 0) {
            config = [D3KeyConfig presetWithName:pName];
        } else {
            config = [D3KeyConfig defaultKeyConfig];
        }
        
        D3PresetItem *item = [D3PresetItem presetWithAuthor:s[@"author"]
                                                     season:s[@"season"]
                                             characterClass:s[@"class"]
                                                  buildName:s[@"build"]
                                                description:s[@"desc"]
                                                     config:config];
        [_mutablePresets addObject:item];
    }
    [self savePreferencesAndCache];
}

#pragma mark Google Sheet URL Parsing

- (NSString *)extractSpreadsheetIdFromUrl:(NSString *)url {
    if (!url || url.length == 0) return nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"/d/([a-zA-Z0-9-_]+)"
                                                                           options:0
                                                                             error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:url options:0 range:NSMakeRange(0, url.length)];
    if (match && match.numberOfRanges > 1) {
        return [url substringWithRange:[match rangeAtIndex:1]];
    }
    return nil;
}

- (NSURL *)gvizUrlFromSheetUrl:(NSString *)url {
    NSString *sheetId = [self extractSpreadsheetIdFromUrl:url];
    if (sheetId && sheetId.length > 0) {
        NSString *str = [NSString stringWithFormat:@"https://docs.google.com/spreadsheets/d/%@/gviz/tq?tqx=out:json", sheetId];
        return [NSURL URLWithString:str];
    }
    return [NSURL URLWithString:url];
}

#pragma mark Fetch Presets

- (void)fetchPresetsWithCompletion:(void(^)(NSArray<D3PresetItem *> *presets, NSError *error))completion {
    // 1. Web App URL이 지정되어 있으면 우선 호출
    if (self.webAppUrl.length > 0) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?action=list", self.webAppUrl]];
        if (url) {
            NSURLRequest *req = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:8.0];
            [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (!error && data) {
                    NSArray *parsed = [self parseJsonArrayResponse:data];
                    if (parsed.count > 0) {
                        [self mergeRemotePresets:parsed];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (completion) completion(self.cachedPresets, nil);
                        });
                        return;
                    }
                }
                // fallback to GViz
                [self fetchFromGVizWithCompletion:completion];
            }] resume];
            return;
        }
    }
    
    // 2. Google Sheets GViz 엔드포인트 호출
    [self fetchFromGVizWithCompletion:completion];
}

- (void)fetchFromGVizWithCompletion:(void(^)(NSArray<D3PresetItem *> *presets, NSError *error))completion {
    NSURL *gvizUrl = [self gvizUrlFromSheetUrl:self.sheetUrl];
    if (!gvizUrl) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(self.cachedPresets, nil);
        });
        return;
    }
    
    NSURLRequest *req = [NSURLRequest requestWithURL:gvizUrl cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:10.0];
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(self.cachedPresets, error);
            });
            return;
        }
        
        NSString *raw = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!raw) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(self.cachedPresets, nil);
            });
            return;
        }
        
        NSArray *parsed = [self parseGVizResponseString:raw];
        if (parsed.count > 0) {
            [self mergeRemotePresets:parsed];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(self.cachedPresets, nil);
        });
    }] resume];
}

- (NSArray<D3PresetItem *> *)parseGVizResponseString:(NSString *)raw {
    NSMutableArray *items = [NSMutableArray array];
    
    // GViz 형태: google.visualization.Query.setResponse({...});
    NSRange startRange = [raw rangeOfString:@"{"];
    NSRange endRange = [raw rangeOfString:@"}" options:NSBackwardsSearch];
    if (startRange.location == NSNotFound || endRange.location == NSNotFound || endRange.location <= startRange.location) {
        return items;
    }
    
    NSString *jsonStr = [raw substringWithRange:NSMakeRange(startRange.location, endRange.location - startRange.location + 1)];
    NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) return items;
    
    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    if (!root || ![root isKindOfClass:[NSDictionary class]]) return items;
    
    NSDictionary *table = root[@"table"];
    if (!table || ![table isKindOfClass:[NSDictionary class]]) return items;
    
    NSArray *rows = table[@"rows"];
    if (!rows || ![rows isKindOfClass:[NSArray class]]) return items;
    
    for (NSDictionary *rowDict in rows) {
        NSArray *c = rowDict[@"c"];
        if (c && [c isKindOfClass:[NSArray class]]) {
            D3PresetItem *item = [D3PresetItem fromGoogleSheetRow:c];
            if (item && item.buildName.length > 0) {
                [items addObject:item];
            }
        }
    }
    return items;
}

- (NSArray<D3PresetItem *> *)parseJsonArrayResponse:(NSData *)data {
    NSMutableArray *items = [NSMutableArray array];
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if ([obj isKindOfClass:[NSArray class]]) {
        for (NSDictionary *dict in (NSArray *)obj) {
            D3PresetItem *item = [D3PresetItem fromDictionary:dict];
            if (item) [items addObject:item];
        }
    } else if ([obj isKindOfClass:[NSDictionary class]] && [obj[@"presets"] isKindOfClass:[NSArray class]]) {
        for (NSDictionary *dict in (NSArray *)obj[@"presets"]) {
            D3PresetItem *item = [D3PresetItem fromDictionary:dict];
            if (item) [items addObject:item];
        }
    }
    return items;
}

- (void)mergeRemotePresets:(NSArray<D3PresetItem *> *)remotes {
    @synchronized (self) {
        NSMutableSet *existingBuilds = [NSMutableSet set];
        for (D3PresetItem *item in _mutablePresets) {
            [existingBuilds addObject:[NSString stringWithFormat:@"%@_%@_%@", item.author, item.season, item.buildName]];
        }
        for (D3PresetItem *remote in remotes) {
            NSString *key = [NSString stringWithFormat:@"%@_%@_%@", remote.author, remote.season, remote.buildName];
            if (![existingBuilds containsObject:key]) {
                [_mutablePresets insertObject:remote atIndex:0];
                [existingBuilds addObject:key];
            }
        }
    }
    [self savePreferencesAndCache];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kD3GoogleSheetPresetsChangedNotification object:nil];
    });
}

#pragma mark Publish Preset

- (void)publishPreset:(D3PresetItem *)preset
           completion:(void(^)(BOOL success, NSString *message))completion {
    if (!preset) {
        if (completion) completion(NO, @"프리셋 데이터가 비어 있습니다.");
        return;
    }
    
    // 1. 로컬 캐시에 즉시 반영 및 저장
    @synchronized (self) {
        [_mutablePresets insertObject:preset atIndex:0];
    }
    [self savePreferencesAndCache];
    
    // 2. 클립보드에 TSV 행 복사 (구글시트 직접 붙여넣기용)
    [self copyPresetRowToClipboard:preset];
    
    // 3. Web App URL이 설정되어 있다면 HTTP POST 전송
    if (self.webAppUrl.length > 0) {
        NSURL *url = [NSURL URLWithString:self.webAppUrl];
        if (url) {
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
            req.HTTPMethod = @"POST";
            [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
            
            NSDictionary *payload = [preset toDictionary];
            NSData *postData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
            req.HTTPBody = postData;
            
            [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!error) {
                        if (completion) completion(YES, @"구글 시트 클라우드에 성공적으로 등록되었습니다!\n클립보드에도 시트용 데이터가 복사되었습니다.");
                    } else {
                        if (completion) completion(YES, @"로컬 및 클립보드에 저장되었습니다.\n(웹앱 전송 오류: 시트에 Cmd+V로 직접 붙여넣으실 수 있습니다.)");
                    }
                    [[NSNotificationCenter defaultCenter] postNotificationName:kD3GoogleSheetPresetsChangedNotification object:nil];
                });
            }] resume];
            return;
        }
    }
    
    // Web App URL 미설정 시: 클립보드 복사 완료 안내
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kD3GoogleSheetPresetsChangedNotification object:nil];
        if (completion) {
            completion(YES, @"프리셋이 성공적으로 등록되었습니다!\n\n📋 구글 시트용 행 데이터가 클립보드에 복사되었습니다.\n열리는 구글 시트에서 빈 행을 클릭하고 [Cmd + V]를 누르면 시트에 반영됩니다.");
        }
    });
}

- (NSString *)copyPresetRowToClipboard:(D3PresetItem *)preset {
    if (!preset) return @"";
    NSString *tsv = [preset toGoogleSheetTSV];
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:tsv forType:NSPasteboardTypeString];
    return tsv;
}

- (void)openSheetInBrowser {
    if (self.sheetUrl.length > 0) {
        NSURL *url = [NSURL URLWithString:self.sheetUrl];
        if (url) {
            [[NSWorkspace sharedWorkspace] openURL:url];
        }
    }
}

#pragma mark Filtering

- (NSArray<D3PresetItem *> *)filterPresetsWithSeason:(NSString *)season
                                      characterClass:(NSString *)charClass
                                             keyword:(NSString *)keyword {
    NSArray<D3PresetItem *> *all = self.cachedPresets;
    NSMutableArray<D3PresetItem *> *filtered = [NSMutableArray array];
    
    BOOL seasonAny = (!season || season.length == 0 || [season isEqualToString:@"전체"] || [season isEqualToString:@"시즌: 전체"]);
    BOOL classAny = (!charClass || charClass.length == 0 || [charClass isEqualToString:@"전체"] || [charClass isEqualToString:@"직업: 전체"]);
    NSString *lowKey = [keyword lowercaseString];
    
    for (D3PresetItem *item in all) {
        if (!seasonAny) {
            if ([season isEqualToString:@"시즌 6"] && ![item.season containsString:@"시즌 6"]) continue;
            else if ([season isEqualToString:@"시즌 7"] && ![item.season containsString:@"시즌 7"]) continue;
            else if ([season isEqualToString:@"시즌 8"] && ![item.season containsString:@"시즌 8"]) continue;
            else if ([season isEqualToString:@"영원"] && ![item.season containsString:@"영원"]) continue;
            else if ([season isEqualToString:@"디아블로 3"] && ![item.season containsString:@"디아블로 3"] && ![item.season containsString:@"디아3"]) continue;
            else if (![item.season containsString:season]) continue;
        }
        
        if (!classAny) {
            if (![item.characterClass containsString:charClass]) continue;
        }
        
        if (lowKey.length > 0) {
            NSString *authorLow = [item.author lowercaseString];
            NSString *buildLow = [item.buildName lowercaseString];
            NSString *descLow = [item.presetDescription lowercaseString];
            if (![authorLow containsString:lowKey] && ![buildLow containsString:lowKey] && ![descLow containsString:lowKey]) {
                continue;
            }
        }
        
        [filtered addObject:item];
    }
    return filtered;
}

#pragma mark Google Apps Script Template

- (NSString *)googleAppsScriptTemplateCode {
    return
    @"// ==========================================================================\n"
    @"// DM_Helper Google Apps Script 자동 연동 템플릿\n"
    @"// 구글 시트 상단 메뉴 [확장 프로그램] > [Apps Script]에 붙여넣고 [배포]하세요.\n"
    @"// ==========================================================================\n\n"
    @"function doGet(e) {\n"
    @"  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();\n"
    @"  var rows = sheet.getDataRange().getValues();\n"
    @"  var presets = [];\n"
    @"  for (var i = 1; i < rows.length; i++) {\n"
    @"    var r = rows[i];\n"
    @"    if (!r[1] && !r[4]) continue;\n"
    @"    presets.push({\n"
    @"      createdAt: r[0] || '',\n"
    @"      author: r[1] || '',\n"
    @"      season: r[2] || '',\n"
    @"      characterClass: r[3] || '',\n"
    @"      buildName: r[4] || '',\n"
    @"      presetDescription: r[5] || '',\n"
    @"      configJson: r[6] || '{}'\n"
    @"    });\n"
    @"  }\n"
    @"  return ContentService.createTextOutput(JSON.stringify({presets: presets}))\n"
    @"                       .setMimeType(ContentService.MimeType.JSON);\n"
    @"}\n\n"
    @"function doPost(e) {\n"
    @"  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();\n"
    @"  var data = JSON.parse(e.postData.contents);\n"
    @"  sheet.appendRow([\n"
    @"    data.createdAt || new Date().toISOString().substring(0, 16).replace('T', ' '),\n"
    @"    data.author || '익명',\n"
    @"    data.season || '시즌 6',\n"
    @"    data.characterClass || '공통',\n"
    @"    data.buildName || '새 프리셋',\n"
    @"    data.presetDescription || '',\n"
    @"    data.configJson || '{}'\n"
    @"  ]);\n"
    @"  return ContentService.createTextOutput(JSON.stringify({result: 'success'}))\n"
    @"                       .setMimeType(ContentService.MimeType.JSON);\n"
    @"}\n";
}

@end
