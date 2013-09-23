//----------------------------------------------------------------------------------------------------------------------------
//
// "FDModifierCheck.m" - Allows one to check if the specified modifier key is pressed (usually at application launch time).
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import "FDModifierCheck.h"

//----------------------------------------------------------------------------------------------------------------------------

@interface FDModifierCheck ()

- (id) init;

@end

//----------------------------------------------------------------------------------------------------------------------------

@implementation FDModifierCheck

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) checkForModifier: (NSUInteger) modifierKeyMask
{
    BOOL        modifierWasPressed  = NO;    
    CGEventRef  shiftDown           = CGEventCreateKeyboardEvent (NULL, (CGKeyCode) 56, true);
    CGEventRef  shiftUp             = CGEventCreateKeyboardEvent (NULL, (CGKeyCode) 56, false);
    
    CGEventPost (kCGHIDEventTap, shiftDown); 
    CGEventPost (kCGHIDEventTap, shiftUp); 
    
    CFRelease (shiftDown);
    CFRelease (shiftUp);
    
    while (1)
    {
        NSAutoreleasePool*  pool  = [[NSAutoreleasePool alloc] init];
        NSEvent*            event = [NSApp nextEventMatchingMask: NSFlagsChangedMask
                                                       untilDate: [NSDate distantPast]
                                                          inMode: NSDefaultRunLoopMode
                                                         dequeue: YES];
        
        modifierWasPressed = ([event modifierFlags] & modifierKeyMask) != 0;
        
        if ((event == nil) || (modifierWasPressed == YES))
        {
            [pool release];
            break;
        }
        else
        {
            [NSApp sendEvent: event];
            [pool release];
        }
    }

    
    return modifierWasPressed;
}

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) checkForAlternateKey
{
    return ([FDModifierCheck checkForModifier: NSAlternateKeyMask]);
}

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) checkForCommandKey
{
    return ([FDModifierCheck checkForModifier: NSCommandKeyMask]);
}

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) checkForControlKey
{
    return ([FDModifierCheck checkForModifier: NSControlKeyMask]);
}

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) checkForOptionKey
{
    return ([FDModifierCheck checkForAlternateKey]);
}

//----------------------------------------------------------------------------------------------------------------------------

- (id) init
{
    self = [super init];
    
    if (self != nil)
    {
        [self doesNotRecognizeSelector: _cmd];
        [self release];
    }
    
    return nil;
}

@end

//----------------------------------------------------------------------------------------------------------------------------
