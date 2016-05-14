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

+ (NSArray<FDDisplay*>*) displays;
+ (FDDisplay*) mainDisplay;

@property (readonly) NSRect frame;

- (NSString*) description;

@property (readonly, retain) FDDisplayMode* displayMode;
@property (readonly, retain) FDDisplayMode* originalMode;

- (NSArray<FDDisplayMode*>*) displayModes;

- (BOOL) setDisplayMode: (FDDisplayMode*) displayMode;

@property (readonly, getter=isMainDisplay) BOOL mainDisplay;
@property (readonly, getter=isBuiltinDisplay) BOOL builtinDisplay;
@property (readonly, getter=isCaptured) BOOL captured;

@property (readonly) BOOL hasFSAA;

@property (readonly) float gamma;
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
