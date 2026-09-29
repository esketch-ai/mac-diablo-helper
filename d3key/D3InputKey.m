//
//  D3InputKey.m
//  d3key
//
//  Created for Diablo Helper Evolution.
//

#import "D3InputKey.h"
#import "D3KeyConfigService.h"

@implementation D3InputKey

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _type = D3InputTypeNone;
        _keyCode = 0xFE;
        _mouseButton = (CGMouseButton)-1;
        _wheelDirection = D3WheelDirectionNone;
    }
    return self;
}

+ (instancetype)emptyKey {
    return [[self alloc] init];
}

+ (instancetype)keyWithKeyCode:(CGKeyCode)keyCode {
    D3InputKey *key = [[self alloc] init];
    key.type = D3InputTypeKeyboard;
    key.keyCode = keyCode;
    return key;
}

+ (instancetype)keyWithMouseButton:(CGMouseButton)button {
    D3InputKey *key = [[self alloc] init];
    key.type = D3InputTypeMouseButton;
    key.mouseButton = button;
    return key;
}

+ (instancetype)keyWithWheelDirection:(D3WheelDirection)direction {
    D3InputKey *key = [[self alloc] init];
    key.type = D3InputTypeMouseWheel;
    key.wheelDirection = direction;
    return key;
}

+ (instancetype)keyWithString:(NSString *)string {
    if (!string || string.length == 0 || [string isEqualToString:@"Unknown"]) {
        return [self emptyKey];
    }
    
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmed isEqualToString:@"Mouse Middle"] || [trimmed isEqualToString:@"마우스 휠 클릭"]) {
        return [self keyWithMouseButton:kCGMouseButtonCenter];
    } else if ([trimmed isEqualToString:@"Mouse Left"] || [trimmed isEqualToString:@"마우스 좌클릭"]) {
        return [self keyWithMouseButton:kCGMouseButtonLeft];
    } else if ([trimmed isEqualToString:@"Mouse Right"] || [trimmed isEqualToString:@"마우스 우클릭"]) {
        return [self keyWithMouseButton:kCGMouseButtonRight];
    } else if ([trimmed isEqualToString:@"XButton1"] || [trimmed isEqualToString:@"Mouse Button 4"]) {
        return [self keyWithMouseButton:(CGMouseButton)3];
    } else if ([trimmed isEqualToString:@"XButton2"] || [trimmed isEqualToString:@"Mouse Button 5"]) {
        return [self keyWithMouseButton:(CGMouseButton)4];
    } else if ([trimmed isEqualToString:@"Wheel Up"] || [trimmed isEqualToString:@"휠 올리기"]) {
        return [self keyWithWheelDirection:D3WheelDirectionUp];
    } else if ([trimmed isEqualToString:@"Wheel Down"] || [trimmed isEqualToString:@"휠 내리기"]) {
        return [self keyWithWheelDirection:D3WheelDirectionDown];
    }
    
    // Keyboard key
    CGKeyCode code = [[D3KeyConfigService sharedService] keyCodeWithString:trimmed];
    if (code != 0xFE) {
        return [self keyWithKeyCode:code];
    }
    
    return [self emptyKey];
}

- (BOOL)isEmpty {
    if (_type == D3InputTypeNone) return YES;
    if (_type == D3InputTypeKeyboard && _keyCode == 0xFE) return YES;
    if (_type == D3InputTypeMouseButton && _mouseButton == (CGMouseButton)-1) return YES;
    if (_type == D3InputTypeMouseWheel && _wheelDirection == D3WheelDirectionNone) return YES;
    return NO;
}

- (NSString *)displayString {
    switch (_type) {
        case D3InputTypeMouseButton:
            if (_mouseButton == kCGMouseButtonLeft) return @"Mouse Left";
            if (_mouseButton == kCGMouseButtonRight) return @"Mouse Right";
            if (_mouseButton == kCGMouseButtonCenter) return @"Mouse Middle";
            if (_mouseButton == 3) return @"XButton1";
            if (_mouseButton == 4) return @"XButton2";
            return [NSString stringWithFormat:@"Mouse %d", (int)_mouseButton + 1];
            
        case D3InputTypeMouseWheel:
            if (_wheelDirection == D3WheelDirectionUp) return @"Wheel Up";
            if (_wheelDirection == D3WheelDirectionDown) return @"Wheel Down";
            return @"Wheel";
            
        case D3InputTypeKeyboard:
            return [[D3KeyConfigService sharedService] stringWithKeycode:_keyCode];
            
        case D3InputTypeNone:
        default:
            return @"";
    }
}

- (BOOL)isEqualToInputKey:(D3InputKey *)other {
    if (!other) return NO;
    if (self.type != other.type) return NO;
    if (self.type == D3InputTypeKeyboard) {
        return self.keyCode == other.keyCode;
    } else if (self.type == D3InputTypeMouseButton) {
        return self.mouseButton == other.mouseButton;
    } else if (self.type == D3InputTypeMouseWheel) {
        return self.wheelDirection == other.wheelDirection;
    }
    return YES;
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[D3InputKey class]]) return NO;
    return [self isEqualToInputKey:(D3InputKey *)object];
}

- (NSUInteger)hash {
    return (NSUInteger)_type ^ (NSUInteger)_keyCode ^ (NSUInteger)_mouseButton ^ (NSUInteger)_wheelDirection;
}

- (id)copyWithZone:(NSZone *)zone {
    D3InputKey *copy = [[[self class] allocWithZone:zone] init];
    copy.type = self.type;
    copy.keyCode = self.keyCode;
    copy.mouseButton = self.mouseButton;
    copy.wheelDirection = self.wheelDirection;
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:_type forKey:@"type"];
    [coder encodeInteger:_keyCode forKey:@"keyCode"];
    [coder encodeInteger:_mouseButton forKey:@"mouseButton"];
    [coder encodeInteger:_wheelDirection forKey:@"wheelDirection"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _type = [coder decodeIntegerForKey:@"type"];
        _keyCode = (CGKeyCode)[coder decodeIntegerForKey:@"keyCode"];
        _mouseButton = (CGMouseButton)[coder decodeIntegerForKey:@"mouseButton"];
        _wheelDirection = (D3WheelDirection)[coder decodeIntegerForKey:@"wheelDirection"];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"type": @(_type),
        @"keyCode": @(_keyCode),
        @"mouseButton": @(_mouseButton),
        @"wheelDirection": @(_wheelDirection),
        @"display": [self displayString]
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (!dict) return [self emptyKey];
    D3InputKey *key = [[self alloc] init];
    key.type = [dict[@"type"] integerValue];
    key.keyCode = (CGKeyCode)[dict[@"keyCode"] unsignedShortValue];
    key.mouseButton = (CGMouseButton)[dict[@"mouseButton"] integerValue];
    key.wheelDirection = (D3WheelDirection)[dict[@"wheelDirection"] integerValue];
    return key;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<D3InputKey: %@>", [self displayString]];
}

@end
