//----------------------------------------------------------------------------------------------------------------------------
//
// "FDHIDManager.h" - HID input
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import "FDDefines.h"
#import "FDHIDDevice.h"

#import <Cocoa/Cocoa.h>
#import <IOKit/hid/IOHIDLib.h>

//----------------------------------------------------------------------------------------------------------------------------

FD_EXTERN NSString*    FDHIDDeviceGamePad;
FD_EXTERN NSString*    FDHIDDeviceKeyboard;
FD_EXTERN NSString*    FDHIDDeviceMouse;

//----------------------------------------------------------------------------------------------------------------------------

enum FDHIDEventType
{
    eFDHIDEventTypeGamePadAxis,
    eFDHIDEventTypeGamePadButton,
    eFDHIDEventTypeKeyboard,
    eFDHIDEventTypeMouseAxis,
    eFDHIDEventTypeMouseButton
};

//----------------------------------------------------------------------------------------------------------------------------

enum FDHIDKey
{
    eFDHIDKeyTab            = 9,
    eFDHIDKeyEnter          = 13,
    eFDHIDKeyEscape         = 27,
    eFDHIDKeySpace          = 32,
    eFDHIDKeyBackspace      = 127,
    eFDHIDKeyUpArrow        = 128,
    eFDHIDKeyDownArrow      = 129,
    eFDHIDKeyLeftArrow      = 130,
    eFDHIDKeyRightArrow     = 131,
    eFDHIDKeyAlternate      = 132,
    eFDHIDKeyOption         = 132,
    eFDHIDKeyControl        = 133,
    eFDHIDKeyShift          = 134,    
    eFDHIDKeyF1             = 135,
    eFDHIDKeyF2             = 136,
    eFDHIDKeyF3             = 137,
    eFDHIDKeyF4             = 138,
    eFDHIDKeyF5             = 139,
    eFDHIDKeyF6             = 140,
    eFDHIDKeyF7             = 141,
    eFDHIDKeyF8             = 142,
    eFDHIDKeyF9             = 143,
    eFDHIDKeyF10            = 144,
    eFDHIDKeyF11            = 145,
    eFDHIDKeyF12            = 146,
    eFDHIDKeyInsert         = 147,
    eFDHIDKeyDelete         = 148,
    eFDHIDKeyPageDown       = 149,
    eFDHIDKeyPageUp         = 150,
    eFDHIDKeyHome           = 151,
    eFDHIDKeyEnd            = 152,
    eFDHIDKeyCapsLock       = 153,
    eFDHIDKeyCommand        = 154,
    eFDHIDKeyNumLock        = 155,
    eFDHIDKeyF13            = 156,
    eFDHIDKeyF14            = 157,
    eFDHIDKeyF15            = 158,
    eFDHIDKeyF16            = 159,
    eFDHIDKeyPadEqual       = 160,
    eFDHIDKeyPadSlash       = 161,
    eFDHIDKeyPadAsterisk    = 162,
    eFDHIDKeyPadMinus       = 163,
    eFDHIDKeyPadPlus        = 164,
    eFDHIDKeyPadEnter       = 165,
    eFDHIDKeyPadPeriod      = 166,
    eFDHIDKeyPad0           = 167,
    eFDHIDKeyPad1           = 168,
    eFDHIDKeyPad2           = 169,
    eFDHIDKeyPad3           = 170,
    eFDHIDKeyPad4           = 171,
    eFDHIDKeyPad5           = 172,
    eFDHIDKeyPad6           = 173,
    eFDHIDKeyPad7           = 174,
    eFDHIDKeyPad8           = 175,
    eFDHIDKeyPad9           = 176,
    eFDHIDKeyPause          = 255
};

//----------------------------------------------------------------------------------------------------------------------------

enum FDHIDMouseAxis
{
    eFDHIDMouseAxisX,
    eFDHIDMouseAxisY,
    eFDHIDMouseAxisWheel
};

//----------------------------------------------------------------------------------------------------------------------------

enum FDHIDGamePadAxis
{
    eFDHIDGamePadAxisLeftX,
    eFDHIDGamePadAxisLeftY,
    eFDHIDGamePadAxisLeftZ,
    eFDHIDGamePadAxisRightX,
    eFDHIDGamePadAxisRightY,
    eFDHIDGamePadAxisRightZ
};

//----------------------------------------------------------------------------------------------------------------------------

typedef struct
{
    FDHIDDevice*        mDevice;
    enum FDHIDEventType mType;
    unsigned int        mButton;
    
    union
    {
        float           mFloatVal;
        signed int      mIntVal;
        BOOL            mBoolVal;
    };
    
    unsigned int        mPadding;
} FDHIDEvent;

//----------------------------------------------------------------------------------------------------------------------------

@interface FDHIDManager : NSObject
{
}

+ (FDHIDManager*) sharedHIDManager;
+ (void) checkForIncompatibleDevices;

- (void) setDeviceFilter: (NSArray*) deviceTypes;
- (NSArray*) devices;
- (const FDHIDEvent*) nextEvent;

@end

//----------------------------------------------------------------------------------------------------------------------------
