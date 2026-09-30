//
//  D3LocalizationManager.h
//  DM_Helper
//
//  Created by sunghyuk on 2026. 9. 30.
//  Copyright © 2026 sunghyuk. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kD3LanguageChangedNotification;
extern NSString * const kD3SelectedLanguageKey;

typedef NS_ENUM(NSInteger, D3LanguageMode) {
    D3LanguageModeAuto = 0,   // System language (Default)
    D3LanguageModeKorean = 1, // 한국어
    D3LanguageModeEnglish = 2 // English
};

@interface D3LocalizationManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, assign) D3LanguageMode languageMode;
@property (nonatomic, readonly) BOOL isKorean;
@property (nonatomic, readonly) NSString *currentLanguageCode; // @"ko" or @"en"

- (NSString *)localizedStringForKey:(NSString *)key;
- (NSString *)localizedStringForKey:(NSString *)key default:(nullable NSString *)defaultVal;

// Preset translations
- (NSString *)localizedPresetName:(NSString *)presetName;

@end

// Convenience macro
#define D3Loc(key) [[D3LocalizationManager sharedManager] localizedStringForKey:(key)]
#define D3LocDef(key, def) [[D3LocalizationManager sharedManager] localizedStringForKey:(key) default:(def)]
#define D3LocFormat(key, ...) [NSString stringWithFormat:[[D3LocalizationManager sharedManager] localizedStringForKey:(key)], ##__VA_ARGS__]

NS_ASSUME_NONNULL_END
