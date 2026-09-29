//
//  D3EventTapService.h
//  d3key
//
//  Created for Diablo Helper Evolution.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "D3InputKey.h"

@protocol D3EventTapListener <NSObject>
@optional
- (void)onInputEvent:(D3InputKey *)inputKey isDown:(BOOL)isDown isRepeat:(BOOL)isRepeat;
- (void)onInputEvent:(D3InputKey *)inputKey isDown:(BOOL)isDown;
@end

@interface D3EventTapService : NSObject

@property (nonatomic, weak) id<D3EventTapListener> listener;
@property (nonatomic, copy) void (^keyCaptureHandler)(D3InputKey *capturedKey);

+ (instancetype)sharedService;

- (BOOL)startEventTap;
- (void)stopEventTap;
- (BOOL)isRunning;

- (BOOL)isKeyPressed:(D3InputKey *)key;
- (NSSet<D3InputKey *> *)pressedKeys;

- (void)startCapturingKeyWithHandler:(void (^)(D3InputKey *capturedKey))handler;
- (void)stopCapturingKey;

@end
