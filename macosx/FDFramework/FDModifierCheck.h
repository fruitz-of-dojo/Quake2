//----------------------------------------------------------------------------------------------------------------------------
//
// "FDModifierCheck.h" - Allows one to check if the specified modifier key is pressed (usually at application launch time).
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>

//----------------------------------------------------------------------------------------------------------------------------

@interface FDModifierCheck : NSObject
{
}

+ (BOOL) checkForModifier: (NSUInteger) theModifierKeyMask;

+ (BOOL) checkForAlternateKey;
+ (BOOL) checkForCommandKey;
+ (BOOL) checkForControlKey;
+ (BOOL) checkForOptionKey;

@end

//----------------------------------------------------------------------------------------------------------------------------
