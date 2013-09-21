//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "Quake2Toolbar.h"
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2006 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
// Quake IIª is copyrighted by id software  [http://www.idsoftware.com].
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#import <Cocoa/Cocoa.h>
#import "Quake2.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@interface Quake2 (Toolbar)

- (void) awakeFromNib;
- (BOOL) validateToolbarItem: (NSToolbarItem *) theItem;
- (NSToolbarItem *) toolbar: (NSToolbar *) theToolbar itemForItemIdentifier: (NSString *) theIdentifier
                                                  willBeInsertedIntoToolbar: (BOOL) theFlag;
- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar*) theToolbar;
- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar*) theToolbar;
- (void) addToolbarItem: (NSMutableDictionary *) theDict identifier: (NSString *) theIdentifier
                  label: (NSString *) theLabel paletteLabel: (NSString *) thePaletteLabel
                toolTip: (NSString *) theToolTip image: (id) theItemContent selector: (SEL) theAction;
- (void) changeView: (NSView *) theView title: (NSString *) theTitle;
- (IBAction) showAboutView: (id) theSender;
- (IBAction) showSoundView: (id) theSender;
- (IBAction) showCLIView: (id) theSender;

@end

//------------------------------------------------------------------------------------------------------------------------------------------------------------
