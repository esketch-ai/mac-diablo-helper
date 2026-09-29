//
//  D3EventPoster.h
//  d3key
//
//  Created for Diablo Helper Evolution.
//

#import <Foundation/Foundation.h>
#import "D3InputKey.h"

@interface D3EventPoster : NSObject

+ (void)postInputKey:(D3InputKey *)inputKey targetPid:(pid_t)targetPid;

+ (void)postKeyDown:(D3InputKey *)inputKey;
+ (void)postKeyUp:(D3InputKey *)inputKey;
+ (void)postKeyDown:(D3InputKey *)inputKey targetPid:(pid_t)targetPid;
+ (void)postKeyUp:(D3InputKey *)inputKey targetPid:(pid_t)targetPid;

+ (void)postLeftClick;
+ (void)postRightClick;
+ (void)postMiddleClick;
+ (void)postMouseButtonClick:(CGMouseButton)button;
+ (void)postWheelScroll:(D3WheelDirection)direction;

@end
