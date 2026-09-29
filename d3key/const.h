//
//  const.h
//  d3key
//
//  Created by sunghyuk on 2016. 3. 3..
//  Copyright © 2016년 sunghyuk. All rights reserved.
//

#ifndef const_h
#define const_h

static NSString * const kDiablo3AppId = @"com.blizzard.diablo3";
//static NSString * const kDiablo3AppId = @"com.github.atom";

static NSString * const kD3KeyConfigUserDefaultsKey = @"d3keyconfig";

static NSString * const kD3KeyStartStopNotification = @"d3keystartstopnote";
static NSString * const kD3KeyConfigChangedNotification = @"d3keyconfigchanged";
static NSString * const kD3KeyActivatedNotification = @"d3keyactivated";
static NSString * const kD3KeyDeactivatedNotification = @"d3keydeactivated";
static NSString * const kD3AccessibilityStatusChangedNotification = @"d3accessibilitychanged";
static NSString * const kD3EngineStateChangedNotification = @"d3enginestatechanged";

static const int64_t kD3SyntheticEventMagicTag = 0xD3D4A;

#define NSLog(...) NSLog(__VA_ARGS__)

#endif /* const_h */
