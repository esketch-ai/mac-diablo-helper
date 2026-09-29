//
//  MainWindowController.h
//  d3key
//
//  Created by sunghyuk-imac on 2016. 3. 2..
//  Updated for Diablo Helper Evolution.
//

#import <Cocoa/Cocoa.h>
#import "D3KeyConfig.h"
#import "D3KeyTextField.h"

#import "D3HelperEngine.h"
#import "D3PresetShareWindowController.h"

@interface MainWindowController : NSWindowController <NSTextFieldDelegate, D3HelperEngineDelegate, D3PresetShareDelegate>

// Legacy XIB outlets to satisfy nib loader
@property (nonatomic, strong) IBOutlet id configIdSegment;
@property (nonatomic, strong) IBOutlet id activeSegment;
@property (nonatomic, strong) IBOutlet id memoField;
@property (nonatomic, strong) IBOutlet id startKeyField;
@property (nonatomic, strong) IBOutlet id stopKeyField1, stopKeyField2, stopKeyField3, stopKeyField4, stopKeyField5;
@property (nonatomic, strong) IBOutlet id skillKeyField1, skillKeyField2, skillKeyField3, skillKeyField4, skillKeyField5, skillKeyField6;
@property (nonatomic, strong) IBOutlet id skillDelayField1, skillDelayField2, skillDelayField3, skillDelayField4, skillDelayField5, skillDelayField6;
@property (nonatomic, strong) IBOutlet id mouseLeftDelayField, mouseRightDelayField;

- (void)changePreset:(NSInteger)presetNum;
- (IBAction)selectConfigIdSegemnt:(id)sender;
- (IBAction)selectActiveSegment:(id)sender;

- (IBAction)presetSelected:(id)sender;
- (IBAction)runOpenerTest:(id)sender;

- (IBAction)importConfigFile:(id)sender;
- (IBAction)exportConfigFile:(id)sender;
- (IBAction)showHelpWindow:(id)sender;
- (IBAction)showPresetShareWindow:(id)sender;

@end
