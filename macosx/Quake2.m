//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "Quake2.m"
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2006 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
// Quake IIª is copyrighted by id software  [http://www.idsoftware.com].
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#import "Quake2.h"
#import "sys_osx.h"
#import "FDModifierCheck.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@implementation Quake2 : NSObject

//------------------------------------------------------------------------------------------------------------------------------------------------------------

+ (void) initialize
{
    NSUserDefaults	*myDefaults = [NSUserDefaults standardUserDefaults];
    NSString		*myDefaultPath = [[[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent]
                                                                stringByAppendingPathComponent: SYS_BASEQ2_PATH];
                                                                
    // set the default path:
    [myDefaults registerDefaults: [NSDictionary dictionaryWithObjects:
                                                    [NSArray arrayWithObjects: myDefaultPath,
                                                                               SYS_INITIAL_OPTION_KEY,
                                                                               SYS_INITIAL_USE_MP3,
                                                                               SYS_INITIAL_MP3_PATH,
                                                                               SYS_INITIAL_USE_PARAMETERS,
                                                                               SYS_INITIAL_PARAMETERS,
                                                                               nil]
                                                forKeys: 
                                                    [NSArray arrayWithObjects: SYS_DEFAULT_BASE_PATH,
                                                                               SYS_DEFAULT_OPTION_KEY,
                                                                               SYS_DEFAULT_USE_MP3,
                                                                               SYS_DEFAULT_MP3_PATH,
                                                                               SYS_DEFAULT_USE_PARAMETERS,
                                                                               SYS_DEFAULT_PARAMETERS,
                                                                               nil]
                                  ]];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) dealloc
{
	[mRequestedCommands release];
	[mModFolder release];
    [mDistantPast release];
    [super dealloc];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (BOOL) application: (NSApplication *) theSender openFile: (NSString *) theFilePath
{
    // allow only dragging one time as command line parameter:
    if (mDenyDrag == YES)
    {
        // insert the dragged item as console command:
        if ([self hostInitialized] == YES)
        {
            BOOL		myDirectory;
            
            if (![[NSFileManager defaultManager] fileExistsAtPath: theFilePath isDirectory: &myDirectory])
            {
                Com_Printf ("Error: The dragged item is not a valid file!\n");
            }
            else
            {
                if (myDirectory == NO)
                {
                    Com_Printf ("Error: The dragged item is not a folder!\n");
                }
                else
                {
                    const char 	*myPath =[theFilePath fileSystemRepresentation];
                    
                    if (myPath != NULL)
                    {
                        SInt32	myIndex = strlen (myPath) - 1;

                        while (myIndex > 1)
                        {
                            if (myPath[myIndex - 1] == '/')
                            {
                                Cbuf_ExecuteText (EXEC_APPEND, va("set game \"%s\"\n", myPath + myIndex));
                                return (YES);
                            }
                            myIndex--;
                        }  
                        Com_Printf ("Error: Can\'t extract path!\n");
                    }
                    else
                    {
                        Com_Printf ("Error: Unable to obtain filesystem representation!\n");
                    }
                }
            }
        }
        return (NO);
    }
	
    mDenyDrag = YES;
    
    if (gSysArgCount > 2)
    {
        return (NO);
    }
    
    // we have received a filepath:
    if (theFilePath != NULL)
    {
    
        char 		*myMod  = (char *) [[theFilePath lastPathComponent] fileSystemRepresentation];
        char 		*myPath = (char *) [theFilePath fileSystemRepresentation];
        char		**myNewArgValues;
        BOOL		myDirectory;
        
        // is the filepath a folder?
        if (![[NSFileManager defaultManager] fileExistsAtPath: theFilePath isDirectory: &myDirectory])
        {
            Sys_Error ("The dragged item is not a valid file!");
        }
        if (myDirectory == NO)
        {
            Sys_Error ("The dragged item is not a folder!");
        }

        // prepare the new command line options:
        myNewArgValues = malloc (sizeof(char *) * 4);
        SYS_CHECK_MALLOC (myNewArgValues);
        gSysArgCount = 4;
        myNewArgValues[0] = gSysArgValues[0];
        gSysArgValues = myNewArgValues;
        gSysArgValues[1] = SYS_SET_COMMAND;
        gSysArgValues[2] = SYS_GAME_COMMAND;
        gSysArgValues[3] = malloc (strlen (myPath) + 1);
        SYS_CHECK_MALLOC (gSysArgValues[3]);
        strcpy (gSysArgValues[3], myMod);
        
        // get the path of the mod [compare it with the id1 path later]:
		mModFolder = [[theFilePath stringByDeletingLastPathComponent] retain];

        return (YES);
    }
    return (NO);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) applicationDidResignActive: (NSNotification *) theNote
{
    if ([self hostInitialized]  == YES)
    {
		IN_ShowCursor (YES);
		IN_SetKeyboardRepeatEnabled (YES);
		IN_SetF12EjectEnabled (YES);
	}
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) applicationDidBecomeActive: (NSNotification *) theNote
{
    extern qboolean		keydown[];
    extern cvar_t *		_windowed_mouse;
	extern cvar_t *		in_mouse;
	extern cvar_t *		vid_fullscreen;

    if ([self hostInitialized] == NO)
    {
        return;
    }
                        
    if ((vid_fullscreen != NULL && vid_fullscreen->value != 0.0f) ||
        ((in_mouse == NULL || (in_mouse != NULL && in_mouse->value == 0.0f) &&
         (_windowed_mouse != NULL && _windowed_mouse->value != 0.0f))))
    {
        IN_ShowCursor (NO);
    }

    keydown[K_COMMAND] = NO;
    keydown[K_TAB] = NO;
    keydown['H'] = NO;

    IN_SetKeyboardRepeatEnabled (NO);
    IN_SetF12EjectEnabled (NO);
    CDAudio_Enable (YES);
    VID_SetPaused (NO);
    
    CGPostKeyboardEvent ((CGCharCode) 0, (CGKeyCode) 55, NO);	// CMD
    CGPostKeyboardEvent ((CGCharCode) 0, (CGKeyCode) 48, NO);	// TAB
    CGPostKeyboardEvent ((CGCharCode) 0, (CGKeyCode) 4, NO);	// H

	[self installFrameTimer];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) applicationWillHide: (NSNotification *) theNote
{
    if ([self hostInitialized] == NO)
    {
        return;
    }

    IN_ShowCursor (YES);
    IN_SetKeyboardRepeatEnabled (YES);
    IN_SetF12EjectEnabled (YES);
    CDAudio_Enable (NO);
    VID_SetPaused (YES);

	[mFrameTimer invalidate];
	mFrameTimer = nil;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) applicationDidFinishLaunching: (NSNotification *) theNote
{
    SYS_Q2_DURING
    {
        NSTimer		*myTimer;

        [self setHostInitialized: NO]; 
        [self enableAppleScriptRun: YES];

        mDenyDrag = YES;
    
        Sys_CheckForIDDirectory ();
    
        Sys_CheckForCDDirectory ();
    
        // check if the user has pressed the Option key on startup:
		mOptionPressed = [FDModifierCheck checkForOptionKey];
    
        // show the settings dialog after 0.5s (required to recognize the "run" AppleScript command):
        myTimer = [NSTimer scheduledTimerWithTimeInterval: 0.5f
                                                target: self
                                                selector: @selector (setupDialog:)
                                                userInfo: NULL
                                                repeats: NO];
                                              
        if (myTimer == NULL)
        {
            [self setupDialog: NULL];
        }
    }
    SYS_Q2_HANDLER;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *) theSender
{
    if ([self hostInitialized]  == YES)
    {
        extern cvar_t	*vid_fullscreen;
        
        if ([NSApp isHidden] == YES || [NSApp isActive] == NO)
        {
            [NSApp activateIgnoringOtherApps: YES];
        }
        
        if (vid_fullscreen != NULL && vid_fullscreen->value == 0.0f)
        {
            NSArray	*myWindowList = [NSApp windows];
            
            if (myWindowList != NULL)
            {
                int	myCount = [myWindowList count],
                        myIndex;
                
                for (myIndex = 0; myIndex < myCount; myIndex++)
                {
                    NSWindow	*myWindow = [myWindowList objectAtIndex: myIndex];
                    
                    if (myWindow != NULL)
                    {
                        if ([myWindow isMiniaturized] == YES)
                        {
                            [myWindow deminiaturize: NULL];
                        }
                    }
                }
            }
        }
        
        M_Menu_Quit_f ();
        return (NSTerminateCancel);
    }
    
    return (NSTerminateNow);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (BOOL) hostInitialized
{
    return (mHostInitialized);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) setHostInitialized: (BOOL) theState
{
    mHostInitialized = theState;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (BOOL) allowAppleScriptRun
{
    return (mAllowAppleScriptRun);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) enableAppleScriptRun: (BOOL) theState
{
    mAllowAppleScriptRun = theState;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) requestCommand: (NSString *) theCommand
{
    [mRequestedCommands addObject: theCommand];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (BOOL) wasDragged
{
    return (mModFolder != NULL ? YES : NO);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (NSString *) modFolder
{
    return (mModFolder);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (NSString *) mediaFolder
{
    return (mMP3Folder);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (BOOL) abortMediaScan
{
    return (mMediaScanCanceled);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) setupParameterUI:  (NSUserDefaults *) theDefaults
{
    // check if the user passed parameters from the command line or by dragging a mod:
    if (gSysArgCount > 1)
    {
        NSString	*myParameters;

        // someone passed command line parameters:
        myParameters = [[[NSString alloc] init] autorelease];

        if (myParameters != NULL)
        {
            SInt	i;
            
            for (i = 1; i < gSysArgCount; i++)
            {
                // surround the string by ", if it contains spaces:
                if (strchr (gSysArgValues[i], ' '))
                {
                    myParameters = [myParameters stringByAppendingFormat: @"\"%s\" ", gSysArgValues[i]];
                }
                else
                {
                    myParameters = [myParameters stringByAppendingFormat: @"%s", gSysArgValues[i]];
                }
                
                // add a space if this was not the last parameter:
                if (i != gSysArgCount - 1)
                {
                    myParameters = [myParameters stringByAppendingString: @" "];
                }
            }

            // display the current parameters:
            [parameterTextField setStringValue: myParameters];
        }

        //don't allow changes:
        [parameterCheckBox setEnabled: NO];
        [parameterTextField setEnabled: NO];
    }
    else
    {
        BOOL	myParametersEnabled;
        
        // get the default command line parameters:
        myParametersEnabled = [theDefaults boolForKey: SYS_DEFAULT_USE_PARAMETERS];
        [parameterTextField setStringValue: [theDefaults stringForKey: SYS_DEFAULT_PARAMETERS]];
        [parameterCheckBox setState: myParametersEnabled];
        [parameterCheckBox setEnabled: YES];
        [self toggleParameterTextField: NULL];        
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) setupDialog: (NSTimer *) theTimer
{
    SYS_Q2_DURING
    {
        NSUserDefaults 	*myDefaults = NULL;
        
        // don't allow the "run" AppleScript command to be executed anymore:
		[self enableAppleScriptRun: NO];
		
        myDefaults = [NSUserDefaults standardUserDefaults];
    
        // prepare the "option key" and the "use MP3" checkbox:
        [optionCheckBox setState: [myDefaults boolForKey: SYS_DEFAULT_OPTION_KEY]];
        [mp3CheckBox setState: [myDefaults boolForKey: SYS_DEFAULT_USE_MP3]];
        [self toggleMP3Playback: self];
    
        // prepare the "MP3 path" textfield:
        [mp3TextField setStringValue: [myDefaults stringForKey: SYS_DEFAULT_MP3_PATH]];
    
        // prepare the command-line parameter textfield and checkbox:
        [self setupParameterUI: myDefaults];
        
        if ([optionCheckBox state] == NO || ([optionCheckBox state] == YES && mOptionPressed == YES))
        {
            // show the startup dialog:
            [startupWindow center];
            [startupWindow makeKeyAndOrderFront: nil];
        }
        else
        {
            // start the game immediately:
            [self startQuake2: nil];
        }
    } SYS_Q2_HANDLER;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) saveCheckBox: (NSButton *) theButton initial: (NSString *) theInitial
              default: (NSString *) theDefault userDefaults: (NSUserDefaults *) theUserDefaults
{
    // has our checkbox the initial value? if, delete from defaults::
    if ([theButton state] == [self isEqualTo: theInitial])
    {
        [theUserDefaults removeObjectForKey: theDefault];
    }
    else
    {
        // write to defaults:
        if ([theButton state] == YES)
        {
            [theUserDefaults setObject: @"YES" forKey: theDefault];
        }
        else
        {
            [theUserDefaults setObject: @"NO" forKey: theDefault];
        }
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) saveString: (NSString *) theString initial: (NSString *) theInitial
            default: (NSString *) theDefault userDefaults: (NSUserDefaults *) theUserDefaults
{
    // has our popup menu the initial value? if, delete from defaults:
    if ([theString isEqualToString: theInitial])
    {
        [theUserDefaults removeObjectForKey: theDefault];
    }
    else
    {
        // write to defaults:
        [theUserDefaults setObject: theString forKey: theDefault];
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) stringToParameters: (NSString *) theString
{
    NSArray		*mySeparatedArguments;
    NSMutableArray      *myNewArguments;
    NSCharacterSet	*myQuotationMarks;
    NSString		*myArgument;
    char		**myNewArgValues;
    SInt		i;
    
    // get all parameters separated by a space:
    mySeparatedArguments = [theString componentsSeparatedByString: @" "];
    
    // no parameters at all?
    if (mySeparatedArguments == NULL || [mySeparatedArguments count] == 0)
    {
        return;
    }
    
    // concatenate parameters that start on " and end on ":
    myNewArguments = [NSMutableArray arrayWithCapacity: 0];
    myQuotationMarks = [NSCharacterSet characterSetWithCharactersInString: @"\""];
    
    for (i = 0; i < [mySeparatedArguments count]; i++)
    {
        myArgument = [mySeparatedArguments objectAtIndex: i];
        if (myArgument != NULL && [myArgument length] != 0)
        {
            if ([myArgument characterAtIndex: 0] == '\"')
            {
                myArgument = [NSString stringWithString: @""];
                for (; i < [mySeparatedArguments count]; i++)
                {
                    myArgument = [myArgument stringByAppendingString: [mySeparatedArguments objectAtIndex: i]];
                    if ([myArgument characterAtIndex: [myArgument length] - 1] == '\"')
                    {
                        break;
                    }
                    else
                    {
                        if (i < [mySeparatedArguments count] - 1)
                        {
                            myArgument = [myArgument stringByAppendingString: @" "];
                        }
                    }
                }
            }
            myArgument = [myArgument stringByTrimmingCharactersInSet: myQuotationMarks];
            if (myArgument != NULL && [myArgument length] != 0)
            {
                [myNewArguments addObject: myArgument];
            }
        }
    }

    gSysArgCount = [myNewArguments count] + 1;
    myNewArgValues = (char **) malloc (sizeof(char *) * gSysArgCount);
    SYS_CHECK_MALLOC (myNewArgValues);

    myNewArgValues[0] = gSysArgValues[0];
    gSysArgValues = myNewArgValues;
    
    // insert the new parameters:
    for (i = 0; i < [myNewArguments count]; i++)
    {
        char *	myCString = (char *) [[myNewArguments objectAtIndex: i] cString];
        
        gSysArgValues[i+1] = (char *) malloc (strlen (myCString) + 1);
        SYS_CHECK_MALLOC (gSysArgValues[i+1]);
        strcpy (gSysArgValues[i+1], myCString);
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (BOOL) isEqualTo: (NSString *) theString
{
	return [theString isEqualToString: @"YES"];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) scanMediaThread: (id) theSender
{
    SYS_Q2_DURING
    {
        // scan for media files:
        CDAudio_GetTrackList ();
        
        // post a notification to the main thread:
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"Fire Frame Timer" object: NULL];
        
        // job done, good bye!
        [NSThread exit];
    } SYS_Q2_HANDLER;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) stopMediaScan: (id) theSender
{
    mMediaScanCanceled = YES;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) fireFrameTimer: (NSNotification *) theNotification
{
    SYS_Q2_DURING
    {
        // close the media scan window:
        [mediascanProgressIndicator stopAnimation: self];
        [mediascanWindow close];
        [[NSNotificationCenter defaultCenter] removeObserver: self name: @"Fire Frame Timer" object: NULL];
        
        // alias the action of the past menu item:
        [pasteMenuItem setTarget: self];
        [pasteMenuItem setAction: @selector (pasteString:)];
    
        IN_SetKeyboardRepeatEnabled (NO);
        IN_SetF12EjectEnabled (NO);
    
        [NSApp activateIgnoringOtherApps: YES];
    
        Qcommon_Init (gSysArgCount, gSysArgValues);
    
		while ([mRequestedCommands count] > 0)
		{
			NSString	*myCommand = [mRequestedCommands objectAtIndex: 0];

			Cbuf_ExecuteText (EXEC_APPEND, va("%s\n", [myCommand cString]));
			[mRequestedCommands removeObjectAtIndex: 0];
		}
				    
		[self setHostInitialized: YES]; 
        mMediaScanCanceled = NO;
        
        [NSApp setServicesProvider: self];
    
        fcntl(0, F_SETFL, fcntl (0, F_GETFL, 0) | FNDELAY);
    
        gSysNoStdOut = Cvar_Get("nostdout", "0", 0);
        if (gSysNoStdOut->value == 0.0)
        {
                fcntl(0, F_SETFL, fcntl (0, F_GETFL, 0) | FNDELAY);
        }
    
        mLastFrameTime = Sys_Milliseconds ();
        
        Qcommon_Frame (0.1);
        
        // install our frame renderer to the default runloop:
        [self installFrameTimer];
    } SYS_Q2_HANDLER;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) startQuake2: (id) theSender
{
    SYS_Q2_DURING
    {
        NSUserDefaults	*myDefaults = [NSUserDefaults standardUserDefaults];

        // save the state of the "option key" checkbox:
        [self saveCheckBox: optionCheckBox initial: SYS_INITIAL_OPTION_KEY
                                           default: SYS_DEFAULT_OPTION_KEY
                                      userDefaults: myDefaults];

        // save the state of the "use MP3" checkbox:
        [self saveCheckBox: mp3CheckBox initial: SYS_INITIAL_USE_MP3
                                        default: SYS_DEFAULT_USE_MP3
                                   userDefaults: myDefaults];

        // save the MP3 path:
        [self saveString: [mp3TextField stringValue] initial: SYS_INITIAL_MP3_PATH
                                                     default: SYS_DEFAULT_MP3_PATH
                                                userDefaults: myDefaults];
        
        // save the state of the "use command line parameters" checkbox:
        [self saveCheckBox: parameterCheckBox initial: SYS_INITIAL_USE_PARAMETERS
                                              default: SYS_DEFAULT_USE_PARAMETERS
                                         userDefaults: myDefaults];

        // save the command line string from the parameter text field [only if no parameters were passed]:
        if ([parameterCheckBox isEnabled] == YES)
        {
            [self saveString: [parameterTextField stringValue] initial: SYS_INITIAL_PARAMETERS
                                                               default: SYS_DEFAULT_PARAMETERS
                                                          userDefaults: myDefaults];
    
            if ([parameterCheckBox state] == YES)
            {
                [self stringToParameters: [parameterTextField stringValue]];
            }
        }
 
        if ([mp3CheckBox state] == YES)
        {
            mMP3Folder = [mp3TextField stringValue];
            [mediascanText setStringValue: @"Scanning folder for MP3 and MP4 files..."];
        }
        else
        {
            [mediascanText setStringValue: @"Scanning AudioCDs..."];
        }
 
        [myDefaults synchronize];       
        [startupWindow close];
        
        // scan for medias, show a dialog since this can take a while:
		SNDDMA_ReserveBufferSize ();
        [mediascanWindow center];
        [mediascanWindow makeKeyAndOrderFront: nil];
        [mediascanProgressIndicator startAnimation: self];
        [[NSDistributedNotificationCenter defaultCenter] addObserver: self
                                                            selector: @selector (fireFrameTimer:)
                                                                name: @"Fire Frame Timer"
                                                              object: NULL];

        [NSThread detachNewThreadSelector: @selector (scanMediaThread:) toTarget: self withObject: nil];
    } SYS_Q2_HANDLER;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) installFrameTimer
{
    // we may not set the timer interval too small, otherwise we wouldn't get AppleScript commands. odd eh?
    mFrameTimer = [NSTimer scheduledTimerWithTimeInterval: 0.0003f //0.000001f
                                                   target: self
                                                 selector: @selector (renderFrame:)
                                                 userInfo: NULL
                                                  repeats: YES];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) renderFrame: (NSTimer *) theTimer
{
    static int		myNewFrameTime, myFrameTime;

    if (dedicated && dedicated->value)
    {
        sleep (1);
    }

    do
    {
        myNewFrameTime = Sys_Milliseconds ();
        myFrameTime = myNewFrameTime - mLastFrameTime;
    } while (myFrameTime < 1);
    mLastFrameTime = myNewFrameTime;
    
    Qcommon_Frame (myFrameTime);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) toggleParameterTextField: (id) theSender
{
    [parameterTextField setEnabled: [parameterCheckBox state]];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) toggleMP3Playback: (id) theSender
{
    BOOL	myState = [mp3CheckBox state];
    
    [mp3Button setEnabled: myState];
    [mp3TextField setEnabled: myState];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) selectMP3Folder: (id) theSender
{
    // prepare the sheet, if not already done:
	NSOpenPanel *	myMP3Panel = [NSOpenPanel openPanel];

    [myMP3Panel setAllowsMultipleSelection: NO];
    [myMP3Panel setCanChooseFiles: NO];
    [myMP3Panel setCanChooseDirectories: YES];
    [myMP3Panel setAccessoryView: mp3HelpView];
    [myMP3Panel setDirectory: [mp3TextField stringValue]];
    [myMP3Panel setTitle: @"Select the folder that holds the MP3s:"];
    
    // show the sheet:
    [myMP3Panel beginSheetForDirectory: @""
                                  file: NULL
                                 types: NULL
                        modalForWindow: startupWindow
                         modalDelegate: self
                        didEndSelector: @selector (closeMP3Sheet:returnCode:contextInfo:)
                           contextInfo: NULL];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) closeMP3Sheet: (NSOpenPanel *) theSheet returnCode: (int) theCode contextInfo: (void *) theInfo
{
    [theSheet close];

    // do nothing on cancel:
    if (theCode != NSCancelButton)
    {
        NSArray *		myFolderArray;

        // get the path of the selected folder;
        myFolderArray = [theSheet filenames];
        if ([myFolderArray count] > 0)
        {
            [mp3TextField setStringValue: [myFolderArray objectAtIndex: 0]];
        }
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) visitFOD: (id) theSender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: SYS_FRUITZ_OF_DOJO_URL]];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (IBAction) pasteString: (id) theSender
{
    extern qboolean		keydown[];
    UInt32				myCurTime = Sys_Milliseconds ();
    qboolean			myOldCommand,
                        myOldVKey;

    // get the old state of the paste keys:
    myOldCommand = keydown[K_COMMAND];
    myOldVKey = keydown['v'];

    // send the keys required for paste:
    keydown[K_COMMAND] = true;
    Key_Event ('v', true, myCurTime);

    // set the old state of the paste keys:
    Key_Event ('v', false, myCurTime);
    keydown[K_COMMAND] = myOldCommand;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) connectToServer: (NSPasteboard *) thePasteboard userData:(NSString *)theData error: (NSString **) theError
{
    NSArray 	*myPasteboardTypes;

    myPasteboardTypes = [thePasteboard types];

    if ([myPasteboardTypes containsObject: NSStringPboardType])
    {
        NSString 	*myRequestedServer;

        myRequestedServer = [thePasteboard stringForType: NSStringPboardType];
        if (myRequestedServer != NULL)
        {
            Cbuf_ExecuteText (EXEC_APPEND, va("connect %s\n", [myRequestedServer cString]));
            return;
        }
    }
    *theError = @"Unable to connect to a server: could not find a string on the pasteboard!";
}

@end

//------------------------------------------------------------------------------------------------------------------------------------------------------------
