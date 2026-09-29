//
//  D3KeyConfigService.h
//  d3key
//
//  Created by sunghyuk-imac on 2016. 3. 7..
//  Updated for Diablo Helper Evolution.
//

#import <Foundation/Foundation.h>
#import "D3KeyConfig.h"

@interface D3KeyConfigService : NSObject

@property (assign) BOOL active;

+ (D3KeyConfigService *)sharedService;

- (CGKeyCode)keyCodeWithString:(NSString *)string;
- (NSString *)stringWithKeycode:(CGKeyCode)keyCode;

- (D3KeyConfig *)loadConfig:(NSString *)configId;
- (void)saveConfig:(D3KeyConfig *)config withConfigId:(NSString *)configId;

// 파일 단위 저장 및 불러오기 (.json / .dhp)
- (BOOL)exportConfig:(D3KeyConfig *)config toURL:(NSURL *)fileURL error:(NSError **)error;
- (D3KeyConfig *)importConfigFromURL:(NSURL *)fileURL error:(NSError **)error;

@end
