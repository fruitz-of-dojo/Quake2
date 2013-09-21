//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "readme.m" - MacOS X help launcher for the installer image.
//
// Written by:	Axel 'awe' Wefers           [mailto:awe@fruitz-of-dojo.de].
//              ©2002-2006 Fruitz Of Dojo   [http://www.fruitz-of-dojo.de].
//
// Version History:
// v1.0:   Initial release.
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark =Includes=

#import <AppKit/AppKit.h>

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark =ObjC Interfaces=

@interface ReadMe : NSObject
@end

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@implementation ReadMe

//------------------------------------------------------------------------------------------------------------------------------------------------------------

- (void) applicationDidFinishLaunching: (NSNotification *) theNotification
{
    // show the help and terminate:
    [NSApp showHelp: NULL];
    [NSApp terminate: NULL];
}

@end

//------------------------------------------------------------------------------------------------------------------------------------------------------------

int	main (int theArgCount, const char **theArgValues)
{
    NSAutoreleasePool *	myPool			= [[NSAutoreleasePool alloc] init];
    NSApplication *		myApplication	= [NSApplication sharedApplication];
    ReadMe *			myReadMe		= [[ReadMe alloc] init];

    [myApplication setDelegate: myReadMe];
    [myApplication run];
	
    [myReadMe release];
    [myPool release];
    
    return (0);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------
