//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "swimp_osx.c" - MacOS X software renderer.
//
// Written by:	awe				            [mailto:awe@fruitz-of-dojo.de].
//		        ©2001-2006 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
// Quake IIª is copyrighted by id software	[http://www.idsoftware.com].
//
// Version History:
// v1.1.0: Improved performance in windowed mode.
//         Window can be resized.
//	       Changed "minimized in Dock mode": now plays in the document miniwindow rather than inside the application icon.
//	       Screenshots are now saved in PNG format.
// v1.0.3: Screenshots are now saved as TIFF instead of PCX files [see "r_misc.c"].
// v1.0.0: Initial release.
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#import <AppKit/AppKit.h>
#import "FDScreenshot.h"
#include "r_local.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Macros

// We could iterate through active displays and capture them each, to avoid the CGReleaseAllDisplays() bug,
// but this would result in awfully switches between renderer selections, since we would have to clean-up the
// captured device list each time...

#ifdef CAPTURE_ALL_DISPLAYS

#define VID_CAPTURE_DISPLAYS()	CGCaptureAllDisplays ()
#define VID_RELEASE_DISPLAYS()	CGReleaseAllDisplays ()

#else

#define VID_CAPTURE_DISPLAYS()	CGDisplayCapture (kCGDirectMainDisplay)
#define VID_RELEASE_DISPLAYS()	CGDisplayRelease (kCGDirectMainDisplay)

#endif /* CAPTURE_ALL_DISPLAYS */

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@interface Quake2View : NSView
@end

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Variables

static Boolean				gVidFullscreen		= NO;
static Quake2View *			gVidView			= NULL;
static CGDirectPaletteRef 	gVidPalette			= NULL;
static NSWindow *			gVidWindow			= NULL;
static NSBitmapImageRep	*	gVidWindowBuffer	= NULL;
static NSImage *			gVidGrowboxImage	= NULL;
static NSImage *			gVidMiniWindow		= NULL;
static cvar_t *				gVidIsMinimized		= NULL;
static UInt32				gVidRGBAPalette[256];
static UInt16				gVidWidth;
static CFDictionaryRef		gVidOriginalMode;
static NSRect				gVidMiniWindowRect;

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Function Prototypes

inline	UInt16		SWimp_GetRowBytes (void);
inline	UInt64 *	SWimp_GetDisplayBaseAddress (void);
inline	void		SWimp_DrawBufferToRect (NSRect theRect);

static	void		SWimp_BlitWindow (void);
static	void		SWimp_BlitFullscreen1x1 (void);
static	void		SWimp_BlitFullscreen2x2 (void);
static	void		SWimp_CloseWindow (void);
static	void		SWimp_DisableQuartzInterpolation (id theView);

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

qboolean SWimp_Screenshot (SInt8 *theFilename, void *theBitmap, UInt32 theWidth, UInt32 theHeight, UInt32 theRowbytes)
{
    NSString *	myFilename		= [NSString stringWithCString: (const char*) theFilename];
    NSSize		myBitmapSize	= NSMakeSize ((float) theWidth, (float) theHeight);
    
    return ([FDScreenshot writeToPNG: myFilename fromRGB24: theBitmap withSize: myBitmapSize rowbytes: theRowbytes]);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	SWimp_DisableQuartzInterpolation (id theView)
{
    NSGraphicsContext *	myGraphicsContext;
    
    [theView lockFocus];
    myGraphicsContext = [NSGraphicsContext currentContext];
    [myGraphicsContext setImageInterpolation: NSImageInterpolationNone];
    [myGraphicsContext setShouldAntialias: NO];
    [theView unlockFocus];    
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

UInt64 * SWimp_GetDisplayBaseAddress (void)
{
    return ((UInt64 *) CGDisplayBaseAddress(kCGDirectMainDisplay));
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

UInt16	SWimp_GetRowBytes (void)
{
    return (CGDisplayBytesPerRow (kCGDirectMainDisplay));
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	SWimp_DrawBufferToRect (NSRect theRect)
{
    register UInt32 *	myDestinationBuffer	= (UInt32 *) [gVidWindowBuffer bitmapData];
    register UInt8 *	mySourceBuffer		= vid.buffer;
	register UInt8 *	mySourceBufferEnd	= mySourceBuffer + vid.width * vid.height;

    if (myDestinationBuffer != NULL)
    {
        // translate 8 bit to 32 bit color:
        while (mySourceBuffer < mySourceBufferEnd)
        {
            *myDestinationBuffer++ = gVidRGBAPalette[*mySourceBuffer++];
        }
        
        // draw the image:
        [gVidWindowBuffer drawInRect: theRect];
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	SWimp_BlitWindow (void)
{
    // any view available?
    if (gVidView != NULL && gVidWindow != NULL)
    {
        if ([gVidWindow isMiniaturized] == YES)
        {
            if (gVidMiniWindow != NULL)
            {
                [gVidMiniWindow lockFocus];
                SWimp_DrawBufferToRect (gVidMiniWindowRect);
                [gVidMiniWindow unlockFocus];
                [gVidWindow setMiniwindowImage: gVidMiniWindow];
            }
        }
        else
        {
            // we could use QuickDraw here, but there is an issue with QuickDraw:
            // If the user changes the display depth, Quake will hang forever.
    
            [gVidView lockFocus];
            
            // draw the current buffer:
            SWimp_DrawBufferToRect ([gVidView bounds]);
            
            // draw the growbox (we could avoid this step by using the "display" method,
            // but this will decrease performance much more than by drawing a custom growbox: 
            if (gVidGrowboxImage != NULL)
            {
                NSSize	myGrowboxSize		= [gVidGrowboxImage size];
                NSRect	myViewRect			= [gVidView bounds];
                NSPoint	myGrowboxLocation	= NSMakePoint (NSMaxX (myViewRect) - myGrowboxSize.width, NSMinY (myViewRect));
                
                [gVidGrowboxImage compositeToPoint: myGrowboxLocation operation: NSCompositeSourceOver];
            }
            
            [gVidView unlockFocus];
            [gVidWindow flushWindow];
        }
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	SWimp_BlitFullscreen1x1 (void)
{
    UInt64		myRowBytes	= (SWimp_GetRowBytes () - vid.width) / sizeof (UInt64);
    UInt64 *	myScreen	= SWimp_GetDisplayBaseAddress ();
	UInt64 *	myOffScreen	= (UInt64 *) vid.buffer;

    // just security:
    if (myScreen == NULL || myOffScreen == NULL)
    {
        ri.Sys_Error( ERR_FATAL, "Bad video buffer!");
    }

    // blit it [1x1]:
    if (myRowBytes == 0)
    {
        UInt32		myWidth = vid.width * vid.height / sizeof (UInt64);
		UInt32		i;
        
        for (i = 0; i < myWidth; i++)
        {
            *(myScreen++) = *(myOffScreen++); 
        }
    }
    else
    {
        UInt32		myWidth = vid.width / sizeof (UInt64);
		UInt32		x;
		UInt32		y;
        
        for (y = 0; y < vid.height; y++)
        {
            for (x = 0; x < myWidth; x++)
            {
                *(myScreen++) = *(myOffScreen++); 
            }
            myScreen += myRowBytes;
        }
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	SWimp_BlitFullscreen2x2 (void)
{
    UInt8 *		myOffScreen	= vid.buffer;
    UInt32		myWidthLoop	= vid.width >> 2;
    UInt64		myRowBytes	= (SWimp_GetRowBytes () - gVidWidth) / sizeof(UInt64);
	UInt64 *	myScreenLo	= SWimp_GetDisplayBaseAddress ();
	UInt64 *	myScreenHi	= myScreenLo + gVidWidth / sizeof (UInt64) + myRowBytes;
	UInt64		myPixels;
	UInt32		i;
	UInt32		j;

    // just security:
    if (myScreenLo == NULL || myScreenHi == NULL || myOffScreen == NULL)
    {
        ri.Sys_Error( ERR_FATAL, "Bad video buffer!");
    }

    myRowBytes = ((SWimp_GetRowBytes () << 1) - gVidWidth) / sizeof (UInt64);

    // blit it [2x2]:
    for (i = 0; i < vid.height; i++)
    {
        for (j = 0; j < myWidthLoop; j++)
        {
#ifdef __LITTLE_ENDIAN__

            myPixels  = ((UInt64) (*myOffScreen++));
            myPixels |= ((UInt64) (*myOffScreen++) << 16);
            myPixels |= ((UInt64) (*myOffScreen++) << 32);
            myPixels |= ((UInt64) (*myOffScreen++) << 48);

#else // __BIG_ENDIAN__

            myPixels  = ((UInt64) (*myOffScreen++) << 48);
            myPixels |= ((UInt64) (*myOffScreen++) << 32);
            myPixels |= ((UInt32) (*myOffScreen++) << 16);
            myPixels |= ((UInt64) (*myOffScreen++));

#endif // __BIG_ENDIAN__

            myPixels |= (myPixels << 8);
            
            *myScreenLo++ = myPixels;
            *myScreenHi++ = myPixels;
        }
        myScreenLo += myRowBytes;
        myScreenHi += myRowBytes;
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	SWimp_EndFrame (void)
{
    // are we in windowed mode?
    if (gVidFullscreen == NO)
    {
        SWimp_BlitWindow ();
        return;
    }

    // wait for the VBL:
    CGDisplayWaitForBeamPositionOutsideLines (kCGDirectMainDisplay, 0, 1);

    // change the palette:
    if (gVidPalette != NULL)
    {
        CGDisplaySetPalette (kCGDirectMainDisplay, gVidPalette);
        free (gVidPalette);
        gVidPalette = NULL;
    }

    // blit the video to the screen:
    if (gVidWidth == vid.width)
    {
        SWimp_BlitFullscreen1x1 ();
    }
    else
    {
        SWimp_BlitFullscreen2x2 ();
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	SWimp_SetPaletteWindowed (const unsigned char *thePalette)
{
    UInt8 *	myPalette = (UInt8 *) gVidRGBAPalette;
	UInt8	i = 0;

    do
    {
        myPalette[0] = thePalette[0];
       	myPalette[1] = thePalette[1];
        myPalette[2] = thePalette[2];
        myPalette[3] = 0xff;
        
        myPalette	+= 4;
        thePalette	+= 4;
		
        i++;
    } while (i != 0);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	SWimp_SetPalette (const unsigned char *thePalette)
{
    // was a palette submitted?
    if (thePalette == NULL)
    {
        thePalette = (const unsigned char *) sw_state.currentpalette;
    }

    // are we in windowed mode?
    if (gVidFullscreen == NO)
    {
        SWimp_SetPaletteWindowed (thePalette);
    }
	else if (CGDisplayCanSetPalette(kCGDirectMainDisplay) == 0)
    {
        ri.Con_Printf (PRINT_ALL, "Can\'t set palette...\n");
    }
	else
	{
		CGDeviceColor 	mySampleTable[256];
		UInt16			i = 0;

		// convert the palette to float:
		for (; i < 256; i++)
		{
			mySampleTable[i].red	= (float) thePalette[i << 2] / 256.0f;
			mySampleTable[i].green	= (float) thePalette[(i << 2) + 1] / 256.0f;
			mySampleTable[i].blue	= (float) thePalette[(i << 2) + 2] / 256.0f;
		}
		
		// create a palette for core graphics:
		gVidPalette = CGPaletteCreateWithSamples (mySampleTable, 256);
		
		if (gVidPalette == NULL)
		{
			ri.Con_Printf (PRINT_ALL, "Can\'t create palette...\n");
		}
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

int	SWimp_Init (void *hInstance, void *wndProc)
{
    // for controlling mouse and minimized window:
    gVidIsMinimized		= ri.Cvar_Get ("_miniwindow", "0", 0);
    
    // save the original display mode:
    gVidOriginalMode	= CGDisplayCurrentMode (kCGDirectMainDisplay);

    // initialize the miniwindow [will not used, if alloc fails]:
    gVidMiniWindow		= [[NSImage alloc] initWithSize: NSMakeSize (128, 128)];
	gVidMiniWindowRect	= NSMakeRect (0.0f, 0.0f, [gVidMiniWindow size].width, [gVidMiniWindow size].height);
	gVidGrowboxImage	= [[NSImage alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"GrowBox" ofType: @"tiff"]];
	
    return (0);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	SWimp_Shutdown (void)
{
    // get the original display mode back:
    if (gVidOriginalMode)
    {
        CGDisplaySwitchToMode (kCGDirectMainDisplay, gVidOriginalMode);
    }

    // release the miniwindow:
    if (gVidMiniWindow != NULL)
    {
        [gVidMiniWindow release];
        gVidMiniWindow = NULL;
    }

    // close the window if available:
    if (gVidFullscreen == NO)
    {
        SWimp_CloseWindow ();
    }

    // free the offscreen buffer:
    if (vid.buffer)
    {
        free(vid.buffer);
        vid.buffer = NULL;
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	SWimp_CloseWindow (void)
{
    // close the old window:
    if (gVidWindow != NULL)
    {
        [gVidWindow close];
        gVidWindow = NULL;
    }
    
    // remove the old view:
    if (gVidView != NULL)
    {
        [gVidView release];
        gVidView = NULL;
    }
    
    // free the window buffer:
    if (gVidWindowBuffer != NULL)
    {
        [gVidWindowBuffer release];
        gVidWindowBuffer = NULL;
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

rserr_t	SWimp_SetMode (int *theWidth, int *theHeight, int theMode, qboolean theFullscreen)
{
    ri.Con_Printf (PRINT_ALL, "setting mode %d:", theMode);

    if (!ri.Vid_GetModeInfo (theWidth, theHeight, theMode))
    {
		ri.Con_Printf (PRINT_ALL, " invalid mode\n");
		return (rserr_invalid_mode);
    }

    ri.Con_Printf (PRINT_ALL, " %d %d\n", *theWidth, *theHeight);

    vid.width = vid.rowbytes = *theWidth;
    vid.height = *theHeight;

    if (theFullscreen == true)
    {
        CFDictionaryRef		myDisplayMode;
        Boolean				myVideoIsZoomed;
        boolean_t			myExactMatch;
        UInt16				myVidHeight;
        float				myNewRefreshRate = 0;
        cvar_t *			myRefreshRate;
        
        // get the refresh rate set by Vid_GetModeInfo ():
        myRefreshRate = ri.Cvar_Get ("vid_refreshrate", "0", 0);
        if (myRefreshRate != NULL)
        {
            myNewRefreshRate = myRefreshRate->value;
        }
        
        // remove the old window, if available:
        if (CGDisplayIsCaptured (kCGDirectMainDisplay) == false)
        {
            VID_CAPTURE_DISPLAYS();
        }
        SWimp_CloseWindow ();

        ri.Vid_NewWindow (vid.width, vid.height);

        if (vid.width < 640)
        {
            gVidWidth		= vid.width << 1;
            myVidHeight		= vid.height << 1;
            myVideoIsZoomed	= YES;
        }
        else
        {
            gVidWidth		= vid.width;
            myVidHeight		= vid.height;
            myVideoIsZoomed	= NO;
        }
    
        // switch to the new display mode:
                // get the requested mode:
        if (myNewRefreshRate > 0)
        {
            myDisplayMode = CGDisplayBestModeForParametersAndRefreshRate (kCGDirectMainDisplay, 8, gVidWidth,
                                                                          myVidHeight, myNewRefreshRate,
                                                                          &myExactMatch);
        }
        else
        {
            myDisplayMode = CGDisplayBestModeForParameters (kCGDirectMainDisplay, 8, gVidWidth, myVidHeight,
                                                            &myExactMatch);
        }
        
        // got we an exact mode match? if not report the new resolution again:
        if (myExactMatch == NO)
        {
            gVidWidth = [[(NSDictionary *) myDisplayMode objectForKey: (NSString *) kCGDisplayWidth] intValue];
            myVidHeight = [[(NSDictionary *) myDisplayMode objectForKey:(NSString *) kCGDisplayHeight] intValue];

            if (myVideoIsZoomed == YES)
            {
                vid.width = gVidWidth >> 1;
                vid.height =  myVidHeight >> 1;
            }
            else
            {
                vid.width = gVidWidth;
                vid.height = myVidHeight;
            }

            *theWidth = vid.rowbytes = vid.width;
            *theHeight = vid.height;

            ri.Vid_NewWindow (vid.width, vid.height);
            ri.Con_Printf (PRINT_ALL, "can\'t switch to mode %d. using %d %d.\n", theMode, *theWidth, *theHeight);
        }

        if (CGDisplaySwitchToMode (kCGDirectMainDisplay, myDisplayMode) != kCGErrorSuccess)
        {
            ri.Sys_Error( ERR_FATAL, "Can\'t switch to the selected mode!\n");
        }
    
        gVidFullscreen = YES;
    }
    else
    {
        NSRect		myContentRect;
        cvar_t *	myVidPosX;
        cvar_t *	myVidPosY;
        
        gVidWidth = vid.width;

        // get the window position:
        myVidPosX = ri.Cvar_Get ("vid_xpos", "0", 0);
        myVidPosY = ri.Cvar_Get ("vid_ypos", "0", 0);
        
        SWimp_CloseWindow ();
        CGDisplaySwitchToMode (kCGDirectMainDisplay, gVidOriginalMode);

        ri.Vid_NewWindow (vid.width, vid.height);

        // open the window:
        myContentRect = NSMakeRect (myVidPosX->value, myVidPosY->value, vid.width, vid.height);
        gVidWindow = [[NSWindow alloc] initWithContentRect: myContentRect
                                                 styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
                                                   backing: NSBackingStoreBuffered
                                                     defer: NO];

        if (gVidWindow == NULL)
        {
            ri.Sys_Error (ERR_FATAL, "Unable to create window!\n");
        }

        [gVidWindow setTitle: @"Quake II"];

        // setup the content view:
        myContentRect.origin.x = myContentRect.origin.y = 0;
        myContentRect.size.width = vid.width;
        myContentRect.size.height = vid.height;
        gVidView = [[Quake2View alloc] initWithFrame: myContentRect];
        
        if (gVidView == NULL)
        {
            ri.Sys_Error (ERR_FATAL, "Unable to create content view!\n");
        }

		[gVidWindow setMinSize: [gVidWindow frame].size];
		[gVidWindow setDocumentEdited: YES];
		[gVidWindow setBackgroundColor: [NSColor blackColor]];
		[gVidWindow useOptimizedDrawing: YES];
        [gVidWindow setContentView: gVidView];
        [gVidWindow makeFirstResponder: gVidView];
        [gVidWindow setDelegate: gVidView];
        
        [NSApp activateIgnoringOtherApps: YES];
        [gVidWindow display];
        [gVidWindow setAcceptsMouseMovedEvents: YES];

        // obtain window buffer:
        gVidWindowBuffer = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                                                   pixelsWide: vid.width
                                                                   pixelsHigh: vid.height
                                                                bitsPerSample: 8
                                                              samplesPerPixel: 4
                                                                     hasAlpha: YES
                                                                     isPlanar: NO
                                                               colorSpaceName: NSDeviceRGBColorSpace
                                                                  bytesPerRow: vid.rowbytes * 4
                                                                 bitsPerPixel: 32];

        // release displays:
        if (CGDisplayIsCaptured (kCGDirectMainDisplay) == true)
        {
            VID_RELEASE_DISPLAYS ();
        }

        [gVidWindow makeKeyAndOrderFront: nil];
        [gVidWindow makeMainWindow];
        
        gVidFullscreen = NO;
		
		SWimp_DisableQuartzInterpolation(gVidView);
    }

    // get the backbuffer:
    vid.buffer = malloc(vid.rowbytes * vid.height);
    if (vid.buffer == NULL)
    {
        ri.Sys_Error (ERR_FATAL, "Unabled to allocate the video backbuffer!\n");
    }

    return (rserr_ok);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	SWimp_AppActivate (qboolean active)
{
    // do nothing!
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark -

@implementation Quake2View

//------------------------------------------------------------------------------------------------------------------------------------------------------------

-(BOOL) acceptsFirstResponder
{
    return YES;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (BOOL) windowShouldClose: (id) theSender
{
    BOOL	myResult = ![[self window] isDocumentEdited];

    if (myResult == NO)
    {
		ri.Cmd_ExecuteText (EXEC_NOW, "menu_quit");
    }
	
    return (myResult);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) windowDidMove: (NSNotification *)note
{
    NSRect	myRect = [gVidWindow frame];
	
    ri.Cmd_ExecuteText (EXEC_NOW, va ("vid_xpos %i", (int) myRect.origin.x + 1));
    ri.Cmd_ExecuteText (EXEC_NOW, va ("vid_ypos %i", (int) myRect.origin.y + 1));
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) windowDidMiniaturize: (NSNotification *) theNotification
{
	if (gVidIsMinimized)
	{
		gVidIsMinimized->value = 1.0f;
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) windowDidDeminiaturize: (NSNotification *) theNotification
{
	if (gVidIsMinimized)
	{
		gVidIsMinimized->value = 0.0f;
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (NSSize) windowWillResize: (NSWindow *) theSender toSize: (NSSize) theProposedFrameSize
{
    NSRect	myMaxWindowRect	= [[theSender screen] visibleFrame];
	NSRect	myContentRect	= [[theSender contentView] frame];
	NSRect	myWindowRect	= [theSender frame];
    NSSize	myMinSize		= [theSender minSize];
	NSSize	myBorderSize;
    float	myAspect;

    // calculate window borders (e.g. titlebar):
    myBorderSize.width	= NSWidth (myWindowRect)  - NSWidth (myContentRect);
    myBorderSize.height	= NSHeight (myWindowRect) - NSHeight (myContentRect);
    
    // remove window borders (like titlebar) for the aspect calculations:
    myMaxWindowRect.size.width	-= myBorderSize.width;
    myMaxWindowRect.size.height	-= myBorderSize.height;
    theProposedFrameSize.width	-= myBorderSize.width;
    theProposedFrameSize.height	-= myBorderSize.height;
	myMinSize.width				-= myBorderSize.width;
	myMinSize.height			-= myBorderSize.height;
    
	myAspect = myMinSize.width / myMinSize.height;
	
    // set aspect ratio for the max rectangle:
    if (NSWidth (myMaxWindowRect) / NSHeight (myMaxWindowRect) > myAspect)
    {
        myMaxWindowRect.size.width = NSHeight (myMaxWindowRect) * myAspect;
    }
    else
    {
        myMaxWindowRect.size.height = NSWidth (myMaxWindowRect) / myAspect;
    }

    // set the aspect ratio for the proposed size:
    if (theProposedFrameSize.width / theProposedFrameSize.height > myAspect)
    {
        theProposedFrameSize.width = theProposedFrameSize.height * myAspect;
    }
    else
    {
        theProposedFrameSize.height = theProposedFrameSize.width / myAspect;
    }

    // clamp the window size to our max window rectangle:
    if (theProposedFrameSize.width > NSWidth (myMaxWindowRect) || theProposedFrameSize.height > NSHeight (myMaxWindowRect))
    {
        theProposedFrameSize = myMaxWindowRect.size;
    }

    if (theProposedFrameSize.width < myMinSize.width || theProposedFrameSize.height < myMinSize.height)
    {
        theProposedFrameSize = myMinSize;
    }

    theProposedFrameSize.width += myBorderSize.width;
    theProposedFrameSize.height += myBorderSize.height;

    return (theProposedFrameSize);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (NSRect) windowWillUseStandardFrame: (NSWindow *) theSender defaultFrame: (NSRect) theDefaultFrame
{
	theDefaultFrame.size = [self windowWillResize: theSender toSize: theDefaultFrame.size];
	
	return theDefaultFrame;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) drawRect: (NSRect) theRect
{
    if (gVidWindowBuffer != NULL)
    {
        [gVidWindowBuffer drawInRect: [self bounds]];
    }
}
	
@end

//------------------------------------------------------------------------------------------------------------------------------------------------------------
