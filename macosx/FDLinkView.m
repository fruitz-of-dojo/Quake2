//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "FDLinkView.m" - Provides an URL style link button.
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2006 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//
// IMPORTANT: THIS PIECE OF CODE MAY NOT BE USED WITH SHAREWARE OR COMMERCIAL APPLICATIONS WITHOUT PERMISSION.
//	          IT IS PROVIDED "AS IS" AND IS STILL COPYRIGHTED BY FRUITZ OF DOJO.
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#import <Cocoa/Cocoa.h>
#import "FDLinkView.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@interface FDLinkView (private)

- (void) initHandCursor;
- (void) initFontAttributes;
- (NSDictionary *) fontAttributesWithColor: (NSColor *) theColor;
- (void) openURL;

@end

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@implementation FDLinkView

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (id) initWithFrame: (NSRect) theFrame
{
    self = [super initWithFrame: theFrame];
	
    if (self)
    {
		[self initHandCursor];
		[self initFontAttributes];
	}
	
    return (self);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) dealloc
{
	[mHandCursor release];
	[mURLString release];
	[mFontAttributesRed release];
	[mFontAttributesBlue release];
    
    [super dealloc];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) setURLString: (NSString *) theURL
{
    if (theURL != nil)
    {
		[mURLString release];
        mURLString = [[NSString stringWithString: theURL] retain];
    }

    [self setNeedsDisplay: YES];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) drawRect: (NSRect) theRect
{
    if (mURLString != nil)
    {
		// draw the text:
		if (mMouseIsDown == YES)
		{
			[mURLString drawAtPoint: NSMakePoint (0.0, 0.0) withAttributes: mFontAttributesRed];
		}
		else
		{
			[mURLString drawAtPoint: NSMakePoint (0.0, 0.0) withAttributes: mFontAttributesBlue];
		}
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) mouseDown: (NSEvent *) theEvent;
{
    NSEvent *	myNextEvent;
    NSPoint 	myLocation;

    if (mURLString != nil)
    {
		mMouseIsDown = YES;
		
		[self setNeedsDisplay:YES];

		myNextEvent = [NSApp nextEventMatchingMask: NSLeftMouseUpMask
											untilDate: [NSDate distantFuture]
											inMode: NSEventTrackingRunLoopMode
											dequeue: YES];
											
		myLocation = [self convertPoint: [myNextEvent locationInWindow] fromView: nil];
		
		if (NSMouseInRect (myLocation, [self bounds], NO))
		{
			[self openURL];
		}
		
		mMouseIsDown = NO;
		
		[self setNeedsDisplay:YES];
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) resetCursorRects
{
	[self addCursorRect: [self bounds] cursor: mHandCursor];
}

@end

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@implementation FDLinkView (private)

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) initHandCursor
{
    mHandCursor = [[NSCursor alloc] initWithImage: [NSImage imageNamed: @"HandCursor"] hotSpot: NSMakePoint (5.0, 1.0)];

	[self addCursorRect: [self bounds] cursor: mHandCursor];
	[mHandCursor setOnMouseEntered: YES];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) initFontAttributes
{
    mFontAttributesRed	= [self fontAttributesWithColor: [NSColor redColor]];
    mFontAttributesBlue	= [self fontAttributesWithColor: [NSColor blueColor]];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (NSDictionary *) fontAttributesWithColor: (NSColor *) theColor
{
    return ([[NSDictionary alloc] initWithObjects: [NSArray arrayWithObjects:
                                                        [NSFont systemFontOfSize: [NSFont systemFontSize]],
                                                        theColor,
                                                        [NSNumber numberWithInt: NSSingleUnderlineStyle],
                                                        nil
                                                   ]
                                          forKeys: [NSArray arrayWithObjects:
                                                        NSFontAttributeName,
                                                        NSForegroundColorAttributeName,
                                                        NSUnderlineStyleAttributeName,
                                                        nil
                                                   ]
            ]);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) openURL
{
    if (mURLString != nil)
    {
		[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: mURLString]];
    }
}

@end

//------------------------------------------------------------------------------------------------------------------------------------------------------------
