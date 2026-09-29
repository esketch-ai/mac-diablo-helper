//
//  D3OpenerStep.m
//  d3key
//
//  Created for Diablo 4 Opener & Ramp-up Sequence.
//

#import "D3OpenerStep.h"

@implementation D3OpenerStep

+ (BOOL)supportsSecureCoding {
    return YES;
}

+ (instancetype)stepWithKey:(D3InputKey *)key delayMs:(NSUInteger)delayMs repeatCount:(NSUInteger)repeatCount description:(NSString *)desc {
    D3OpenerStep *step = [[self alloc] init];
    step.inputKey = key ?: [D3InputKey emptyKey];
    step.delayMs = delayMs > 0 ? delayMs : 100;
    step.repeatCount = repeatCount > 0 ? repeatCount : 1;
    step.stepDescription = desc ?: @"";
    return step;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _inputKey = [D3InputKey emptyKey];
        _delayMs = 150;
        _repeatCount = 1;
        _stepDescription = @"";
    }
    return self;
}

- (BOOL)isEmpty {
    return (_inputKey == nil || [_inputKey isEmpty]);
}

- (id)copyWithZone:(NSZone *)zone {
    D3OpenerStep *copy = [[[self class] allocWithZone:zone] init];
    copy.inputKey = [self.inputKey copyWithZone:zone];
    copy.delayMs = self.delayMs;
    copy.repeatCount = self.repeatCount;
    copy.stepDescription = [self.stepDescription copyWithZone:zone];
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_inputKey forKey:@"inputKey"];
    [coder encodeInteger:_delayMs forKey:@"delayMs"];
    [coder encodeInteger:_repeatCount forKey:@"repeatCount"];
    [coder encodeObject:_stepDescription forKey:@"stepDescription"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _inputKey = [coder decodeObjectOfClass:[D3InputKey class] forKey:@"inputKey"] ?: [D3InputKey emptyKey];
        _delayMs = [coder decodeIntegerForKey:@"delayMs"];
        if (_delayMs == 0) _delayMs = 150;
        _repeatCount = [coder decodeIntegerForKey:@"repeatCount"];
        if (_repeatCount == 0) _repeatCount = 1;
        _stepDescription = [coder decodeObjectOfClass:[NSString class] forKey:@"stepDescription"] ?: @"";
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"inputKey": [_inputKey toDictionary] ?: @{},
        @"delayMs": @(_delayMs),
        @"repeatCount": @(_repeatCount),
        @"stepDescription": _stepDescription ?: @""
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) {
        return [[self alloc] init];
    }
    D3OpenerStep *step = [[self alloc] init];
    NSDictionary *keyDict = dict[@"inputKey"];
    if (keyDict && [keyDict isKindOfClass:[NSDictionary class]]) {
        step.inputKey = [D3InputKey fromDictionary:keyDict];
    } else {
        step.inputKey = [D3InputKey emptyKey];
    }
    
    id delayVal = dict[@"delayMs"];
    step.delayMs = delayVal ? [delayVal unsignedIntegerValue] : 150;
    if (step.delayMs == 0) step.delayMs = 150;
    
    id repVal = dict[@"repeatCount"];
    step.repeatCount = repVal ? [repVal unsignedIntegerValue] : 1;
    if (step.repeatCount == 0) step.repeatCount = 1;
    
    step.stepDescription = dict[@"stepDescription"] ?: @"";
    return step;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[D3OpenerStep class]]) return NO;
    D3OpenerStep *other = (D3OpenerStep *)object;
    return [self.inputKey isEqualToInputKey:other.inputKey] &&
           self.delayMs == other.delayMs &&
           self.repeatCount == other.repeatCount;
}

@end
