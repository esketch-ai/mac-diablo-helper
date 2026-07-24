//
//  D3KeyConfig.h
//  d3key
//
//  Created by sunghyuk-imac on 2016. 3. 2..
//  Copyright © 2016년 sunghyuk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface D3KeyConfig : NSObject <NSCoding>

@property (assign) CGKeyCode startKey;

@property CGKeyCode stopKey1;
@property CGKeyCode stopKey2;
@property CGKeyCode stopKey3;
@property CGKeyCode stopKey4;
@property CGKeyCode stopKey5;

@property CGKeyCode skillKey1;
@property CGKeyCode skillKey2;
@property CGKeyCode skillKey3;
@property CGKeyCode skillKey4;
@property CGKeyCode skillKey5;
@property CGKeyCode skillKey6;

@property CGKeyCode mouseLeftKey;
@property CGKeyCode mouseRightKey;

@property NSUInteger skillDelay1;
@property NSUInteger skillDelay2;
@property NSUInteger skillDelay3;
@property NSUInteger skillDelay4;
@property NSUInteger skillDelay5;
@property NSUInteger skillDelay6;
@property NSUInteger mouseLeftDelay;
@property NSUInteger mouseRightDelay;

+ (D3KeyConfig *) defaultKeyConfig;

- (BOOL) isStartKey:(CGKeyCode) keyCode;
- (BOOL) isStopKey:(CGKeyCode) keyCode;

@end
