//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "sys_osx.c" - MacOS X system functions.
//
// Written by:	awe                         [mailto:awe@fruitz-of-dojo.de].
//              ©2001-2006 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
// Quake IIª is copyrighted by id software	[http://www.idsoftware.com].
//
// Version History:
// v1.0.8: ¥ Mission packs can now be dragged onto the application icon even if Quake II is already running.
//	       ¥ Added startup dialog for command-line parameters.
//	       ¥ Added support for AppleScript.
//	       ¥ Added multi-threaded media-scan window.
// v1.0.6: ¥ Removed underscore from symbol name parameter at call to "dlsym ()" [because of new "dlopen.c"].
//	       ¥ Fixed disabled mouse after CMD-TABing.
//	       ¥ Added command "sys_hide" for mapping CMD_TAB to other keys.
// v1.0.5: ¥ Improved keyboard handling.
//         ¥ If application is installed inside the same folder as the baseq2 folder, the baseq2 folder will be
//           selected automagically.
// v1.0.4: ¥ Fixed invisible cursor on "baseq2" folder selection dialog.
// v1.0.3: ¥ Fixed a keyboard handling issue, introduced with the keypad support.
// v1.0.2: ¥ Fixed "Keyboard repeat" issue after application quit.
//         ¥ Mousewheel support should finally work.
//         ¥ Added support for up to 5 mousebuttons [K_JOY1 & K_JOY2 are used for binding button 4 and 5].
//	       ¥ Paste works now via CMD-V instead of CTRL-V [beside of SHIFT-INSERT] and the "Edit" menu.
//         ¥ Added "Connect To Server" service.
//	       ¥ Added support for CMD-TAB, CMD-H, CMD-M and CMD-Q [CMD-M only in windowed mode].
// v1.0.0: ¥ Initial release.
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#import <Cocoa/Cocoa.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <dirent.h>
#include <unistd.h>
#include <errno.h>
#include <ctype.h>
#include <dlfcn.h>
#include <fcntl.h>

#import "Quake2.h"
#import "Quake2Application.h"

#include "sys_osx.h"
#include "in_osx.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Variables

unsigned int			sys_frame_time;

qboolean				stdin_active		= YES;
cvar_t *				gSysNoStdOut		= NULL;
static void *			gSysGameLibrary		= NULL;
int						gSysArgCount		= 0;
char **					gSysArgValues		= NULL;

#ifndef DEDICATED_ONLY

cvar_t *				gSysIsMinimized		= NULL;
static int				gSysMsgTime			= 0;
static BOOL				gSysHostInitialized	= NO;
static char	*			gSysCDPath[]		=	{
                                                    "/Volumes/QUAKE2/install/data",
                                                    "/Volumes/Quake2/install/data",
                                                    "/Volumes/QUAKE2/Quake2InstallData",
                                                    NULL
                                                };



#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Function Prototypes

extern	void	M_Menu_Quit_f (void);
extern	void	Key_Event (int key, qboolean down, unsigned time);
extern	void	IN_SetKeyboardRepeatEnabled (BOOL theState);
extern	void	IN_SetF12EjectEnabled (qboolean theState);
extern	void	IN_ShowCursor (BOOL theState);
extern	void	IN_ReceiveMouseMove (CGMouseDelta theDeltaX, CGMouseDelta theDeltaY);
extern  BOOL	CDAudio_GetTrackList (void);
extern	void	CDAudio_Enable (BOOL theState);
extern qboolean	SNDDMA_ReserveBufferSize (void);
extern	void	VID_SetPaused (BOOL theState);

int				Sys_CheckSpecialKeys (int theKey);
void			Sys_Sleep (void);

static	void	Sys_HideApplication_f (void);

#endif /* !DEDICATED_ONLY */

static	BOOL	Sys_OpenGameAPI (const char *theGameName, char *thePath, char *theCurPath);

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	Sys_Error (char *theError, ...)
{
    va_list     myArgPtr;
    char        myString[SYS_STRING_SIZE];

    fcntl (0, F_SETFL, fcntl (0, F_GETFL, 0) & ~FNDELAY);
    
    va_start (myArgPtr, theError);
    vsnprintf (myString, SYS_STRING_SIZE, theError, myArgPtr);
    va_end (myArgPtr);

#ifdef DEDICATED_ONLY

    fprintf (stderr, "Error: %s\n", myString);
    
    exit (1);

#else

    NSLog (@"An error has occured: %@\n", [NSString stringWithCString: myString]);

    CL_Shutdown ();
    Qcommon_Shutdown ();
    gSysHostInitialized = NO;

    IN_SetKeyboardRepeatEnabled (YES);
    IN_SetF12EjectEnabled (YES);
    
    NSRunCriticalAlertPanel (@"An error has occured:", [NSString stringWithCString: myString],
                             NULL, NULL, NULL);
    
    exit (1);

#endif /* DEDICATED_ONLY */
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void Sys_Quit (void)
{
    CL_Shutdown ();
    Qcommon_Shutdown ();

#ifndef DEDICATED_ONLY

    gSysHostInitialized = NO;

    IN_SetKeyboardRepeatEnabled (YES);
    IN_SetF12EjectEnabled (YES);
    
#endif /* DEDICATED_ONLY */

    exit (0);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	Sys_UnloadGame (void)
{
    if (gSysGameLibrary != NULL) 
    {
        dlclose (gSysGameLibrary);
    }
	
    gSysGameLibrary = NULL;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

BOOL	Sys_OpenGameAPI (const char *theGameName, char *thePath, char *theCurPath)
{
    char	myName[MAXPATHLEN];
    
    snprintf (myName, MAXPATHLEN, "%s/%s/%s", theCurPath, thePath, theGameName);
    Com_Printf ("Trying to load library (%s)\n", myName);

    gSysGameLibrary = dlopen (myName, RTLD_NOW );
	
    if (gSysGameLibrary != NULL)
    {
        Com_DPrintf ("LoadLibrary (%s)\n", myName);
        return (YES);
    }

    return (NO);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void *	Sys_GetGameAPI (void *theParameters)
{
    void *	(*myGameAPI) (void *);
    char	myCurPath[MAXPATHLEN];
    char	*myPath;

    if (gSysGameLibrary != NULL)
    {
        Com_Error (ERR_FATAL, "Sys_GetGameAPI without Sys_UnloadingGame");
    }

    getcwd (myCurPath, sizeof (myCurPath));

    Com_Printf ("------ Loading GameMac.q2plug ------\n");

    // now run through the search paths
    myPath = NULL;
    while (1)
    {
        myPath = FS_NextPath (myPath);
		
        if (myPath == NULL)
            return (NULL);
        
        
        if (Sys_OpenGameAPI ("GameMac.q2plug/Contents/MacOS/GameMac", myPath, myCurPath) == YES)
            break;
			
#ifdef __ppc__

		// try deprecated plug-ins:
		
        if (Sys_OpenGameAPI ("GamePPC.q2plug/Contents/MacOS/GamePPC", myPath, myCurPath) == YES)
            break;

        if (Sys_OpenGameAPI ("GamePPC.bundle/Contents/MacOS/GamePPC", myPath, myCurPath) == YES)
            break;
			
#endif // __ppc__
   }

    myGameAPI = (void *) dlsym (gSysGameLibrary, "GetGameAPI");
	
    if (myGameAPI == NULL)
    {
        Sys_UnloadGame ();		
        return (NULL);
    }

    return (myGameAPI (theParameters));
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

char *Sys_ConsoleInput (void)
{
    static char 	myText[256];
    int     		myLength;
    fd_set			myFDSet;
    struct timeval	myTimeOut;
    
    if (!dedicated || !dedicated->value)
    {
        return NULL;
    }
    
    if (!stdin_active)
    {
        return NULL;
    }
    
    FD_ZERO (&myFDSet);
    FD_SET (0, &myFDSet);
    myTimeOut.tv_sec = 0;
    myTimeOut.tv_usec = 0;
    if (select (1, &myFDSet, NULL, NULL, &myTimeOut) == -1 || !FD_ISSET (0, &myFDSet))
    {
        return (NULL);
    }
    
    myLength = read (0, myText, sizeof (myText));
    if (myLength == 0)
    {
        stdin_active = false;
        return (NULL);
    }
    
    if (myLength < 1)
    {
        return (NULL);
    }
    myText[myLength - 1] = 0x00;
    
    return (myText);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	Sys_ConsoleOutput (char *theString)
{
#ifdef DEDICATED_ONLY

    unsigned char	*myChar;
    
    if (theString == NULL)
    {
        return;
    }
    
    if (gSysNoStdOut != NULL && gSysNoStdOut->value != 0.0)
    {
        return;
    }
    
    for (myChar = (unsigned char *) theString; *myChar != 0x00; myChar++)
    {
        *myChar &= 0x7f;
        if ((*myChar > 128 || *myChar < 32) && *myChar != 10 && *myChar != 13 && *myChar != 9)
        {
            fprintf (stdout, "[%02x]", *myChar);
        }
        else
        {
            putc (*myChar, stdout);
        }
    }
    
    fflush (stdout);

#else

    return;

#endif /* DEDICATED_ONLY */
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void Sys_SendKeyEvents (void)
{
    sys_frame_time = Sys_Milliseconds ();
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void Sys_AppActivate (void)
{
    // not used!
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void Sys_CopyProtect (void)
{
    // check for the CD here!
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	Sys_Init (void)
{
#ifndef DEDICATED_ONLY

    gSysIsMinimized = Cvar_Get ("_miniwindow", "0", 0);
    Cmd_AddCommand ("sys_hide", Sys_HideApplication_f);

#endif /* !DEDICATED_ONLY */
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#ifndef DEDICATED_ONLY

char *	Sys_GetClipboardData (void)
{
    NSPasteboard	*myPasteboard = NULL;
    NSArray 		*myPasteboardTypes = NULL;

    myPasteboard = [NSPasteboard generalPasteboard];
    myPasteboardTypes = [myPasteboard types];
    if ([myPasteboardTypes containsObject: NSStringPboardType])
    {
        NSString	*myClipboardString;

        myClipboardString = [myPasteboard stringForType: NSStringPboardType];
        if (myClipboardString != NULL && [myClipboardString length] > 0)
        {
            return (strdup ([myClipboardString cString]));
        }
    }
    return (NULL);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	Sys_HideApplication_f (void)
{
    extern qboolean	keydown[];
    
    keydown[K_COMMAND] = NO;
    keydown[K_TAB] = NO;
    keydown['H'] = NO;

    [NSApp hide: NULL];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

int	Sys_CheckSpecialKeys (int theKey)
{
    extern cvar_t *		vid_fullscreen;
    extern qboolean		keydown[];
    int					myKey;

    // do a fast evaluation:
    if (keydown[K_COMMAND] == false)
    {
        return (0);
    }
    
    myKey = toupper (theKey);
    
    // check the keys:
    switch (myKey)
    {
        case K_TAB:
        case 'H':
            // CMD-TAB is handled by the system if windowed:
            if (myKey == 'H' || (vid_fullscreen != NULL && vid_fullscreen->value != 0.0f))
            {
                Sys_HideApplication_f ();
                
                return (1);
            }
            break;
        case 'M':
            // minimize window [CMD-M]:
            if (vid_fullscreen != NULL && vid_fullscreen->value == 0.0f)
            {
                NSWindow *	myWindow = [NSApp keyWindow];
				
                if (myWindow != NULL && [myWindow isMiniaturized] == NO)
                {
                    [myWindow miniaturize: NULL];
                }
    
                return (1);
            }
            break;
        case 'Q':
            // application quit [CMD-Q]:
            M_Menu_Quit_f ();

            return (1);
        case '?':
            if (vid_fullscreen != NULL && vid_fullscreen->value == 0.0f)
            {
                [NSApp showHelp: NULL];
                
                return (1);
            }
            break;
    }

    // paste [CMD-V] already checked inside "keys.c"!
    return (0);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void 	Sys_CheckForCDDirectory (void)
{
    UInt8	i;
    NSString	*myCurrentPath;
    char	**myNewArgValues,
                *myCDPath = NULL;
    
    // cd command already issued?
    if (gSysArgCount >= 4)
    {
        for (i = 0; i < gSysArgCount - 2; i++)
        {
            if (strcmp (gSysArgValues[i], SYS_SET_COMMAND) == 0 && strcmp (gSysArgValues[i + 1], SYS_CDDIR_COMMAND) == 0)
            {
                return;
            }
        }
    }
    
    // is the cd mounted?
    for (i = 0; gSysCDPath[i] != NULL; i++)
    {
        myCurrentPath = [[NSString stringWithCString: gSysCDPath[i]] stringByAppendingString: @"/baseq2/pak0.pak"];
        
		if ([[NSFileManager defaultManager] fileExistsAtPath: myCurrentPath])
        {
            myCDPath = gSysCDPath[i];
            break;    
        }
    }
    if (myCDPath == NULL)
    {
        return;
    }
    
    // insert "+set cddir path" to the command line:
    gSysArgCount += 3;
    myNewArgValues = malloc (sizeof(char *) * gSysArgCount);
    SYS_CHECK_MALLOC (myNewArgValues);
    for (i = 0; i < gSysArgCount - 3; i++)
    {
        myNewArgValues[i] = gSysArgValues[i];
    }
    gSysArgValues = myNewArgValues;
    gSysArgValues[i++] = SYS_SET_COMMAND;
    gSysArgValues[i++] = SYS_CDDIR_COMMAND;
    gSysArgValues[i] = SYS_CD_PATH;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	Sys_CheckForIDDirectory (void)
{
    char *				myBaseDir		= NULL;
    BOOL				myFirstRun		= YES;
	BOOL				myDefaultPath	= YES;
	BOOL				myPathChanged	= NO;
	BOOL				myFileExists	= NO;
    NSString *			myValidatePath	= nil;
    NSUserDefaults *	myDefaults		= [NSUserDefaults standardUserDefaults];
	NSString *			myBasePath		= [myDefaults stringForKey: SYS_DEFAULT_BASE_PATH];
    NSArray	*			myFolder;
    SInt				myResult;
	SInt				myPathLength;

    while (1)
    {
        if (myBasePath)
        {
			// get a POSIX version of the path:
			myBaseDir		= (char *) [myBasePath fileSystemRepresentation];
			myPathLength	= strlen (myBaseDir);
			
			// check if the last component was "baseq2":
			if (myPathLength >= 6)
			{
				if ((myBaseDir[myPathLength - 6] == 'b' || myBaseDir[myPathLength - 6] == 'B') &&
					(myBaseDir[myPathLength - 5] == 'a' || myBaseDir[myPathLength - 5] == 'A') &&
					(myBaseDir[myPathLength - 4] == 's' || myBaseDir[myPathLength - 4] == 'S') &&
					(myBaseDir[myPathLength - 3] == 'e' || myBaseDir[myPathLength - 3] == 'E') &&
					(myBaseDir[myPathLength - 2] == 'q' || myBaseDir[myPathLength - 2] == 'Q') &&
					 myBaseDir[myPathLength - 1] == '2')
				{
					// check if the game plug-in exists:
					myValidatePath	= [myBasePath stringByAppendingPathComponent: SYS_VALIDATION_FILE1];
					myFileExists	= [[NSFileManager defaultManager] fileExistsAtPath: myValidatePath];
		
#ifdef __ppc__

					if (myFileExists == NO)
					{
						myValidatePath = [myBasePath stringByAppendingPathComponent: SYS_VALIDATION_FILE2];
						myFileExists = [[NSFileManager defaultManager] fileExistsAtPath: myValidatePath];
					}

					if (myFileExists == NO)
					{
						myValidatePath = [myBasePath stringByAppendingPathComponent: SYS_VALIDATION_FILE3];
						myFileExists = [[NSFileManager defaultManager] fileExistsAtPath: myValidatePath];
					}

#endif __ppc__
					
					if (myFileExists == YES)
					{
						// remove "baseq2":
						myBaseDir[myPathLength - 6] = 0x00;
						
						// change working directory to the selected path:
						if (!chdir (myBaseDir))
						{
							if (myPathChanged)
							{
								[myDefaults setObject: myBasePath forKey: SYS_DEFAULT_BASE_PATH];
								[myDefaults synchronize];
							}
							break;
						}
						else if (myFirstRun == NO)
						{
							NSRunCriticalAlertPanel (@"Can\'t change to the selected path!", @"The selection was: \"%@\"", NULL, NULL, NULL, myBasePath);
						}
					}
					else if (myFirstRun == NO)
					{
						NSRunCriticalAlertPanel (@"Can\'t accept the selected folder!", @"The selected \"baseq2\" folder does not contain \"GameMac.q2plug\"!", NULL, NULL, NULL);
					}
				}
				else if (myFirstRun == NO)
				{
					NSRunCriticalAlertPanel (@"Can\'t accept the selected folder!", @"The selected folder is not the \"baseq2\" folder!", NULL, NULL, NULL);
				}
			}
			else if (myFirstRun == NO)
			{
				NSRunCriticalAlertPanel (@"Can\'t accept the selected folder!", @"The selected folder is not the \"baseq2\" folder!", NULL, NULL, NULL);
			}
		}
        
        // if the path from the user defaults is bad, look if the baseq2 folder is located at the same folder
        // as our Quake 2 application:
        if (myDefaultPath == YES)
        {
            myBasePath		= [[[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent: SYS_BASEQ2_PATH];
            myPathChanged	= YES;
            myDefaultPath	= NO;
        }
        else
        {
			NSOpenPanel*	myOpenPanel = [[NSOpenPanel alloc] init];
			
			[myOpenPanel setAllowsMultipleSelection: NO];
			[myOpenPanel setCanChooseFiles: NO];
			[myOpenPanel setCanChooseDirectories: YES];
			[myOpenPanel setTitle: @"Please locate the \"baseq2\" folder:"];
	
            // if we run for the first time or the location of the "baseq2" folder changed, show an info dialog:
            if (myFirstRun == YES)
            {
                NSRunInformationalAlertPanel (@"You will now be asked to locate the \"baseq2\" folder.",
                                              @"This folder is part of the retail installation of "
                                              @"Quake II. You will only be asked for it again, if you "
                                              @"change the location of this folder.",
                                              NULL, NULL, NULL);
                myFirstRun = NO;
            }
        
			// request the "baseq2" folder:
			myResult = [myOpenPanel runModalForDirectory: nil file: nil types: nil];
			
			// if the user selected "Cancel", quit the game:
			if (myResult == NSOKButton)
			{	
				// get the selected path:
				myFolder = [myOpenPanel filenames];
				
				if ([myFolder count])
				{
					myBasePath = [myFolder objectAtIndex: 0];
					myPathChanged = YES;
				}
			}
			
			[myOpenPanel release];
			
			if (myResult == NSCancelButton)
			{
				[NSApp terminate: nil];
			}
		}
    }
    
    // just check if the mod is located at the same folder as the id1 folder:
	if ([[NSApp delegate] wasDragged] == YES && [[[NSApp delegate] modFolder] isEqualToString: [myBasePath stringByDeletingLastPathComponent]] == NO)
    {
        NSRunInformationalAlertPanel (@"An error has occured:", @"The mission pack has to be located within "
                                      @"the same folder as the \"baseq2\" folder.", @"", NULL, NULL, NULL);
        [NSApp terminate: nil];
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	Sys_DoEvents (NSEvent *myEvent, NSEventType myType)
{
    extern cvar_t *		vid_fullscreen;
	extern cvar_t *		_windowed_mouse;
	extern cvar_t *		in_mouse;
    
    static NSString	*	myKeyboardBuffer;
    static unichar		myCharacter;
    static CGMouseDelta	myMouseDeltaX;
	static CGMouseDelta	myMouseDeltaY;
	static CGMouseDelta	myMouseWheel;
    static UInt8		i;
    static UInt16		myKeyPad;
    static UInt32	 	myKeyboardBufferSize;
	static UInt32	 	myFilteredFlags;
	static UInt32	 	myFlags;
	static UInt32	 	myLastFlags = 0;
	static UInt32	 	myFilteredMouseButtons;
	static UInt32	 	myMouseButtons;
	static UInt32	 	myLastMouseButtons = 0;

    // we check here for events:
    switch (myType)
    {
        case NSSystemDefined:
            SYS_CHECK_MOUSE_ENABLED ();
            
            if ([myEvent subtype] == 7)
            {
                myMouseButtons = [myEvent data2];
                myFilteredMouseButtons = myLastMouseButtons ^ myMouseButtons;
                
                for (i = 0; i < SYS_MOUSE_BUTTONS; i++)
                {
                    if(myFilteredMouseButtons & (1 << i))
                    {
                        Key_Event (K_MOUSE1 + i, (myMouseButtons & (1 << i)) ? 1 : 0, gSysMsgTime);
                    }
                }
                
                myLastMouseButtons = myMouseButtons;
            }
            else
            {
                [NSApp sendSuperEvent: myEvent];
            }
            
            break;
            
        // scroll wheel:
        case NSScrollWheel:
            SYS_CHECK_MOUSE_ENABLED ();
            
            myMouseWheel = [myEvent deltaY];

            if(myMouseWheel > 0)
            {
                Key_Event (K_MWHEELUP, true, gSysMsgTime);
                Key_Event (K_MWHEELUP, false, gSysMsgTime);
            }
            else
            {
                Key_Event (K_MWHEELDOWN, true, gSysMsgTime);
                Key_Event (K_MWHEELDOWN, false, gSysMsgTime);
            }
            break;
            
        // mouse movement:
        case NSMouseMoved:
        case NSLeftMouseDragged:
        case NSRightMouseDragged:
        case NSOtherMouseDragged:
            SYS_CHECK_MOUSE_ENABLED ();

            CGGetLastMouseDelta (&myMouseDeltaX, &myMouseDeltaY);
            IN_ReceiveMouseMove (myMouseDeltaX, myMouseDeltaY);

            break;

        // key up and down:
        case NSKeyDown:
        case NSKeyUp:
            myKeyboardBuffer = [myEvent charactersIgnoringModifiers];
            myKeyboardBufferSize = [myKeyboardBuffer length];

            for (i = 0; i < myKeyboardBufferSize; i++)
            {
                myCharacter = [myKeyboardBuffer characterAtIndex: i];
                
                if ((myCharacter & 0xFF00) ==  0xF700)
                {
                    myCharacter -= 0xF700;
                    if (myCharacter < 0x47)
                    {
                        if (gInSpecialKey[myCharacter])
                        {
                            Key_Event (gInSpecialKey[myCharacter], (myType == NSKeyDown), gSysMsgTime);
                            break;
                        }
                    }
                }
//                else
                {
                    myFlags = [myEvent modifierFlags];
                    
                    if (myFlags & NSNumericPadKeyMask)
                    {
                        myKeyPad = [myEvent keyCode];
            
                        if (myKeyPad < 0x5D && gInNumPadKey[myKeyPad] != 0x00)
                        {
                            Key_Event (gInNumPadKey[myKeyPad], (myType == NSKeyDown), gSysMsgTime);
                            break;
                        }                    
                    }
                    if (myCharacter < 0x80)
                    {
                        if (myCharacter >= 'A' && myCharacter <= 'Z')
                            myCharacter += 'a' - 'A';
                        Key_Event (myCharacter, (myType == NSKeyDown), gSysMsgTime);
                    }
                }
            }
            
            break;
        
        // special keys:
        case NSFlagsChanged:
            myFlags = [myEvent modifierFlags];
            myFilteredFlags = myFlags ^ myLastFlags;
            
            if (myFilteredFlags & NSAlphaShiftKeyMask)
                Key_Event (K_CAPSLOCK, (myFlags & NSAlphaShiftKeyMask) ? 1 : 0, gSysMsgTime);
                
            if (myFilteredFlags & NSShiftKeyMask)
                Key_Event (K_SHIFT, (myFlags & NSShiftKeyMask) ? 1 : 0, gSysMsgTime);
                
            if (myFilteredFlags & NSControlKeyMask)
                Key_Event (K_CTRL, (myFlags & NSControlKeyMask) ? 1 : 0, gSysMsgTime);
                
            if (myFilteredFlags & NSAlternateKeyMask)
                Key_Event (K_ALT, (myFlags & NSAlternateKeyMask) ? 1 : 0, gSysMsgTime);
                
            if (myFilteredFlags & NSCommandKeyMask)
                Key_Event (K_COMMAND, (myFlags & NSCommandKeyMask) ? 1 : 0, gSysMsgTime);
                
            if (myFilteredFlags & NSNumericPadKeyMask)
                Key_Event (K_NUMLOCK, (myFlags & NSNumericPadKeyMask) ? 1 : 0, gSysMsgTime);
                
            myLastFlags = myFlags;
            
            break;
        
        // process other events:
        default:
            [NSApp sendSuperEvent: myEvent];
            break;
    }
}

#pragma mark -

#endif /* !DEDICATED_ONLY */

//------------------------------------------------------------------------------------------------------------------------------------------------------------

int	main (int theArgCount, const char **theArgValues)
{
#ifdef DEDICATED_ONLY

    int		myTime;
	int		myOldTime;
	int		myNewTime;
    
    gSysArgCount	= theArgCount;
    gSysArgValues	= (char **) theArgValues;

    Qcommon_Init (gSysArgCount, gSysArgValues);

    fcntl(0, F_SETFL, fcntl (0, F_GETFL, 0) | FNDELAY);

    gSysNoStdOut = Cvar_Get("nostdout", "0", 0);
	
    if (gSysNoStdOut->value == 0.0)
    {
            fcntl(0, F_SETFL, fcntl (0, F_GETFL, 0) | FNDELAY);
    }

    myOldTime = Sys_Milliseconds ();
    
    Qcommon_Frame (0.1);

    while (1)
    {
        do
        {
            myNewTime	= Sys_Milliseconds ();
            myTime		= myNewTime - myOldTime;
        } while (myTime < 1);
		
        myOldTime = myNewTime;
        
        Qcommon_Frame (myTime);
    }

    return (0);

#else

    NSAutoreleasePool *	myPool		= [[NSAutoreleasePool alloc] init];
    NSUserDefaults *	myDefaults	= [NSUserDefaults standardUserDefaults];

    // required for the animated document window (needs to be done early!):
    [myDefaults registerDefaults: [NSDictionary dictionaryWithObject: @"YES" forKey: @"AppleDockIconEnabled"]];
    [myPool release];
	
    // the Finder passes "-psn_x_xxxxxxx". remove it.
    if (theArgCount == 2 && theArgValues[1] != NULL && strstr (theArgValues[1], "-psn_") == theArgValues[1])
    {
        gSysArgCount = 1;
    }
    else
    {
        gSysArgCount = theArgCount;
    }
	
    gSysArgValues = (char **) theArgValues;
    
    return (NSApplicationMain (theArgCount, theArgValues));

#endif /* DEDICATED ONLY */
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------
