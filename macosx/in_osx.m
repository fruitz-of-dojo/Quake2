//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "in_osx.c" - MacOS X mouse input functions.
//
// Written by:	awe				            [mailto:awe@fruitz-of-dojo.de].
//		        ©2001-2006 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
// Quake IIª is copyrighted by id software	[http://www.idsoftware.com].
//
// Version History:
// v1.0.8: F12 eject is now disabled while Quake II is running and if a key is bound to F12.
// v1.0.2: MouseScaling is now disabled and enabled via IOKit.
//         Fixed an issue with mousepointer visibilty.
// v1.0.0: Initial release.
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#import <AppKit/AppKit.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/hidsystem/IOHIDLib.h>
#import <IOKit/hidsystem/IOHIDParameter.h>

#include <AvailabilityMacros.h>

#if (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4)
#include <IOKit/hidsystem/event_status_driver.h>
#else
#include <drivers/event_status_driver.h>
#endif

#include "in_osx.h"
#include "client.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Variables

extern cvar_t *			gSysIsMinimized;
extern cvar_t *			vid_fullscreen;
extern cvar_t *			_windowed_mouse;

cvar_t *				in_joystick;
cvar_t *				in_mouse;
                        
static BOOL				gInMLooking = NO;
static cvar_t*			m_filter;
static cvar_t *			gInSensitivity;
cvar_t *				lookstrafe;
cvar_t *				m_side;
cvar_t *				m_yaw;
cvar_t *				m_pitch;
cvar_t *				m_forward;
cvar_t *				freelook;
static CGMouseDelta		gInMouseX;
static CGMouseDelta		gInMouseY;
static CGMouseDelta		gInMouseNewX;
static CGMouseDelta		gInMouseNewY;
static CGMouseDelta		gInMouseOldX;
static CGMouseDelta		gInMouseOldY;

UInt8					gInSpecialKey[] =	{
													K_UPARROW, K_DOWNARROW,    K_LEFTARROW,  K_RIGHTARROW,
														 K_F1,        K_F2,           K_F3,          K_F4,
														 K_F5,        K_F6,           K_F7,          K_F8,
														 K_F9,       K_F10,          K_F11,         K_F12,
														K_F13,       K_F14,          K_F15,             0,
															0,   	     0, 	         0, 	        0,
															0, 		     0, 	         0, 	        0,
															0, 		     0, 	         0, 	        0,
															0, 		     0, 	         0, 	        0,
															0, 	 	     0, 	         0,         K_INS,
														K_DEL, 	    K_HOME, 	         0, 	    K_END,
													   K_PGUP,      K_PGDN,	             0,	            0,
													  K_PAUSE,		     0,	             0,	            0,
															0,		     0,	             0,	            0,
															0, 	 K_NUMLOCK, 	         0, 	        0,
															0, 		     0, 	         0, 	        0,
															0, 		     0, 	         0, 	        0,
															0, 		     0, 	     K_INS, 	        0
											};

UInt8					gInNumPadKey[] =	{	
															0,	          0,	          0, 	        0,
															0,	          0,	          0, 	        0,
															0,	          0,	          0, 	        0,
															0,	          0,	          0, 	        0,
															0,	          0,	          0, 	        0,
															0,	          0,	          0, 	        0,
															0,	          0,	          0, 	        0,
															0,	          0,	          0, 	        0,
															0,	          0,	          0, 	        0,
															0,	          0,	          0, 	        0,
															0,	          0,	          0, 	        0,
															0,	          0,	          0, 	        0,
															0,	          0,	          0, 	        0,
															0,	          0,	          0, 	        0,
															0,	          0,	          0, 	        0,
															0,	          0,	          0, 	        0,
															0,     K_KP_DEL,	          0,    K_KP_MULT,
															0,    K_KP_PLUS,			  0,	        0,
															0,			  0,			  0,	        0,
												   K_KP_ENTER,   K_KP_SLASH,     K_KP_MINUS,			0,
															0,   K_KP_EQUAL,       K_KP_INS, 	 K_KP_END,
											   K_KP_DOWNARROW,    K_KP_PGDN, K_KP_LEFTARROW, 	   K_KP_5,
											  K_KP_RIGHTARROW,    K_KP_HOME,              0, K_KP_UPARROW,
													K_KP_PGUP,	   	      0,	          0,            0
											};
								
#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Function Prototypes

void			IN_SetKeyboardRepeatEnabled (BOOL theState);
void			IN_SetF12EjectEnabled (qboolean theState);
void			IN_ShowCursor (BOOL theState);
void			IN_CenterCursor (void);
void			IN_ReceiveMouseMove (CGMouseDelta theDeltaX, CGMouseDelta theDeltaY);

static void		IN_SetMouseScalingEnabled (BOOL theState);
static void 	IN_MLookDown_f (void);
static void 	IN_MLookUp_f (void);

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

io_connect_t IN_GetIOHandle (void)
{
    mach_port_t		myMasterPort;
    io_connect_t 	myHandle = MACH_PORT_NULL;
	kern_return_t	myStatus = IOMasterPort (MACH_PORT_NULL, &myMasterPort );

    if (myStatus == KERN_SUCCESS)
	{
		io_service_t	myService = IORegistryEntryFromPath (myMasterPort, kIOServicePlane ":/IOResources/IOHIDSystem");
	
		if (myService != MACH_PORT_NULL)
		{
			myStatus = IOServiceOpen (myService, mach_task_self (), kIOHIDParamConnectType, &myHandle);
			
			IOObjectRelease (myService);
		}
	}
	
    return (myHandle);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_SetKeyboardRepeatEnabled (BOOL theState)
{
    static BOOL		myKeyboardRepeatEnabled = YES;
    static double	myOriginalKeyboardRepeatInterval;
    static double	myOriginalKeyboardRepeatThreshold;
    NXEventHandle	myEventStatus;
    
    if (theState == myKeyboardRepeatEnabled)
        return;
		
    if (!(myEventStatus = NXOpenEventStatus ()))
        return;
        
    if (theState == YES)
    {
        NXSetKeyRepeatInterval (myEventStatus, myOriginalKeyboardRepeatInterval);
        NXSetKeyRepeatThreshold (myEventStatus, myOriginalKeyboardRepeatThreshold);
        NXResetKeyboard (myEventStatus);
    }
    else
    {
        myOriginalKeyboardRepeatInterval = NXKeyRepeatInterval (myEventStatus);
        myOriginalKeyboardRepeatThreshold = NXKeyRepeatThreshold (myEventStatus);
        NXSetKeyRepeatInterval (myEventStatus, 3456000.0f);
        NXSetKeyRepeatThreshold (myEventStatus, 3456000.0f);
    }
    
    NXCloseEventStatus (myEventStatus);
    myKeyboardRepeatEnabled = theState;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_SetF12EjectEnabled (qboolean theState)
{
    static BOOL		myF12KeyIsEnabled = YES;
    static UInt32	myOldValue;
    io_connect_t	myIOHandle = MACH_PORT_NULL;
    
    // Do we have a state change?
    if (theState == myF12KeyIsEnabled)
    {
        return;
    }

    // Get the IOKit handle:
    myIOHandle = IN_GetIOHandle ();
	
    if (myIOHandle == MACH_PORT_NULL)
    {
        return;
    }

    // Set the F12 key according to the current state:
    if (theState == NO && keybindings[K_F12] != NULL && keybindings[K_F12][0] != 0x00)
    {
        UInt32		myValue = 0x00;
        IOByteCount	myCount;
        kern_return_t	myStatus;
        
        myStatus = IOHIDGetParameter (myIOHandle,
                                      CFSTR (kIOHIDF12EjectDelayKey),
                                      sizeof (UInt32),
                                      &myOldValue,
                                      &myCount);

        // change only the settings, if we were successfull!
        if (myStatus != kIOReturnSuccess)
        {
            theState = YES;
        }
        else
        {
            IOHIDSetParameter (myIOHandle, CFSTR (kIOHIDF12EjectDelayKey), &myValue, sizeof (UInt32));
        }
    }
    else
    {
        if (myF12KeyIsEnabled == NO)
        {
            IOHIDSetParameter (myIOHandle, CFSTR (kIOHIDF12EjectDelayKey),  &myOldValue, sizeof (UInt32));
        }
        theState = YES;
    }
    
    myF12KeyIsEnabled = theState;
    IOServiceClose (myIOHandle);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_SetMouseScalingEnabled (BOOL theState)
{
    static BOOL		myMouseScalingEnabled = YES;
    static double	myOldAcceleration = 0.0;
    io_connect_t	myIOHandle = MACH_PORT_NULL;

    // Do we have a state change?
    if (theState == myMouseScalingEnabled)
    {
        return;
    }
    
    // Get the IOKit handle:
    myIOHandle = IN_GetIOHandle ();
    if (myIOHandle == MACH_PORT_NULL)
    {
        return;
    }

    // Set the mouse acceleration according to the current state:
    if (theState == YES)
    {
        IOHIDSetAccelerationWithKey (myIOHandle,  CFSTR (kIOHIDMouseAccelerationType), myOldAcceleration);
    }
    else
    {
        kern_return_t	myStatus;

        myStatus = IOHIDGetAccelerationWithKey (myIOHandle, CFSTR (kIOHIDMouseAccelerationType),
                                                &myOldAcceleration);

        // change only the settings, if we were successfull!
        if (myStatus != kIOReturnSuccess || myOldAcceleration == 0.0)
        {
            theState = YES;
        }
        
        // change only the settings, if we were successfull!
        if (myStatus != kIOReturnSuccess)
        {
            theState = YES;
        }
        
        // finally disable the acceleration:
        if (theState == NO)
        {
            IOHIDSetAccelerationWithKey (myIOHandle,  CFSTR (kIOHIDMouseAccelerationType), -1.0);
        }
    }
    
    myMouseScalingEnabled = theState;
    IOServiceClose (myIOHandle);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_ShowCursor (BOOL theState)
{
    static BOOL		myCursorIsVisible = YES;

    // change only if we got a state change:
    if (theState != myCursorIsVisible)
    {
        if (theState == YES)
        {
            CGAssociateMouseAndMouseCursorPosition (YES);
            IN_CenterCursor ();
            IN_SetMouseScalingEnabled (YES);
            CGDisplayShowCursor (kCGDirectMainDisplay);
        }
        else
        {
            [NSApp activateIgnoringOtherApps: YES];
            CGDisplayHideCursor (kCGDirectMainDisplay);
            CGAssociateMouseAndMouseCursorPosition (NO);
            IN_CenterCursor ();
            IN_SetMouseScalingEnabled (NO);
        }
        myCursorIsVisible = theState;
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_CenterCursor (void)
{
    CGPoint		myCenter;

    if (vid_fullscreen != NULL && vid_fullscreen->value == 0.0f)
    {
        extern cvar_t	*vid_xpos, *vid_ypos;

        float		myCenterX, myCenterY;

        // get the window position:
        if (vid_xpos != NULL)
        {
            myCenterX = vid_xpos->value;
        }
        else
        {
            myCenterX = 0.0f;
        }

        if (vid_ypos != NULL)
        {
            myCenterY = -vid_ypos->value;
        }
        else
        {
            myCenterY = 0.0f;
        }
        
        // calculate the window center:
        myCenterX += (float) (viddef.width >> 1);
        myCenterY += (float) CGDisplayPixelsHigh (kCGDirectMainDisplay) - (float) (viddef.height >> 1);
        
        myCenter = CGPointMake (myCenterX, myCenterY);
    }
    else
    {
        // just center at the middle of the screen:
        myCenter = CGPointMake ((float) (viddef.width >> 1), (float) (viddef.height >> 1));
    }

    // and go:
    CGDisplayMoveCursorToPoint (kCGDirectMainDisplay, myCenter);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_Init (void)
{
    m_filter		= Cvar_Get ("m_filter", "0", 0);
    in_mouse		= Cvar_Get ("in_mouse", "1", CVAR_ARCHIVE);
    in_joystick		= Cvar_Get ("in_joystick", "0", CVAR_ARCHIVE);
    freelook		= Cvar_Get( "freelook", "0", 0 );
    lookstrafe		= Cvar_Get ("lookstrafe", "0", 0);
    gInSensitivity	= Cvar_Get ("sensitivity", "3", 0);
    m_pitch			= Cvar_Get ("m_pitch", "0.022", 0);
    m_yaw			= Cvar_Get ("m_yaw", "0.022", 0);
    m_forward		= Cvar_Get ("m_forward", "1", 0);
    m_side			= Cvar_Get ("m_side", "0.8", 0);

    Cmd_AddCommand ("+mlook", IN_MLookDown_f);
    Cmd_AddCommand ("-mlook", IN_MLookUp_f);

//    IN_SetMouseScalingEnabled (NO);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_Shutdown (void)
{
//    IN_SetMouseScalingEnabled (YES);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_MLookDown_f (void) 
{ 
    gInMLooking = true; 
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_MLookUp_f (void) 
{
    gInMLooking = false;
    IN_CenterView ();
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_Frame (void)
{
    // set the cursor visibility by respecting the display mode:
    if (vid_fullscreen != NULL && vid_fullscreen->value == 1.0f)
    {
        IN_ShowCursor (NO);
    }
    else
    {
        // is the mouse in windowed mode?
        if ([NSApp isActive] == YES && gSysIsMinimized->value == 0.0f && in_mouse->value != 0.0f &&
            _windowed_mouse != NULL && _windowed_mouse->value != 0.0f)
        {
            IN_ShowCursor (NO);
        }
        else
        {
            IN_ShowCursor (YES);
        }
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_ReceiveMouseMove (CGMouseDelta theDeltaX, CGMouseDelta theDeltaY)
{
    gInMouseNewX = theDeltaX;
    gInMouseNewY = theDeltaY;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_Move (usercmd_t *cmd)
{
    CGMouseDelta	myMouseX = gInMouseNewX, myMouseY = gInMouseNewY;

    if ((vid_fullscreen != NULL && vid_fullscreen->value == 0.0f &&
         (_windowed_mouse == NULL || (_windowed_mouse != NULL && _windowed_mouse->value == 0.0f))) ||
        in_mouse->value == 0.0f || [NSApp isActive] == NO || gSysIsMinimized->value != 0.0f)
    {
        return;
    }

    gInMouseNewX = 0;
    gInMouseNewY = 0;

    if (m_filter->value != 0.0f)
    {
        gInMouseX = (myMouseX + gInMouseOldX) >> 1;
        gInMouseY = (myMouseY + gInMouseOldY) >> 1;
    }
    else
    {
        gInMouseX = myMouseX;
        gInMouseY = myMouseY;
    }

    gInMouseOldX = myMouseX;
    gInMouseOldY = myMouseY;

    gInMouseX *= gInSensitivity->value;
    gInMouseY *= gInSensitivity->value;

    if ((in_strafe.state & 1) || (lookstrafe->value && gInMLooking))
    {
        cmd->sidemove += m_side->value * gInMouseX;
    }
    else
    {
        cl.viewangles[YAW] -= m_yaw->value * gInMouseX;
    }

    if ((gInMLooking || freelook->value) && !(in_strafe.state & 1))
    {
        cl.viewangles[PITCH] += m_pitch->value * gInMouseY;
    }
    else
    {
        cmd->forwardmove -= m_forward->value * gInMouseY;
    }

    // force the mouse to the center, so there's room to move:
    if (myMouseX != 0 || myMouseY != 0)
    {
        IN_CenterCursor ();
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_Commands (void)
{
    // already handled in "sys_osx.m"!
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_Activate (qboolean active)
{
    // not required!
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_ActivateMouse (void)
{
    // not required!
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	IN_DeactivateMouse (void)
{
    // not required!
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------
