//----------------------------------------------------------------------------------------------------------------------------
//
// "FDView.h"
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>

//----------------------------------------------------------------------------------------------------------------------------

@interface FDView : NSView
{
}

- (id) initWithFrame: (NSRect) frameRect;

- (void) setCursor: (NSCursor*) cursor;
- (NSCursor*) cursor;

- (void) setVsync: (BOOL) enabled;
- (BOOL) vsync;

- (NSOpenGLContext*) openGLContext;

@end

//----------------------------------------------------------------------------------------------------------------------------
