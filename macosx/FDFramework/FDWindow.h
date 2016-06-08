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

- (instancetype) initForDisplay: (FDDisplay*) display;
- (instancetype) initForDisplay: (FDDisplay*) display samples: (NSUInteger) samples NS_DESIGNATED_INITIALIZER;

- (instancetype) initWithContentRect: (NSRect) rect;
- (instancetype) initWithContentRect: (NSRect) rect samples: (NSUInteger) samples NS_DESIGNATED_INITIALIZER;

- (void) setResizeHandler: (FDResizeHandler) pResizeHandler forContext: (void*) pContext;

- (void) centerForDisplay: (FDDisplay*) display;

@property (nonatomic, getter=isCursorVisible) BOOL cursorVisible;
@property BOOL vsync;

- (NSOpenGLContext*) openGLContext;

@property (readonly, getter=isFullscreen) BOOL fullscreen;

- (void) endFrame;

@end

//----------------------------------------------------------------------------------------------------------------------------
