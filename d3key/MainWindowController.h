//
//  MainWindowController.h
//  d3key
//
//  Created by sunghyuk-imac on 2016. 3. 2..
//  Copyright © 2016년 sunghyuk. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MainWindowController : NSWindowController <NSTextFieldDelegate>
{
    
    IBOutlet NSSegmentedControl *configIdSegment;
    IBOutlet NSSegmentedControl *activeSegment;
    
    IBOutlet NSTextField *memoField;
    
    IBOutlet NSTextField *startKeyField;
    
    IBOutlet NSTextField *stopKeyField1;
    IBOutlet NSTextField *stopKeyField2;
    IBOutlet NSTextField *stopKeyField3;
    IBOutlet NSTextField *stopKeyField4;
    IBOutlet NSTextField *stopKeyField5;
    
    IBOutlet NSTextField *skillKeyField1;
    IBOutlet NSTextField *skillKeyField2;
    IBOutlet NSTextField *skillKeyField3;
    IBOutlet NSTextField *skillKeyField4;
    IBOutlet NSTextField *skillKeyField5;
    IBOutlet NSTextField *skillKeyField6;
    
    IBOutlet NSTextField *skillDelayField1;
    IBOutlet NSTextField *skillDelayField2;
    IBOutlet NSTextField *skillDelayField3;
    IBOutlet NSTextField *skillDelayField4;
    IBOutlet NSTextField *skillDelayField5;
    IBOutlet NSTextField *skillDelayField6;
    
    // add by latem
    IBOutlet NSTextField *mouseLeftDelayField;
    IBOutlet NSTextField *mouseRightDelayField;
    
}
- (void) changePreset:(NSInteger)presetNum;
- (IBAction) selectConfigIdSegemnt:(id)sender;
- (IBAction) selectActiveSegment:(id)sender;

@end
