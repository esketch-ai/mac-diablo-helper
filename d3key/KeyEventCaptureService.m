//
//  KeyEventCaptureService.m
//  d3key
//
//  Created by sunghyuk-imac on 2016. 3. 8..
//  Copyright © 2016년 sunghyuk. All rights reserved.
//

#import "KeyEventCaptureService.h"
#import "D3KeyConfigService.h"
#import <Carbon/Carbon.h>

@implementation KeyEventCaptureService
{
    NSEvent *_levent;
}

+ (KeyEventCaptureService *) sharedService {
    static id sharedInstance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        
    });
    
    return sharedInstance;
}

- (void) registerEvent:(D3KeyTextField *) textField {
    [self removeEvent];
    NSLog(@"register local key event monitor");
    _levent = [NSEvent addLocalMonitorForEventsMatchingMask:(NSKeyDownMask|NSFlagsChangedMask) handler:^(NSEvent *event) {
        if (event.keyCode == kVK_Delete) {
            textField.stringValue = @"";
            [[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:textField];
        } else if (event.keyCode == kVK_ANSI_Q && (event.modifierFlags & NSCommandKeyMask)) {
            // cmd+q, do nothing
        } else if (event.keyCode == 0x7A || event.keyCode == 0x78 || event.keyCode == 0x63 || event.keyCode == 0x76 || event.keyCode == 0x60) {
            // F1, F2, F3, F4, F5, do nothing
        } else if (event.keyCode != kVK_Tab && event.keyCode != kVK_Command) {
            textField.stringValue = [[D3KeyConfigService sharedService] stringWithKeycode:event.keyCode];
            [[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:textField];
        }
        
        return event;
    }];
}

- (void) removeEvent {
    if (_levent) {
        NSLog(@"remove local key event monitor");
        [NSEvent removeMonitor:_levent];
        _levent = nil;
    }
}


@end
