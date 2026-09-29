//
//  D3DeadzoneFilter.m
//  d3key
//
//  Created for Diablo Helper Evolution.
//

#import "D3DeadzoneFilter.h"
#import <AppKit/AppKit.h>

@implementation D3DeadzoneFilter

+ (NSArray<NSString *> *)supportedResolutions {
    return @[
        @"자동 감지 (현재 디스플레이)",
        @"1920 x 1080 (FHD)",
        @"2560 x 1440 (QHD)",
        @"3440 x 1440 (UltraWide)",
        @"3840 x 2160 (4K UHD)",
        @"2880 x 1800 (MacBook Pro 15/16\")",
        @"3024 x 1964 (MacBook Pro 14\")",
        @"2560 x 1600 (MacBook Pro 13\" / Air)"
    ];
}

+ (BOOL)isCursorInUIDeadzone:(NSString *)resolutionMode {
    CGEventRef event = CGEventCreate(NULL);
    if (!event) return NO;
    CGPoint cursorLoc = CGEventGetLocation(event);
    CFRelease(event);
    
    // 멀티 모니터 환경 대응: 커서가 위치한 실제 디스플레이 식별
    CGDirectDisplayID matchingDisplay = CGMainDisplayID();
    uint32_t displayCount = 0;
    CGGetDisplaysWithPoint(cursorLoc, 1, &matchingDisplay, &displayCount);
    
    CGRect screenBounds = CGDisplayBounds(matchingDisplay);
    CGFloat screenW = screenBounds.size.width;
    CGFloat screenH = screenBounds.size.height;
    
    // 해당 디스플레이 내 상대 좌표 계산 (0,0 ~ screenW, screenH)
    CGFloat relX = cursorLoc.x - screenBounds.origin.x;
    CGFloat relY = cursorLoc.y - screenBounds.origin.y;
    
    // 특정 고정 해상도 모드가 강제 지정된 경우 스케일 보정
    if ([resolutionMode containsString:@"1920 x 1080"]) {
        relX = (relX / screenW) * 1920.0;
        relY = (relY / screenH) * 1080.0;
        screenW = 1920.0; screenH = 1080.0;
    } else if ([resolutionMode containsString:@"2560 x 1440"]) {
        relX = (relX / screenW) * 2560.0;
        relY = (relY / screenH) * 1440.0;
        screenW = 2560.0; screenH = 1440.0;
    } else if ([resolutionMode containsString:@"3440 x 1440"]) {
        relX = (relX / screenW) * 3440.0;
        relY = (relY / screenH) * 1440.0;
        screenW = 3440.0; screenH = 1440.0;
    } else if ([resolutionMode containsString:@"3840 x 2160"]) {
        relX = (relX / screenW) * 3840.0;
        relY = (relY / screenH) * 2160.0;
        screenW = 3840.0; screenH = 2160.0;
    }
    
    // CG 좌표계: (0,0)은 화면 좌상단, Y는 아래로 증가
    CGFloat bottomBarStartY = screenH * 0.80; // 화면 하단 20%
    CGFloat bottomBarStartX = screenW * 0.22; // 중앙 56% 폭 (0.22 ~ 0.78)
    CGFloat bottomBarEndX = screenW * 0.78;
    
    // 1. 하단 액션바 / 스킬바 / 구슬 영역 검사
    if (relY >= bottomBarStartY && relY <= screenH) {
        if (relX >= bottomBarStartX && relX <= bottomBarEndX) {
            return YES;
        }
    }
    
    // 2. 우측 상단 미니맵 영역 (D3: 우측 상단 15% 폭, 22% 높이)
    CGFloat miniMapStartX = screenW * 0.85;
    CGFloat miniMapEndY = screenH * 0.22;
    if (relX >= miniMapStartX && relY <= miniMapEndY) {
        return YES;
    }
    
    return NO;
}

@end
