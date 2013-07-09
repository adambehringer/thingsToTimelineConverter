//
//  BDThingsImportController.m
//  Things Timeline 3D Exporter
//
//  Created by Adam Behringer on 7/3/13.
//  Copyright (c) 2013 BEEDOCS, Inc. All rights reserved.
//

#import "BDThingsImportController.h"
#import "NSString+BDString.h"
#import "Things.h"

static const NSString *kListNameStr = @"ListName";
static const NSString *kListCountWithoutFinishedStr = @"ListCountWithoutFinished";
static const NSString *kListCountWithFinishedStr = @"ListCountWithFinished";

static NSString *kListNameColumnIdentifier = @"list";
static NSString *kListToDoCountColumnIdentifier = @"todoCount";

// Private
@interface BDThingsImportController () <NSTableViewDataSource, NSTableViewDelegate>

// interface outlets
@property (weak) IBOutlet NSButton *checkboxIncludeCompleted;
@property (weak) IBOutlet NSButton *checkboxIncludeName;
@property (weak) IBOutlet NSButton *checkboxIncludeDueDate;
@property (weak) IBOutlet NSButton *checkboxIncludeNotes;
@property (weak) IBOutlet NSTableView *tableView;

// properties
@property (nonatomic, strong) ThingsApplication *thingsApp;
@property (nonatomic, strong) NSArray *listsArray;

@end

@implementation BDThingsImportController

#pragma mark - Accessors

- (ThingsApplication *)thingsApp
{
    if (!_thingsApp)
    {
        // Get the scripting bridge proxy for Things
        _thingsApp = [SBApplication applicationWithBundleIdentifier:@"com.culturedcode.things"];
    }
    
    if (!_thingsApp.isRunning)
        [_thingsApp activate];
    
    return _thingsApp;
}

#pragma mark - Actions

- (IBAction)refreshThingsDatabase:(id)sender
{
    [self refreshCache];
    [self.tableView reloadData];
}

- (IBAction)toggledFinishedOption:(NSButton *)sender
{
    [self.tableView reloadData];
}

- (IBAction)export:(id)sender
{
    // confirm that we have some items to export before continuing
    NSDictionary *listDict = self.listsArray[self.tableView.selectedRow];
    
    if ((self.checkboxIncludeCompleted.state == NSOnState
         && [listDict[kListCountWithFinishedStr] integerValue] < 1)
        || [listDict[kListCountWithoutFinishedStr] integerValue] < 1)
    {
        NSAlert *alert = [NSAlert alertWithMessageText:@"Empty Export" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"The options you selected do not include any to-do items. Export will be cancelled."];
        alert.alertStyle = NSWarningAlertStyle;
        [alert runModal];
        return;
    }
    
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.title = @"Export Things To-dos";
    savePanel.prompt = @"Export";
    savePanel.canCreateDirectories = YES;
    savePanel.nameFieldStringValue = @"timeline";
    savePanel.extensionHidden = NO;
    savePanel.allowedFileTypes = @[ @"txt" ];
    savePanel.allowsOtherFileTypes = NO;
    
    [savePanel beginSheetModalForWindow:[self.tableView window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton)
        {
            BOOL success = [self exportToTextFile:savePanel.URL];
            
            if (success)
            {
                NSBeep();
                NSAlert *alert = [NSAlert alertWithMessageText:@"Done Exporting Things To-dos" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"To open the file with Timeline 3D, drag-and-drop it onto the Timeline 3D app icon or use File > Open…"];
                alert.alertStyle = NSInformationalAlertStyle;
                [alert runModal];
            }
        }
    }];
}

#pragma mark - Private

- (BOOL)exportToTextFile:(NSURL *)outputURL
{
    SBElementArray *listItems = self.thingsApp.lists;
    ThingsList *selectedList = listItems[self.tableView.selectedRow];
    
    NSMutableString *outputStr = [NSMutableString stringWithString:@"Label\tStart Time\tEnd Time\tLink\tNotes\tImage\tMovie\tTags\tColor\n"]; // required first line
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    
    for (ThingsToDo *todo in selectedList.toDos)
    {
        if (!todo.dueDate || todo.status == ThingsStatusCanceled) continue;
        
        if (self.checkboxIncludeCompleted.state == NSOffState && todo.status != ThingsStatusOpen)
            continue;
        
        // if text could have a tab or line breaks, use our string category stringWidthoutTabsAndReturns to encode it in a way that Timeline 3D can parse it.
        
        NSString *name = (self.checkboxIncludeName.state == NSOnState) ? [todo.name stringWithoutTabsAndReturns] : @"";
        NSString *startDate = [dateFormatter stringFromDate:todo.dueDate];
        NSString *endDate = @""; // not using an end date, but still need the placeholder
		NSString *link = @""; // not using a link, but still need the placeholder
        NSString *notes = (self.checkboxIncludeNotes.state == NSOnState) ? [todo.notes stringWithoutTabsAndReturns] : @"";
        
        [outputStr appendFormat:@"%@\t%@\t%@\t%@\t%@\n", name, startDate, endDate, link, notes];
    }
    
    NSError *error;
    [outputStr writeToURL:outputURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error) NSLog(@"Error writing out text file. %@", error);
    
    return YES;
}

- (void)refreshCache
{
    if (self.thingsApp)
    {
        NSMutableArray *listsArrayMutable = [NSMutableArray array];
        SBElementArray *listItems = self.thingsApp.lists;
        
        for (ThingsList *list in listItems)
        {
            NSUInteger countOfOpenTodosWithDueDates = 0;
            NSUInteger countOfAllTodosWithDueDates = 0;
            
            for (ThingsToDo *todo in list.toDos)
            {
                if (!todo.dueDate || todo.status == ThingsStatusCanceled) continue;
                
                ++countOfAllTodosWithDueDates;
                
                if (todo.status == ThingsStatusOpen)
                    ++countOfOpenTodosWithDueDates;
            }

            NSDictionary *listItemDict = @{ kListNameStr                 : list.name,
                                            kListCountWithoutFinishedStr : @(countOfOpenTodosWithDueDates),
                                            kListCountWithFinishedStr    : @(countOfAllTodosWithDueDates) };
            
            [listsArrayMutable addObject:listItemDict];
        }
        
        self.listsArray = [listsArrayMutable copy];
    }
}

# pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.listsArray.count;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    NSDictionary *listDict = self.listsArray[rowIndex];
    
    if ([aTableColumn.identifier isEqualToString:kListNameColumnIdentifier])
        return listDict[kListNameStr];
    
    else if ([aTableColumn.identifier isEqualToString:kListToDoCountColumnIdentifier])
    {
        if (self.checkboxIncludeCompleted.state == NSOnState)
            return listDict[kListCountWithFinishedStr];
        else
            return listDict[kListCountWithoutFinishedStr];
    }
    else
        return nil;
}

#pragma mark - Lifecycle

- (void)awakeFromNib
{
    [self refreshCache];
    
    if (self.tableView.selectedRow < 0 && self.listsArray.count > 0) // make sure at least one row is selected
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
}


@end
