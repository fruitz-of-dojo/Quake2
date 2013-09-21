//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "glimp_osx.c" - MacOS X OpenGL renderer.
//
// Written by:	awe                         [mailto:awe@fruitz-of-dojo.de].
//		        ©2001-2006 Fruitz Of Dojo   [http://www.fruitz-of-dojo.de].
//
// Quake IIª is copyrighted by id software  [http://www.idsoftware.com].
//
// Version History:
// v1.1.0: ¥ Changed "minimized in Dock mode": now plays in the document miniwindow rather than inside the application icon.
//	       ¥ Screenshots are now saved in PNG format.
// v1.0.8: ¥ Added support for non-overbright gamma [variable "gl_overbright_gamma"].
// v1.0.6: ¥ Added support for FSAA [variable "gl_ext_multisample"].
// v1.0.5: ¥ Added support for anisotropic texture filtering [variable "gl_anisotropic"].
//         ¥ Added support for Truform [variable "gl_truform"].
//         ¥ Improved renderer performance thru smaller lightmaps [define USE_SMALL_LIGHTMAPS at compile time].
//         ¥ "gl_mode" is now set to "0" instead of "3" by default. Fixes a problem with monitors which provide
//           only a single resolution.
// v1.0.3: ¥ Screenshots are now saved as TIFF instead of TGA files [see "gl_rmisc.c"].
//         ¥ Fixed an issue with wrong pixels at the right and left border of cinematics [see "gl_draw.c"].
// v1.0.1: ¥ added "gl_force16bit" command.
//         ¥ added "gl_swapinterval". 0 = no VBL wait, 1 = wait for VBL. Available via "Video Options" dialog, too.
//         ¥ added rendering inside the Dock [if window is minimized].
//           changes in "gl_rmain.c", line 1043 and later:
//         ¥ "gl_ext_palettedtexture" is now by default turned off.
//         ¥ "gl_ext_multitexture" is now possible, however default value is "0", due to bad performance.
// v1.0.0: Initial release.
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#import <AppKit/AppKit.h>
#import <IOKit/graphics/IOGraphicsTypes.h>
#import <OpenGL/OpenGL.h>
#import "FDScreenshot.h"

#include "gl_local.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Macros

// We could iterate through active displays and capture them each, to avoid the CGReleaseAllDisplays() bug,
// but this would result in awfully switches between renderer selections, since we would have to clean-up the
// captured device list each time...

#ifdef CAPTURE_ALL_DISPLAYS

#define GL_CAPTURE_DISPLAYS()	CGCaptureAllDisplays ()
#define GL_RELEASE_DISPLAYS()	CGReleaseAllDisplays ()

#else

#define GL_CAPTURE_DISPLAYS()	CGDisplayCapture (kCGDirectMainDisplay)
#define GL_RELEASE_DISPLAYS()	CGDisplayRelease (kCGDirectMainDisplay)

#endif /* CAPTURE_ALL_DISPLAYS */

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Defines

#define CG_MAX_GAMMA_TABLE_SIZE	256		// Required for getting and setting non-overbright gamma tables.

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark TypeDefs

typedef struct		{
                                CGTableCount		count;
                                CGGammaValue		red[CG_MAX_GAMMA_TABLE_SIZE];
                                CGGammaValue		green[CG_MAX_GAMMA_TABLE_SIZE];
                                CGGammaValue		blue[CG_MAX_GAMMA_TABLE_SIZE];
                        }	gl_gammatable_t;

#pragma mark -
                        
//------------------------------------------------------------------------------------------------------------------------------------------------------------

@interface Quake2GLView : NSView
@end

#pragma mark -

@interface NSOpenGLContext (CGLContextAccess)
- (CGLContextObj) cglContext;
@end

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Variables

qboolean					gGLTruformAvailable = NO;
long						gGLMaxARBMultiSampleBuffers;
long						gGLCurARBMultiSamples;

static CFDictionaryRef		gGLOriginalMode;
static CGGammaValue			gGLOriginalGamma[9];
static gl_gammatable_t		gGLOriginalGammaTable;
static NSRect				gGLMiniWindowRect;
static NSOpenGLContext *	gGLContext					= NULL;
static NSWindow	*			gGLWindow					= NULL;
static NSImage *			gGLMiniWindow				= NULL;
static NSBitmapImageRep *	gGLMiniWindowBuffer			= NULL;
static Quake2GLView *		gGLView						= NULL;
static float				gGLOldGamma					= 0.0f;
static float				gGLOldOverbrightGamma		= 0.0f;
static Boolean				gGLFullscreen				= NO;
static Boolean				gGLCanSetGamma				= NO;
cvar_t *					gGLSwapInterval				= NULL;
cvar_t *					gGLIsMinimized				= NULL;
cvar_t *					gGLGamma					= NULL;
cvar_t *					gGLTextureAnisotropyLevel	= NULL;
cvar_t *					gGLARBMultiSampleLevel		= NULL;
cvar_t *					gGLTrufomTesselationLevel	= NULL;
cvar_t *					gGLOverbrightGamma			= NULL;
static long					gGLMaxARBMultiSamples		= 0;
static const float			gGLTruformAmbient[4]		= { 1.0f, 1.0f, 1.0f, 1.0f };

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Function Prototypes

static void						GLimp_SetMiniWindowBuffer (void);
static void						GLimp_DestroyContext (void);
static NSOpenGLPixelFormat *	GLimp_CreateGLPixelFormat (int theDepth, Boolean theFullscreen);
static Boolean					GLimp_InitGraphics (int *theWidth, int *theHeight, float theRefreshRate, Boolean theFullscreen);
static void						GLimp_SetSwapInterval (void);
static void						GLimp_SetAnisotropyTextureLevel (void);
static void						GLimp_SetTruform (void);
static void						GLimp_SetARBMultiSample (void);
static void						GLimp_CheckForARBMultiSample (void);

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

qboolean GLimp_Screenshot (SInt8 *theFilename, void *theBitmap, UInt32 theWidth, UInt32 theHeight, UInt32 theRowbytes)
{
    NSString *	myFilename		= [NSString stringWithCString: (const char*) theFilename];
    NSSize		myBitmapSize	= NSMakeSize ((float) theWidth, (float) theHeight);
    
    return ([FDScreenshot writeToPNG: myFilename fromRGB24: theBitmap withSize: myBitmapSize rowbytes: theRowbytes]);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	GLimp_SetMiniWindowBuffer (void)
{
    if (gGLMiniWindowBuffer == NULL || [gGLMiniWindowBuffer pixelsWide] != vid.width || [gGLMiniWindowBuffer pixelsHigh] != vid.height)
    {
        [gGLMiniWindowBuffer release];
		
        gGLMiniWindowBuffer = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                                                      pixelsWide: vid.width
                                                                      pixelsHigh: vid.height
                                                                   bitsPerSample: 8
                                                                 samplesPerPixel: 4
                                                                        hasAlpha: YES
                                                                        isPlanar: NO
                                                                  colorSpaceName: NSDeviceRGBColorSpace
                                                                     bytesPerRow: vid.width * 4
                                                                    bitsPerPixel: 32];
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	GLimp_BeginFrame (float camera_separation)
{
    if (gGLFullscreen == YES)
    {
        if ((gGLGamma != NULL && gGLGamma->value != gGLOldGamma) ||
            (gGLOverbrightGamma != NULL && gGLOverbrightGamma->value != gGLOldOverbrightGamma))
        {
            if (gGLCanSetGamma == YES)
            {
                // clamp "gl_overbright_gamma" to "0" or "1":
                if (gGLOverbrightGamma != NULL)
                {
                    if (gGLOverbrightGamma->value < 0.0f)
                    {
                        ri.Cvar_SetValue ("gl_overbright_gamma", 0);
                    }
                    else
                    {
                        if (gGLOverbrightGamma->value > 0.0f && gGLOverbrightGamma->value != 1.0f)
                        {
                            ri.Cvar_SetValue ("gl_overbright_gamma", 1);
                        }
                    }
                }
                
                // finally set the new gamma:
                if (gGLOverbrightGamma != NULL && gGLOverbrightGamma->value == 0.0f)
                {
                    static gl_gammatable_t	myNewTable;
                    UInt16 			i;
                    float			myNewGamma;
                    
                    myNewGamma = (1.4f - gGLGamma->value) * 2.5f;
                    if (myNewGamma < 1.0f)
                    {
                        myNewGamma = 1.0f;
                    }
                    else
                    {
                        if (myNewGamma > 2.25f)
                        {
                            myNewGamma = 2.25f;
                        }
                    }
                    
                    for (i = 0; i < gGLOriginalGammaTable.count; i++)
                    {
                        myNewTable.red[i]   = myNewGamma * gGLOriginalGammaTable.red[i];
                        myNewTable.green[i] = myNewGamma * gGLOriginalGammaTable.green[i];
                        myNewTable.blue[i]  = myNewGamma * gGLOriginalGammaTable.blue[i];
                    }
                    
                    CGSetDisplayTransferByTable (kCGDirectMainDisplay, gGLOriginalGammaTable.count,
                                                 myNewTable.red, myNewTable.green, myNewTable.blue);
                }
                else
                {
                    gGLOldGamma = 1.0f - gGLGamma->value;
                    if (gGLOldGamma < 0.0f)
                    {
                        gGLOldGamma = 0.0f;
                    }
                    else
                    {
                        if (gGLOldGamma >= 1.0f)
                        {
                            gGLOldGamma = 0.999f;
                        }
                    }
                    CGSetDisplayTransferByFormula (kCGDirectMainDisplay,
                                                   gGLOldGamma,
                                                   1.0f,
                                                   gGLOriginalGamma[2],
                                                   gGLOldGamma,
                                                   1.0f,
                                                   gGLOriginalGamma[5],
                                                   gGLOldGamma,
                                                   1.0f,
                                                   gGLOriginalGamma[8]);
                }
                gGLOldGamma = gGLGamma->value;
                gGLOldOverbrightGamma = gGLOverbrightGamma->value;
            }
        }
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	GLimp_EndFrame (void)
{
    if (gGLContext != NULL)
    {
        [gGLContext makeCurrentContext];
        [gGLContext flushBuffer];
    }
    
    if (gGLFullscreen == NO && [gGLWindow isMiniaturized])
	{
		UInt8 *	myBitmapBuffer = (UInt8 *) [gGLMiniWindowBuffer bitmapData];
		
		if (myBitmapBuffer != NULL)
		{
			UInt8 *	myBitmapBufferEnd = myBitmapBuffer + (vid.width << 2) * vid.height;

			// get the OpenGL buffer:
			qglReadPixels (0, 0, vid.width, vid.height, GL_RGBA, GL_UNSIGNED_BYTE, myBitmapBuffer);
			
			// set all alpha to 1.0. instead we could use "glPixelTransferf (GL_ALPHA_BIAS, 1.0f)", but it's slower!
			myBitmapBuffer += 3;
			
			while (myBitmapBuffer < myBitmapBufferEnd)
			{
				*myBitmapBuffer	= 0xFF;
				myBitmapBuffer	+= sizeof (UInt32);
			}

			// draw the Dock image:
			[gGLMiniWindow lockFocus];
			[gGLMiniWindowBuffer drawInRect: gGLMiniWindowRect];
			[gGLMiniWindow unlockFocus];
			[gGLWindow setMiniwindowImage: gGLMiniWindow];		
		}
    }

    GLimp_SetSwapInterval ();
    GLimp_SetAnisotropyTextureLevel ();
    GLimp_SetARBMultiSample ();
    GLimp_SetTruform ();
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

int 	GLimp_Init (void *hinstance, void *hWnd)
{
    CGDisplayErr	myError;

    // for controlling mouse and minimized window:
    gGLIsMinimized = ri.Cvar_Get ("_miniwindow", "0", 0);

    // initialize the miniwindow:
	gGLMiniWindowRect	= NSMakeRect (0.0f, 0.0f, 128.0f, 128.0f);
    gGLMiniWindow		= [[NSImage alloc] initWithSize: gGLMiniWindowRect.size];
	
	[gGLMiniWindow setFlipped: YES];
	
    // get the swap interval variable:
    gGLSwapInterval = ri.Cvar_Get ("gl_swapinterval", "1", 0);
    
    // get the video gamma variable:
    gGLGamma = ri.Cvar_Get ("vid_gamma", "0", 0);
    
    // get the variable for the aniostropic texture level:
    gGLTextureAnisotropyLevel = ri.Cvar_Get ("gl_anisotropic", "0", CVAR_ARCHIVE);

    // get the variable for the multisample level:
    gGLARBMultiSampleLevel = ri.Cvar_Get ("gl_arb_multisample", "0", CVAR_ARCHIVE);

    // get the variable for the truform tesselation level:
    gGLTrufomTesselationLevel = ri.Cvar_Get ("gl_truform", "-1", CVAR_ARCHIVE);
    
    // get the variable for overbright gamma:
    gGLOverbrightGamma = ri.Cvar_Get ("gl_overbright_gamma", "0", CVAR_ARCHIVE);
    
    // save the original display mode:
    gGLOriginalMode = CGDisplayCurrentMode (kCGDirectMainDisplay);

    // get the gamma:
    myError = CGGetDisplayTransferByFormula (kCGDirectMainDisplay,
                                             &gGLOriginalGamma[0],
                                             &gGLOriginalGamma[1],
                                             &gGLOriginalGamma[2],
                                             &gGLOriginalGamma[3],
                                             &gGLOriginalGamma[4],
                                             &gGLOriginalGamma[5],
                                             &gGLOriginalGamma[6],
                                             &gGLOriginalGamma[7],
                                             &gGLOriginalGamma[8]);
    
    if (myError == CGDisplayNoErr)
    {
        gGLCanSetGamma = YES;
    }
    else
    {
        gGLCanSetGamma = NO;
    }

    // get the gamma for non-overbright gamma:
    myError = CGGetDisplayTransferByTable (kCGDirectMainDisplay,
                                           CG_MAX_GAMMA_TABLE_SIZE,
                                           gGLOriginalGammaTable.red,
                                           gGLOriginalGammaTable.green,
                                           gGLOriginalGammaTable.blue,
                                           &gGLOriginalGammaTable.count);

    if (myError != CGDisplayNoErr)
    {
        gGLCanSetGamma = NO;
    }

    gGLOldGamma = 0.0f;
    gGLOldOverbrightGamma = 1.0f - gGLOverbrightGamma->value;
    
    return (true);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	GLimp_Shutdown (void)
{
    if (gGLMiniWindow != NULL)
    {
        [gGLMiniWindow release];
        gGLMiniWindow = NULL;
    }

	if (gGLMiniWindowBuffer != NULL)
	{
		[gGLMiniWindowBuffer release];
		gGLMiniWindowBuffer = NULL;
	}

    GLimp_DestroyContext ();

    // get the original display mode back:
    if (gGLOriginalMode)
    {
        CGDisplaySwitchToMode (kCGDirectMainDisplay, gGLOriginalMode);
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	GLimp_DestroyContext (void)
{
    // set variable states to modfied:
    gGLSwapInterval->modified = YES;
    gGLTextureAnisotropyLevel->modified = YES;
    gGLARBMultiSampleLevel->modified = YES;
    gGLTrufomTesselationLevel->modified = YES;

    // restore old gamma settings:
    if (gGLCanSetGamma == YES)
    {
            CGSetDisplayTransferByFormula (kCGDirectMainDisplay,
                                            gGLOriginalGamma[0],
                                            gGLOriginalGamma[1],
                                            gGLOriginalGamma[2],
                                            gGLOriginalGamma[3],
                                            gGLOriginalGamma[4],
                                            gGLOriginalGamma[5],
                                            gGLOriginalGamma[6],
                                            gGLOriginalGamma[7],
                                            gGLOriginalGamma[8]);
            gGLOldGamma = 0.0f;
    }

    // clean up the OpenGL context:
    if (gGLContext != NULL)
    {
        [gGLContext makeCurrentContext];
        [NSOpenGLContext clearCurrentContext];
        [gGLContext clearDrawable];
        [gGLContext release];
        gGLContext = NULL;
    }

    // close the old window:
    if (gGLWindow != NULL)
    {
        [gGLWindow close];
        gGLWindow = NULL;
    }
    
    // close the content view:
    if (gGLView != NULL)
    {
        [gGLView release];
        gGLView = NULL;
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

int     GLimp_SetMode (int *theWidth, int *theHeight, int theMode, qboolean theFullscreen)
{
    int			myWidth;
	int			myHeight;
    float		myNewRefreshRate = 0;
    cvar_t	*	myRefreshRate;
    
    ri.Con_Printf (PRINT_ALL, "Initializing OpenGL display\n");

    ri.Con_Printf (PRINT_ALL, "...setting mode %d:", theMode );

    if (!ri.Vid_GetModeInfo (&myWidth, &myHeight, theMode))
    {
        ri.Con_Printf (PRINT_ALL, " invalid mode\n");
        return (rserr_invalid_mode);
    }

    myRefreshRate = ri.Cvar_Get ("vid_refreshrate", "0", 0);
    if (myRefreshRate != NULL)
    {
        myNewRefreshRate = myRefreshRate->value;
    }

    ri.Con_Printf (PRINT_ALL, " %d x %d\n", myWidth, myHeight);
    
    GLimp_DestroyContext ();
    
    *theWidth = myWidth;
    *theHeight = myHeight;

    GLimp_InitGraphics (&myWidth, &myHeight, myNewRefreshRate, theFullscreen);

    ri.Vid_NewWindow (myWidth, myHeight);

    return (rserr_ok);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	GLimp_SetSwapInterval (void)
{
    // change the swap interval if the value changed:
    if (gGLSwapInterval == NULL)
    {
        return;
    }

    if (gGLSwapInterval->modified == YES)
    {
        long		myCurSwapInterval = (long) gGLSwapInterval->value;
        
        if (myCurSwapInterval > 1)
        {
            myCurSwapInterval = 1;
            ri.Cvar_SetValue ("gl_swapinterval", 1.0f);
        }
        else
        {
            if (myCurSwapInterval < 0)
            {
                myCurSwapInterval = 0;
                ri.Cvar_SetValue ("gl_swapinterval", 0.0f);
            }
        }
        [gGLContext makeCurrentContext];
        CGLSetParameter (CGLGetCurrentContext (), kCGLCPSwapInterval, &myCurSwapInterval);
        gGLSwapInterval->modified = NO;
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	GLimp_SetAnisotropyTextureLevel (void)
{
    extern GLfloat	qglMaxAnisotropyTextureLevel,
                        qglCurAnisotropyTextureLevel;
                        
    if (gGLTextureAnisotropyLevel == NULL || gGLTextureAnisotropyLevel->modified == NO)
    {
        return;
    }
    
    if (gGLTextureAnisotropyLevel->value == 0.0f)
    {
        qglCurAnisotropyTextureLevel = 1.0f;
    }
    else
    {
        qglCurAnisotropyTextureLevel = qglMaxAnisotropyTextureLevel;
    }

    gGLTextureAnisotropyLevel->modified = NO;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	GLimp_SetTruform (void)
{
    if (gGLTruformAvailable == NO ||
        gGLTrufomTesselationLevel == NULL ||
        gGLTrufomTesselationLevel->modified == NO)
    {
        return;
    }
    else
    {
        SInt32	myPNTriangleLevel = gGLTrufomTesselationLevel->value;

        if (myPNTriangleLevel >= 0)
        {
            if (myPNTriangleLevel > 7)
            {
                myPNTriangleLevel = 7;
                ri.Cvar_SetValue ("gl_truform", myPNTriangleLevel);
                ri.Con_Printf (PRINT_ALL, "Clamping to max. pntriangle level 7!\n");
                ri.Con_Printf (PRINT_ALL, "value < 0  : Disable Truform\n");
                ri.Con_Printf (PRINT_ALL, "value 0 - 7: Enable Truform with the specified tesselation level\n");
            }
            
            // enable pn_triangles. lightning required due to a bug of OpenGL!
            qglEnable (GL_PN_TRIANGLES_ATIX);
            qglEnable (GL_LIGHTING);
            qglLightModelfv (GL_LIGHT_MODEL_AMBIENT, gGLTruformAmbient);
            qglEnable (GL_COLOR_MATERIAL);
        
            // point mode:
            //qglPNTrianglesiATIX (GL_PN_TRIANGLES_POINT_MODE_ATIX, GL_PN_TRIANGLES_POINT_MODE_LINEAR_ATIX);
            qglPNTrianglesiATIX (GL_PN_TRIANGLES_POINT_MODE_ATIX, GL_PN_TRIANGLES_POINT_MODE_CUBIC_ATIX);
            
            // normal mode (no normals used at all by Quake):
            //qglPNTrianglesiATIX (GL_PN_TRIANGLES_NORMAL_MODE_ATIX, GL_PN_TRIANGLES_NORMAL_MODE_LINEAR_ATIX);
            qglPNTrianglesiATIX (GL_PN_TRIANGLES_NORMAL_MODE_ATIX, GL_PN_TRIANGLES_NORMAL_MODE_QUADRATIC_ATIX);
        
            // tesselation level:
            qglPNTrianglesiATIX (GL_PN_TRIANGLES_TESSELATION_LEVEL_ATIX, myPNTriangleLevel);
        }
        else
        {
            if (myPNTriangleLevel != -1)
            {
                myPNTriangleLevel = -1;
                ri.Cvar_SetValue ("gl_truform", myPNTriangleLevel);
            }
            qglDisable (GL_PN_TRIANGLES_ATIX);
            qglDisable (GL_LIGHTING);
        }
        gGLTrufomTesselationLevel->modified = NO;
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	GLimp_SetARBMultiSample (void)
{
    if (gGLARBMultiSampleLevel->modified == NO)
    {
        return;
    }

    if (gGLMaxARBMultiSampleBuffers <= 0)
    {
        ri.Con_Printf (PRINT_ALL, "No ARB_multisample extension available!\n");
        ri.Cvar_SetValue ("gl_arb_multisample", 0);
        gGLARBMultiSampleLevel->modified = NO;
    }
    else
    {
        float		mySampleLevel = gGLARBMultiSampleLevel->value;
        BOOL		myRestart = NO;
        
        if (gGLARBMultiSampleLevel->value != gGLCurARBMultiSamples)
        {
            if ((mySampleLevel == 0.0f ||
                 mySampleLevel == 4.0f ||
                 mySampleLevel == 8.0f ||
                 mySampleLevel == gGLMaxARBMultiSamples) &&
                mySampleLevel <= gGLMaxARBMultiSamples)
            {
                myRestart = YES;
            }
            else
            {
//                float	myOldValue;
//                
//                qglGetFloatv (GL_SAMPLES_ARB, &myOldValue);
//                ri.Cvar_SetValue ("gl_arb_multisample", myOldValue);
//                ri.Con_Printf (PRINT_ALL, "Invalid multisample level. Reverting to: %f.\n", myOldValue);
                //gGLARBMultiSampleLevel->value = gGLCurARBMultiSamples;
				ri.Cvar_SetValue ("gl_arb_multisample", gGLCurARBMultiSamples);
                ri.Con_Printf (PRINT_ALL, "Invalid multisample level. Reverting to: %d.\n", gGLCurARBMultiSamples);
            }
        }
        
        gGLARBMultiSampleLevel->modified = NO;
        
        if (myRestart == YES)
        {
            ri.Cmd_ExecuteText (EXEC_NOW, "vid_restart\n");
        }
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	GLimp_CheckForARBMultiSample (void)
{

    CGLRendererInfoObj			myRendererInfo;
    CGLError				myError;
    UInt64				myDisplayMask;
    long				myCount,
                                        myIndex,
                                        mySampleBuffers,
                                        mySamples;

    // reset out global values:
    gGLMaxARBMultiSampleBuffers = 0;
    gGLMaxARBMultiSamples = 0;
    
    // retrieve the renderer info for the main display:
    myDisplayMask = CGDisplayIDToOpenGLDisplayMask (kCGDirectMainDisplay);
    myError = CGLQueryRendererInfo (myDisplayMask, &myRendererInfo, &myCount);
    
    if (myError == kCGErrorSuccess)
    {
        // loop through all renderers:
        for (myIndex = 0; myIndex < myCount; myIndex++)
        {
            // check if the current renderer supports sample buffers:
            myError = CGLDescribeRenderer (myRendererInfo, myIndex, kCGLRPMaxSampleBuffers, &mySampleBuffers);
            if (myError == kCGErrorSuccess && mySampleBuffers > 0)
            {
                // retrieve the number of samples supported by the current renderer:
                myError = CGLDescribeRenderer (myRendererInfo, myIndex, kCGLRPMaxSamples, &mySamples);
                if (myError == kCGErrorSuccess && mySamples > gGLMaxARBMultiSamples)
                {
                    gGLMaxARBMultiSampleBuffers = mySampleBuffers;
                    
                    // The ATI Radeon/PCI drivers report a value of "4", but "8" is maximum...
                    gGLMaxARBMultiSamples = mySamples << 1;
                }
            }
        }
        
        // get rid of the renderer info:
        CGLDestroyRendererInfo (myRendererInfo);
    }
    
    // shouldn't happen, but who knows...
    if (gGLMaxARBMultiSamples <= 1)
    {
        gGLMaxARBMultiSampleBuffers = 0;
        gGLMaxARBMultiSamples = 0;
    }
    
    // because of the Radeon issue above...
    if (gGLMaxARBMultiSamples > 8)
    {
        gGLMaxARBMultiSamples = 8;
    }

//	gGLMaxARBMultiSamples = 8;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

NSOpenGLPixelFormat *	GLimp_CreateGLPixelFormat (int theDepth, Boolean theFullscreen)
{
    NSOpenGLPixelFormat			*myPixelFormat;
    NSOpenGLPixelFormatAttribute	myAttributeList[16];
    UInt8				i = 0;

    if (gGLMaxARBMultiSampleBuffers > 0 &&
        gGLARBMultiSampleLevel->value != 0 &&
        (gGLARBMultiSampleLevel->value == 4.0f ||
         gGLARBMultiSampleLevel->value == 8.0f ||
         gGLARBMultiSampleLevel->value == gGLMaxARBMultiSamples))
    {
        gGLCurARBMultiSamples = gGLARBMultiSampleLevel->value;
        myAttributeList[i++] = NSOpenGLPFASampleBuffers;
        myAttributeList[i++] = gGLMaxARBMultiSampleBuffers;
        myAttributeList[i++] = NSOpenGLPFASamples;
        myAttributeList[i++] = gGLCurARBMultiSamples;
    }
    else
    {
        gGLARBMultiSampleLevel->value = 0.0f;
        gGLCurARBMultiSamples = 0;
    }
    
    // are we running fullscreen or windowed?
    if (theFullscreen)
    {
        myAttributeList[i++] = NSOpenGLPFAFullScreen;
    }
    else
    {
        myAttributeList[i++] = NSOpenGLPFAWindow;
    }

    // choose the main display automatically:
    myAttributeList[i++] = NSOpenGLPFAScreenMask;
    myAttributeList[i++] = CGDisplayIDToOpenGLDisplayMask (kCGDirectMainDisplay);

    // we need a double buffered context:
    myAttributeList[i++] = NSOpenGLPFADoubleBuffer;

    // set the "accelerated" attribute only if we don't allow the software renderer!
    if ((ri.Cvar_Get ("gl_allow_software", "0", 0))->value == 0.0f)
    {
        myAttributeList[i++] = NSOpenGLPFAAccelerated;
    }
    
    myAttributeList[i++] = NSOpenGLPFAColorSize;
    myAttributeList[i++] = theDepth;

    myAttributeList[i++] = NSOpenGLPFADepthSize;
    myAttributeList[i++] =  1;

    myAttributeList[i++] = NSOpenGLPFANoRecovery;

    myAttributeList[i++] = 0;

    myPixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes: myAttributeList];

    return (myPixelFormat);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

Boolean	GLimp_InitGraphics (int *theWidth, int *theHeight, float theRefreshRate, Boolean theFullscreen)
{
    NSOpenGLPixelFormat	*	myPixelFormat = NULL;
    int						myDisplayDepth;

    if (theFullscreen)
    {
        CFDictionaryRef		myDisplayMode;
        boolean_t			myExactMatch;

        if (CGDisplayIsCaptured (kCGDirectMainDisplay) != true)
        {
            GL_CAPTURE_DISPLAYS();
        }
        
        // force 16bit OpenGL display?
        if ((ri.Cvar_Get ("gl_force16bit", "0", 0))->value != 0.0f)
        {
            myDisplayDepth = 16;
        }
        else
        {
            myDisplayDepth = 32;
        }
        
        // get the requested mode:
        if (theRefreshRate > 0)
        {
            myDisplayMode = CGDisplayBestModeForParametersAndRefreshRate (kCGDirectMainDisplay, myDisplayDepth,
                                                                          *theWidth, *theHeight, theRefreshRate,
                                                                          &myExactMatch);
        }
        else
        {
            myDisplayMode = CGDisplayBestModeForParameters (kCGDirectMainDisplay, myDisplayDepth, *theWidth,
                                                            *theHeight, &myExactMatch);
        }

        // got we an exact mode match? if not report the new resolution again:
        if (myExactMatch == NO)
        {
            *theWidth	= [[(NSDictionary *) myDisplayMode objectForKey: (NSString *) kCGDisplayWidth] intValue];
            *theHeight	= [[(NSDictionary *) myDisplayMode objectForKey: (NSString *) kCGDisplayHeight] intValue];
			
            ri.Con_Printf (PRINT_ALL, "can\'t switch to requested mode. using %d x %d.\n", *theWidth, *theHeight);
        }

        // switch to the new display mode:
        if (CGDisplaySwitchToMode (kCGDirectMainDisplay, myDisplayMode) != kCGErrorSuccess)
        {
            ri.Sys_Error (ERR_FATAL, "Can\'t switch to the selected mode!\n");
        }

        myDisplayDepth = [[(NSDictionary *) myDisplayMode objectForKey: (id) kCGDisplayBitsPerPixel] intValue];
    }
    else
    {
        if (gGLOriginalMode)
        {
            CGDisplaySwitchToMode (kCGDirectMainDisplay, gGLOriginalMode);
        }
    
        myDisplayDepth = [[(NSDictionary *)  gGLOriginalMode objectForKey: (id) kCGDisplayBitsPerPixel] intValue];
    }
    
    // check if we have access to sample buffers:
    GLimp_CheckForARBMultiSample ();
    
    // get the pixel format [the loop is just for sample buffer failures]:
    while (myPixelFormat == NULL)
    {
        if (gGLARBMultiSampleLevel->value < 0.0f)
            gGLARBMultiSampleLevel->value = 0.0f;

        if ((myPixelFormat = GLimp_CreateGLPixelFormat (myDisplayDepth, theFullscreen)) == NULL)
        {
            if (gGLARBMultiSampleLevel->value == 0.0f)
            {
                ri.Sys_Error (ERR_FATAL,"Unable to find a matching pixelformat. Please try other displaymode(s).");
            }
            gGLARBMultiSampleLevel->value -= 4.0;
        }
    }

    // initialize the OpenGL context:
    if (!(gGLContext = [[NSOpenGLContext alloc] initWithFormat: myPixelFormat shareContext: nil]))
    {
        ri.Sys_Error (ERR_FATAL, "Unable to create an OpenGL context. Please try other displaymode(s).");
    }

    // get rid of the pixel format:
    [myPixelFormat release];

    if (theFullscreen)
    {
        // attach the OpenGL context to fullscreen:
        if (CGLSetFullScreen ([gGLContext cglContext]) != CGDisplayNoErr)
        {
            ri.Sys_Error (ERR_FATAL, "Unable to use the selected displaymode for fullscreen OpenGL.");
        }
    }
    else
    {
        cvar_t *	myVidPosX		= ri.Cvar_Get ("vid_xpos", "0", 0);
        cvar_t *	myVidPosY		= ri.Cvar_Get ("vid_ypos", "0", 0);
        NSRect 		myContentRect	= NSMakeRect (myVidPosX->value, myVidPosY->value, *theWidth, *theHeight);
        
        // setup the window according to our settings:
        gGLWindow = [[NSWindow alloc] initWithContentRect: myContentRect
                                                styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask
                                                  backing: NSBackingStoreBuffered
                                                    defer: NO];

        if (gGLWindow == NULL)
        {
            ri.Sys_Error (ERR_FATAL, "Unable to create window!\n");
        }

        [gGLWindow setTitle: @"Quake II"];

        // setup the content view:
        myContentRect.origin.x		= myContentRect.origin.y = 0;
        myContentRect.size.width	= vid.width;
        myContentRect.size.height	= vid.height;
		
        gGLView = [[Quake2GLView alloc] initWithFrame: myContentRect];

        // setup the view for tracking the window location:
        [gGLWindow setDocumentEdited: YES];
		[gGLWindow setMinSize: [gGLWindow frame].size];
        [gGLWindow setShowsResizeIndicator: NO];
        [gGLWindow setBackgroundColor: [NSColor blackColor]];
        [gGLWindow useOptimizedDrawing: NO];
        [gGLWindow setContentView: gGLView];
        [gGLWindow makeFirstResponder: gGLView];
        [gGLWindow setDelegate: gGLView];

        // attach the OpenGL context to the window:
        [gGLContext setView: [gGLWindow contentView]];
        
        // finally show the window:
        [NSApp activateIgnoringOtherApps: YES];
        [gGLWindow display];        
        [gGLWindow flushWindow];
        [gGLWindow setAcceptsMouseMovedEvents: YES];
        
        if (CGDisplayIsCaptured (kCGDirectMainDisplay) == true)
        {
            GL_RELEASE_DISPLAYS ();
        }

        [gGLWindow makeKeyAndOrderFront: nil];
        [gGLWindow makeMainWindow];
    }
    
    // Lock the OpenGL context to the refresh rate of the display [for clean rendering], if desired:
    [gGLContext makeCurrentContext];

    // set the buffers for the mini window [if buffer is available, will be checked later]:
	GLimp_SetMiniWindowBuffer();

    // last clean up:
    vid.width		= *theWidth;
    vid.height		= *theHeight;
    gGLFullscreen	= theFullscreen;

    return (true);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	GLimp_AppActivate (qboolean active)
{
    // not required!
}

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@implementation NSOpenGLContext (CGLContextAccess)

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (CGLContextObj) cglContext;
{
    return (_contextAuxiliary);
}

@end

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@implementation Quake2GLView

//------------------------------------------------------------------------------------------------------------------------------------------------------------

-(BOOL) acceptsFirstResponder
{
    return (YES);
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

- (void)windowDidMove: (NSNotification *)note
{
    NSRect	myRect = [gGLWindow frame];
	
    ri.Cmd_ExecuteText (EXEC_NOW, va ("vid_xpos %i", (int) myRect.origin.x + 1));
    ri.Cmd_ExecuteText (EXEC_NOW, va ("vid_ypos %i", (int) myRect.origin.y + 1));
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) windowWillMiniaturize: (NSNotification *) theNotification
{
    GLimp_SetMiniWindowBuffer ();
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) windowDidMiniaturize: (NSNotification *) theNotification
{
	if (gGLIsMinimized)
	{
		gGLIsMinimized->value = 1.0f;
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) windowDidDeminiaturize: (NSNotification *) theNotification
{
	if (gGLIsMinimized)
	{
		gGLIsMinimized->value = 0.0f;
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

    theProposedFrameSize.width	+= myBorderSize.width;
    theProposedFrameSize.height	+= myBorderSize.height;

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
    // required for resizing and deminiaturizing:
    if (gGLContext != NULL)
    {
        [gGLContext update];
    }
}

@end

//------------------------------------------------------------------------------------------------------------------------------------------------------------
