//
//  D3OpenerStep.h
//  d3key
//
//  Created for Diablo 4 Opener & Ramp-up Sequence.
//

#import <Foundation/Foundation.h>
#import "D3InputKey.h"

@interface D3OpenerStep : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, strong) D3InputKey *inputKey;
@property (nonatomic, assign) NSUInteger delayMs;
@property (nonatomic, assign) NSUInteger repeatCount;
@property (nonatomic, copy) NSString *stepDescription;

+ (instancetype)stepWithKey:(D3InputKey *)key delayMs:(NSUInteger)delayMs repeatCount:(NSUInteger)repeatCount description:(NSString *)desc;

- (BOOL)isEmpty;
- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end
