//----------------------------------------------------------------------------------------------------------------------------
//
// "FDWindow.h"
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import "FDDisplay.h"

#import <Cocoa/Cocoa.h>

//----------------------------------------------------------------------------------------------------------------------------

typedef void (*FDResizeHandler) (id fdView, void* pContext);

//----------------------------------------------------------------------------------------------------------------------------

@interface FDWindow : NSWindow
{
}

- (id) initForDisplay: (FDDisplay*) display;
- (id) initForDisplay: (FDDisplay*) display samples: (NSUInteger) samples;

- (id) initWithContentRect: (NSRect) rect;
- (id) initWithContentRect: (NSRect) rect samples: (NSUInteger) samples;

- (void) setResizeHandler: (FDResizeHandler) pResizeHandler forContext: (void*) pContext;

- (void) centerForDisplay: (FDDisplay*) display;

- (void) setCursorVisible: (BOOL) state;
- (BOOL) isCursorVisible;

- (void) setVsync: (BOOL) enabled;
- (BOOL) vsync;

- (NSOpenGLContext*) openGLContext;

- (BOOL) isFullscreen;

- (void) endFrame;

@end

//----------------------------------------------------------------------------------------------------------------------------
