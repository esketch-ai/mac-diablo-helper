//
//  D3KeyTextField.h
//  d3key
//
//  Created by sunghyuk-imac on 2016. 3. 4..
//  Updated for Diablo Helper Evolution.
//

#import <Cocoa/Cocoa.h>
#import "D3InputKey.h"

@interface D3KeyTextField : NSTextField

@property (nonatomic, strong) D3InputKey *inputKey;
@property (nonatomic, assign, readonly) BOOL isCapturing;
@property (nonatomic, assign) BOOL allowMouseLeft;

- (void)setInputKey:(D3InputKey *)inputKey;

@end
