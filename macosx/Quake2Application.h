//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "Quake2Application.h" - required for getting the height of the startup dialog's toolbar.
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2006 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
// Quake IIª is copyrighted by id software	[http://www.idsoftware.com].
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#import <Cocoa/Cocoa.h>

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@interface Quake2Application : NSApplication

- (void) sendEvent: (NSEvent *) theEvent;
- (void) sendSuperEvent: (NSEvent *) theEvent;
- (void) handleRunCommand: (NSScriptCommand *) theCommand;
- (void) handleConsoleCommand: (NSScriptCommand *) theCommand;

@end

//------------------------------------------------------------------------------------------------------------------------------------------------------------
