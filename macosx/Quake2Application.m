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

#import "Quake2Application.h"
#import "Quake2.h"

#include "sys_osx.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@implementation Quake2Application : NSApplication

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) sendEvent: (NSEvent *) theEvent
{
    // we need to intercept NSApps "sendEvent:" action:
    if ([[self delegate] hostInitialized] == YES)
    {
        if ([NSApp isHidden] == YES)
        {
            S_StopAllSounds ();
            [super sendEvent: theEvent];
        }
        else
        {
            Sys_DoEvents (theEvent, [theEvent type]);
        }
    }
    else
    {
        [super sendEvent: theEvent];
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) sendSuperEvent: (NSEvent *) theEvent
{
    [super sendEvent: theEvent];
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) handleRunCommand: (NSScriptCommand *) theCommand
{
    if ([[self delegate] allowAppleScriptRun] == YES)
    {
        NSDictionary *	myArguments = [theCommand evaluatedArguments];
    
        if (myArguments != nil)
        {
            NSString *	myParameters = [myArguments objectForKey: @"Quake2Parameters"];
        
            // Check if we got command line parameters:
            if (myParameters != nil && [myParameters isEqualToString: @""] == NO)
            {
                [[self delegate] stringToParameters: myParameters];
            }
            else
            {
                [[self delegate] stringToParameters: @""];
            }
        }
		
		[[self delegate] enableAppleScriptRun: NO];
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) handleConsoleCommand: (NSScriptCommand *) theCommand
{
    NSDictionary *	myArguments = [theCommand evaluatedArguments];

    if (myArguments != nil)
    {
        NSString *	myCommandList= [myArguments objectForKey: @"Quake2Commandlist"];
        
        // Send the console command only if we got commands:
        if (myCommandList != nil && [myCommandList isEqualToString: @""] == NO)
        {
            // required because of the options dialog - we have to wait with the command until host_init() is finished!
            if ([[self delegate] hostInitialized] == YES)
            {
                Cbuf_ExecuteText (EXEC_APPEND, va("%s\n", [myCommandList cString]));
            }
            else
            {
				[[self delegate] requestCommand: myCommandList];
            }
        }
    }
}

@end

//------------------------------------------------------------------------------------------------------------------------------------------------------------
