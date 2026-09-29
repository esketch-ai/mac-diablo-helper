//
//  D3DeadzoneFilter.h
//  d3key
//
//  Created for Diablo Helper Evolution.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface D3DeadzoneFilter : NSObject

+ (BOOL)isCursorInUIDeadzone:(NSString *)resolutionMode;
+ (NSArray<NSString *> *)supportedResolutions;

@end
