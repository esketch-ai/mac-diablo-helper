//
//  D3PresetShareWindowController.h
//  DM_Helper
//
//  Created by sunghyuk on 2026. 9. 29.
//  Copyright © 2026 sunghyuk. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "D3KeyConfig.h"
#import "D3PresetItem.h"

@protocol D3PresetShareDelegate <NSObject>
@required
- (void)presetShareDidSelectConfig:(D3KeyConfig *)config forSlot:(NSInteger)slot;
- (D3KeyConfig *)currentConfigForPresetSharing;
- (NSInteger)currentActiveSlot;
@end

@interface D3PresetShareWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate>

@property (nonatomic, weak) id<D3PresetShareDelegate> delegate;

+ (instancetype)sharedController;
- (void)showWindowAndRefresh:(id)sender;

@end
