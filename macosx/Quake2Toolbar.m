//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "Quake2Toolbar.m"
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2006 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
// Quake IIª is copyrighted by id software  [http://www.idsoftware.com].
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#import "Quake2Toolbar.h"
#import "NSToolbarPrivate.h"

#import "sys_osx.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@implementation Quake2 (Toolbar)

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) awakeFromNib
{
    NSToolbar *	myToolbar = [[[NSToolbar alloc] initWithIdentifier: @"Quake Toolbar"] autorelease];

    // required for event handling:
	mRequestedCommands	= [[NSMutableArray alloc] initWithCapacity: 0];
	mDistantPast		= [[NSDate distantPast] retain];
	mDenyDrag			= NO;
    NSImage	* aboutImg	= [[NSWorkspace sharedWorkspace] iconForFileType: NSFileTypeForHFSTypeCode(kToolbarInfoIcon)];

	// set the URL at the FDLinkView:
	[linkView setURL: [NSURL URLWithString: SYS_FRUITZ_OF_DOJO_URL]];

    // initialize the toolbar:
    mToolbarItems = [[NSMutableDictionary dictionary] retain];
    [self addToolbarItem: mToolbarItems identifier: SYS_ABOUT_TOOLBARITEM label: @"About" paletteLabel: @"About"
                 toolTip: @"About Quake II." image: aboutImg
                selector: @selector (showAboutView:)];
    [self addToolbarItem: mToolbarItems identifier: SYS_AUDIO_TOOLBARITEM label: @"Sound" paletteLabel: @"Sound"
                 toolTip: @"Change sound settings." imageNamed: @"Sound.icns" selector: @selector (showSoundView:)];
    [self addToolbarItem: mToolbarItems identifier: SYS_PARAM_TOOLBARITEM label: @"CLI" paletteLabel: @"CLI"
                 toolTip: @"Set command-line parameters." imageNamed: @"Arguments.icns"
                selector: @selector (showCLIView:)];
    [self addToolbarItem: mToolbarItems identifier: SYS_START_TOOLBARITEM label: @"Play" paletteLabel: @"Play"
                 toolTip: @"Start the game." imageNamed: @"Start.icns"
                selector: @selector (startQuake2:)];
    
    [myToolbar setDelegate: self];    
    [myToolbar setAllowsUserCustomization: NO];
    [myToolbar setAutosavesConfiguration: NO];
    [myToolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
    [startupWindow setToolbar: myToolbar];
    [self showAboutView: self];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (BOOL) validateToolbarItem: (NSToolbarItem *) theItem
{
    return (YES);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (NSToolbarItem *) toolbar: (NSToolbar *) theToolbar itemForItemIdentifier: (NSString *) theIdentifier
                                                  willBeInsertedIntoToolbar: (BOOL) theFlag
{
    NSToolbarItem *myItem = [mToolbarItems objectForKey: theIdentifier];
    NSToolbarItem *myNewItem = [[[NSToolbarItem alloc] initWithItemIdentifier: theIdentifier] autorelease];
    
    [myNewItem setLabel: [myItem label]];
    [myNewItem setPaletteLabel: [myItem paletteLabel]];
    [myNewItem setImage: [myItem image]];
    [myNewItem setToolTip: [myItem toolTip]];
    [myNewItem setTarget: [myItem target]];
    [myNewItem setAction: [myItem action]];
    [myNewItem setMenuFormRepresentation: [myItem menuFormRepresentation]];

    return (myNewItem);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar*) theToolbar
{
    return ([NSArray arrayWithObjects: SYS_ABOUT_TOOLBARITEM, SYS_AUDIO_TOOLBARITEM, 
                                       SYS_PARAM_TOOLBARITEM, NSToolbarFlexibleSpaceItemIdentifier,
                                       SYS_START_TOOLBARITEM, nil]);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar*) theToolbar
{
    return ([NSArray arrayWithObjects: SYS_ABOUT_TOOLBARITEM, SYS_AUDIO_TOOLBARITEM,
                                       SYS_PARAM_TOOLBARITEM, SYS_START_TOOLBARITEM,
                                       NSToolbarFlexibleSpaceItemIdentifier, nil]);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) addToolbarItem: (NSMutableDictionary *) theDict identifier: (NSString *) theIdentifier
                  label: (NSString *) theLabel paletteLabel: (NSString *) thePaletteLabel
                toolTip: (NSString *) theToolTip imageNamed: (NSString *) theItemContent selector: (SEL) theAction
{
    [self addToolbarItem:theDict identifier:theIdentifier label:theLabel paletteLabel:thePaletteLabel toolTip:theToolTip image:[NSImage imageNamed:theItemContent] selector:theAction];
}

- (void) addToolbarItem: (NSMutableDictionary *) theDict identifier: (NSString *) theIdentifier
                  label: (NSString *) theLabel paletteLabel: (NSString *) thePaletteLabel
                toolTip: (NSString *) theToolTip image: (NSImage*) theItemContent selector: (SEL) theAction
{
    NSToolbarItem *	myItem = [[[NSToolbarItem alloc] initWithItemIdentifier: theIdentifier] autorelease];

    [myItem setLabel: theLabel];
    [myItem setPaletteLabel: thePaletteLabel];
    [myItem setToolTip: theToolTip];
    [myItem setTarget: self];
    [myItem setImage: theItemContent];
    [myItem setAction: theAction];
    [theDict setObject: myItem forKey: theIdentifier];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) changeView: (NSView *) theView title: (NSString *) theTitle
{
    NSRect	myCurFrame;
	NSRect	myNewFrame;
    UInt32	myNewHeight;
    
    if (theView == NULL || theView == [startupWindow contentView])
    {
        return;
    }
    
    if (mEmptyView == NULL)
    {
        mEmptyView = [[startupWindow contentView] retain];
    }

    myCurFrame = [NSWindow contentRectForFrameRect:[startupWindow frame] styleMask:[startupWindow styleMask]];
    [mEmptyView setFrame: myCurFrame];
    [startupWindow setContentView: mEmptyView];

    myNewHeight = NSHeight ([theView frame]);
	
    if ([[startupWindow toolbar] isVisible])
    {
        myNewHeight += NSHeight ([[[startupWindow toolbar] _toolbarView] frame]);
    }
    myNewFrame = NSMakeRect (NSMinX (myCurFrame), NSMaxY (myCurFrame ) - myNewHeight,
                             NSWidth (myCurFrame), myNewHeight);
    myNewFrame = [NSWindow frameRectForContentRect: myNewFrame styleMask: [startupWindow styleMask]];

    [startupWindow setFrame: myNewFrame display: YES animate: [startupWindow isVisible]];
    [startupWindow setContentView: theView];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) showAboutView: (id) theSender
{
    [self changeView: aboutView title: @"About"];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) showSoundView: (id) theSender
{
    [self changeView: audioView title: @"Sound"];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) showCLIView: (id) theSender
{
    [self changeView: parameterView title: @"CLI"];
}

@end

//------------------------------------------------------------------------------------------------------------------------------------------------------------
