//
//  D3KeyConfig.m
//  d3key
//
//  Created by sunghyuk-imac on 2016. 3. 2..
//  Copyright © 2016년 sunghyuk. All rights reserved.
//

#import "D3KeyConfig.h"
#import <Carbon/Carbon.h>
#include "const.h"

@implementation D3KeyConfig

@synthesize memo;
@synthesize startKey;
@synthesize stopKey1, stopKey2, stopKey3, stopKey4, stopKey5;
@synthesize skillDelay1, skillDelay2, skillDelay3, skillDelay4, skillDelay5, skillDelay6, mouseRightDelay, mouseLeftDelay;
@synthesize skillKey1, skillKey2, skillKey3, skillKey4, skillKey5, skillKey6, mouseLeftKey, mouseRightKey;

#pragma mark member methods

- (BOOL) isStartKey:(CGKeyCode) keyCode {
    return (keyCode == self.startKey);
}

- (BOOL) isStopKey:(CGKeyCode)keyCode {
    return
    (keyCode == self.stopKey1 || keyCode == self.stopKey2 || keyCode == self.stopKey3 || keyCode == self.stopKey4 || keyCode == self.stopKey5)
    ? true : false;
}

#pragma mark static methods

+ (D3KeyConfig *) defaultKeyConfig {
    D3KeyConfig * config = [[D3KeyConfig alloc] init];
    //config.startKey = kVK_Space;
    config.memo = @"";
    config.startKey = kVK_ANSI_Grave;
    config.stopKey1 = kVK_Return;
    config.stopKey2 = kVK_ANSI_T; // town portal
    config.stopKey3 = kVK_Space;
    config.stopKey4 = kVK_ANSI_M; // map
    config.stopKey5 = kVK_ANSI_R; // reply
    config.skillKey1 = kVK_ANSI_1;
    config.skillKey2 = kVK_ANSI_2;
    config.skillKey3 = kVK_ANSI_3;
    config.skillKey4 = kVK_ANSI_4;
    config.skillKey5 = 0xFE;
    config.skillKey6 = 0xFE;
    config.mouseRightKey = kCGMouseButtonRight;
    config.mouseLeftKey = kCGMouseButtonLeft;
    return config;
}

#pragma mark NSCoding impl

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:[NSNumber numberWithUnsignedShort:self.startKey] forKey:@"startKey"];
    
    [aCoder encodeObject:[NSNumber numberWithUnsignedShort:self.stopKey1] forKey:@"stopKey1"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedShort:self.stopKey2] forKey:@"stopKey2"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedShort:self.stopKey3] forKey:@"stopKey3"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedShort:self.stopKey4] forKey:@"stopKey4"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedShort:self.stopKey5] forKey:@"stopKey5"];
    
    [aCoder encodeObject:[NSNumber numberWithUnsignedShort:self.skillKey1] forKey:@"skillKey1"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedShort:self.skillKey2] forKey:@"skillKey2"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedShort:self.skillKey3] forKey:@"skillKey3"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedShort:self.skillKey4] forKey:@"skillKey4"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedShort:self.skillKey5] forKey:@"skillKey5"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedShort:self.skillKey6] forKey:@"skillKey6"];
    
    [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.skillDelay1] forKey:@"skillDelay1"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.skillDelay2] forKey:@"skillDelay2"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.skillDelay3] forKey:@"skillDelay3"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.skillDelay4] forKey:@"skillDelay4"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.skillDelay5] forKey:@"skillDelay5"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.skillDelay6] forKey:@"skillDelay6"];
    
    [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.mouseLeftDelay] forKey:@"mouseLeftDelay"];
    [aCoder encodeObject:[NSNumber numberWithUnsignedInteger:self.mouseRightDelay] forKey:@"mouseRightDelay"];
    
}

- (id) initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super init])) {
        self.startKey = [[aDecoder decodeObjectForKey:@"startKey"] unsignedShortValue];
        
        self.stopKey1 = [[aDecoder decodeObjectForKey:@"stopKey1"] unsignedShortValue];
        self.stopKey2 = [[aDecoder decodeObjectForKey:@"stopKey2"] unsignedShortValue];
        self.stopKey3 = [[aDecoder decodeObjectForKey:@"stopKey3"] unsignedShortValue];
        self.stopKey4 = [[aDecoder decodeObjectForKey:@"stopKey4"] unsignedShortValue];
        self.stopKey5 = [[aDecoder decodeObjectForKey:@"stopKey5"] unsignedShortValue];
        
        self.skillKey1 = [[aDecoder decodeObjectForKey:@"skillKey1"] unsignedShortValue];
        self.skillKey2 = [[aDecoder decodeObjectForKey:@"skillKey2"] unsignedShortValue];
        self.skillKey3 = [[aDecoder decodeObjectForKey:@"skillKey3"] unsignedShortValue];
        self.skillKey4 = [[aDecoder decodeObjectForKey:@"skillKey4"] unsignedShortValue];
        self.skillKey5 = [[aDecoder decodeObjectForKey:@"skillKey5"] unsignedShortValue];
        self.skillKey6 = [[aDecoder decodeObjectForKey:@"skillKey6"] unsignedShortValue];
        
        self.skillDelay1 = [[aDecoder decodeObjectForKey:@"skillDelay1"] unsignedIntegerValue];
        self.skillDelay2 = [[aDecoder decodeObjectForKey:@"skillDelay2"] unsignedIntegerValue];
        self.skillDelay3 = [[aDecoder decodeObjectForKey:@"skillDelay3"] unsignedIntegerValue];
        self.skillDelay4 = [[aDecoder decodeObjectForKey:@"skillDelay4"] unsignedIntegerValue];
        self.skillDelay5 = [[aDecoder decodeObjectForKey:@"skillDelay5"] unsignedIntegerValue];
        self.skillDelay6 = [[aDecoder decodeObjectForKey:@"skillDelay6"] unsignedIntegerValue];
        
        self.mouseLeftKey = kCGMouseButtonLeft;
        self.mouseRightKey = kCGMouseButtonRight;
        
        self.mouseLeftDelay = [[aDecoder decodeObjectForKey:@"mouseLeftDelay"] unsignedIntegerValue];
        self.mouseRightDelay = [[aDecoder decodeObjectForKey:@"mouseRightDelay"] unsignedIntegerValue];
        
    }
    return self;
}

@end
