//
//  D3InputKey.h
//  d3key
//
//  Created for Diablo Helper Evolution.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef NS_ENUM(NSInteger, D3InputType) {
    D3InputTypeNone = 0,
    D3InputTypeKeyboard = 1,
    D3InputTypeMouseButton = 2,
    D3InputTypeMouseWheel = 3
};

typedef NS_ENUM(NSInteger, D3WheelDirection) {
    D3WheelDirectionNone = 0,
    D3WheelDirectionUp = 1,
    D3WheelDirectionDown = -1
};

@interface D3InputKey : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, assign) D3InputType type;
@property (nonatomic, assign) CGKeyCode keyCode;
@property (nonatomic, assign) CGMouseButton mouseButton;
@property (nonatomic, assign) D3WheelDirection wheelDirection;

+ (instancetype)emptyKey;
+ (instancetype)keyWithKeyCode:(CGKeyCode)keyCode;
+ (instancetype)keyWithMouseButton:(CGMouseButton)button;
+ (instancetype)keyWithWheelDirection:(D3WheelDirection)direction;
+ (instancetype)keyWithString:(NSString *)string;

- (BOOL)isEmpty;
- (BOOL)isEqualToInputKey:(D3InputKey *)other;
- (NSString *)displayString;

- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end
