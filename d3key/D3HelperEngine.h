//
//  D3HelperEngine.h
//  d3key
//
//  Created for Diablo Helper Evolution.
//

#import <Foundation/Foundation.h>
#import "D3KeyConfig.h"
#import "D3EventTapService.h"

@protocol D3HelperEngineDelegate <NSObject>
@optional
- (void)helperEngineStateChanged:(BOOL)isRunning;
- (void)helperEngineOpenerStateChanged:(BOOL)isOpenerRunning;
- (void)helperEnginePresetChangeRequested:(NSInteger)presetIndex;
@end

@interface D3HelperEngine : NSObject <D3EventTapListener>

@property (nonatomic, strong) D3KeyConfig *config;
@property (nonatomic, weak) id<D3HelperEngineDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, assign, readonly) BOOL isOpenerRunning;
@property (nonatomic, assign, readonly) pid_t targetPid;

+ (instancetype)sharedEngine;

- (void)start;
- (void)stop;
- (void)toggle;
- (void)triggerOpener;

- (void)updateConfig:(D3KeyConfig *)newConfig;

@end
