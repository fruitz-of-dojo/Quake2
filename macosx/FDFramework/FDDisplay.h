//----------------------------------------------------------------------------------------------------------------------------
//
// "FDDisplay.h"
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import "FDDisplayMode.h"

#import <Cocoa/Cocoa.h>

//----------------------------------------------------------------------------------------------------------------------------

@interface FDDisplay : NSObject
{
}

+ (NSArray*) displays;
+ (FDDisplay*) mainDisplay;

- (NSRect) frame;

- (NSString*) description;

- (FDDisplayMode*) displayMode;
- (FDDisplayMode*) originalMode;

- (NSArray*) displayModes;

- (BOOL) setDisplayMode: (FDDisplayMode*) displayMode;

- (BOOL) isMainDisplay;
- (BOOL) isBuiltinDisplay;
- (BOOL) isCaptured;

- (BOOL) hasFSAA;

- (float) gamma; 
- (void) setGamma: (float) gamma update: (BOOL) doUpdate;

- (void) fadeOutDisplay: (float) seconds;
- (void) fadeInDisplay: (float) seconds;

+ (void) fadeOutAllDisplays: (float) seconds;
+ (void) fadeInAllDisplays: (float) seconds;

- (void) captureDisplay;
- (void) releaseDisplay;

+ (void) captureAllDisplays;
+ (void) releaseAllDisplays;
+ (BOOL) isAnyDisplayCaptured;

@end

//----------------------------------------------------------------------------------------------------------------------------
