//----------------------------------------------------------------------------------------------------------------------------
//
// "FDHIDActuator.m"
//
// NOTE: This was only tested with a X360 controller and the driver by Colin Munro [http://tattiebogle.net].
//       I have found the following issues with v0.11 of this driver:
//       - FFEffectStop() does not seem to work consistently. FFEffectGetEffectStatus() reports not playing but it is playing.
//       - FFEFFECT::dwFlags needs to have FFEFF_SPHERICAL set. MS sample code uses FFEFF_CARTESIAN which is not supported.
//       - FFEFFECT::dwSamplePeriod is not supported.
//       - FFPERIODIC::dwPeriod is not handled in miliseconds (seems to be off by a factor of ~10).
//       The workaround for FFEffectStop() is to rely on setting the effect duration instead of stopping the effect manually.
//       I hope that the effect duration makes sense for other controllers since it does not match up with the documentation.
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import "FDHIDActuator.h"
#import "FDHIDDevice.h"
#import "FDHIDInternal.h"
#import "FDDebug.h"
#import "FDDefines.h"

#import <Cocoa/Cocoa.h>
#import <ForceFeedback/ForceFeedback.h>

#import <IOKit/hidsystem/IOHIDLib.h>
#import <IOKit/hid/IOHIDLib.h>

//----------------------------------------------------------------------------------------------------------------------------

static const DWORD  sFDHIDActuatorDuration = 2 * FF_SECONDS / 100;

//----------------------------------------------------------------------------------------------------------------------------

@implementation _FDHIDActuator

- (id) init
{
    self = [super init];
    
    if (self != nil)
    {
        [self release];
    }
    
    return nil;
}

//----------------------------------------------------------------------------------------------------------------------------

- (id) initWithDevice: (_FDHIDDevice*) device
{
    self = [super init];
    
    if (self != nil)
    {
        FFCAPABILITIES          features        = { 0 };
        UInt32                  autocenter      = 0;
        UInt32                  gain            = FF_FFNOMINALMAX;
        IOHIDDeviceRef          pDevice         = [device iohidDeviceRef];
        CFMutableDictionaryRef  matchingDict    = nil;
        CFTypeRef               cfType          = nil;
        bool                    success         = (pDevice != nil);
        
        if (success)
        {
            matchingDict    = IOServiceMatching (kIOHIDDeviceKey);
            success         = matchingDict != nil;
        }
        
        if (success)
        {
            cfType = IOHIDDeviceGetProperty (pDevice, CFSTR (kIOHIDLocationIDKey));
            success = (cfType != nil);
        }

        if (success)
        {
            CFDictionaryAddValue (matchingDict, CFSTR (kIOHIDLocationIDKey), cfType);
            CFRelease (cfType);
            
            mIoService = IOServiceGetMatchingService (kIOMasterPortDefault, matchingDict);
            success    = (mIoService != 0);
        }
        
        if (success)
        {
            success = (FFIsForceFeedback (mIoService) == FF_OK);
        }
        
        if (success)
        {
            success = (FFCreateDevice (mIoService, &mpDevice) == FF_OK);
        }
        
        if (success)
        {
            success = (FFDeviceGetForceFeedbackCapabilities(mpDevice, &features) == FF_OK);
        }
        
        if (success)
        {
            success = ((features.supportedEffects & FFCAP_ET_SINE) == FFCAP_ET_SINE);
        }

        if (success)
        {
            success = (features.subType == FFCAP_ST_VIBRATION);
        }
        
        if (success)
        {
            success = (FFDeviceSendForceFeedbackCommand (mpDevice, FFSFFC_RESET) == FF_OK);
        }
        
        if (success)
        {
            success = (FFDeviceSendForceFeedbackCommand  (mpDevice, FFSFFC_SETACTUATORSON) == FF_OK);
        }
        
        if (success)
        {
            FFDeviceSetForceFeedbackProperty (mpDevice, FFPROP_AUTOCENTER, &autocenter);
        }
        
        if (success)
        {
            success = (FFDeviceSetForceFeedbackProperty (mpDevice, FFPROP_FFGAIN, &gain) == FF_OK);
        }
        
        if (success)
        {
            for (NSUInteger i = 0; i < FD_SIZE_OF_ARRAY (features.ffAxes); ++i)
            {
                mEffectAxes[i] = features.ffAxes[i];
            }
            
            mEffectParams.dwSize                    = sizeof (FFEFFECT);
            mEffectParams.dwFlags                   = FFEFF_OBJECTOFFSETS | FFEFF_SPHERICAL;
            mEffectParams.dwDuration                = FF_INFINITE;
            mEffectParams.dwSamplePeriod            = 0;
            mEffectParams.dwGain                    = FF_FFNOMINALMAX;
            mEffectParams.dwTriggerButton           = FFEB_NOTRIGGER;
            mEffectParams.dwTriggerRepeatInterval   = 0;
            mEffectParams.cAxes                     = features.numFfAxes;
            mEffectParams.rgdwAxes                  = &(mEffectAxes[0]);
            mEffectParams.rglDirection              = &(mEffectDirection[0]);
            mEffectParams.lpEnvelope                = &mEffectEnvelope;
            mEffectParams.cbTypeSpecificParams      = sizeof (FFPERIODIC);
            mEffectParams.lpvTypeSpecificParams     = &mEffectPeriodic;
            mEffectParams.dwStartDelay              = 0;
            
            mEffectPeriodic.dwMagnitude             = 8 * FF_FFNOMINALMAX / 10;
            mEffectPeriodic.lOffset                 = 0;
            mEffectPeriodic.dwPhase                 = 0;
            mEffectPeriodic.dwPeriod                = sFDHIDActuatorDuration;
            
            mEffectEnvelope.dwSize                  = sizeof (FFENVELOPE); 
            mEffectEnvelope.dwAttackLevel           = 8 * FF_FFNOMINALMAX / 10;
            mEffectEnvelope.dwAttackTime            = 0 * FF_SECONDS;
            mEffectEnvelope.dwFadeLevel             = 8 * FF_FFNOMINALMAX / 10;
            mEffectEnvelope.dwFadeTime              = 0 * FF_SECONDS;

            mEffectDirection[0]                     = 270 * FF_DEGREES;
            mEffectDirection[1]                     = 0 * FF_DEGREES;
            
            success = (FFDeviceCreateEffect (mpDevice, kFFEffectType_Sine_ID, &mEffectParams, &mpEffect) == FF_OK);
        }
        
        if (success)
        {
            success = (mpEffect != NULL);
        }
        
        if (success)
        {
            const HRESULT result = FFEffectDownload (mpEffect);
            
            success = ((result == FF_OK) || (result == S_FALSE));
        }
        
        if (success)
        {
            FDLog (@"%@ has an actuator!\n", [device productName]);
        }
        
        if (!success)
        {
            [self release];
            self = nil;
        }
    }
    
    return self;
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) dealloc
{
    if (mpDevice)
    {
        if (mpEffect)
        {
            FFDeviceReleaseEffect (mpDevice, mpEffect);
        }
        
        FFReleaseDevice (mpDevice);
    }
    
    if (mIoService)
    {
        IOObjectRelease (mIoService);
    }
    
    [super dealloc];
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) setIntensity: (float) intensity
{
    if (intensity < 0.0f)
    {
        intensity = 0.0f;
    }
    else if (intensity > 1.0f)
    {
        intensity = 1.0f;
    }
    
    const DWORD newGain = (DWORD) (intensity * ((float) FF_FFNOMINALMAX));
    
    if (newGain != mEffectParams.dwGain)
    {
        mEffectParams.dwGain = newGain;
        
        FFEffectSetParameters (mpEffect, &mEffectParams, FFEP_GAIN);
    }
}

//----------------------------------------------------------------------------------------------------------------------------

- (float) intensity
{
    return ((float) mEffectParams.dwGain) / ((float) FF_FFNOMINALMAX);
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) setDuration: (float) duration
{
    if (duration < 0.0f)
    {
        duration = 0.0f;
    }
    
    const DWORD newDuration = ((DWORD) (0.1f * duration * ((float) FF_SECONDS)));
    
    if (newDuration != mEffectParams.dwDuration)
    {
        mEffectParams.dwDuration = newDuration;
        mEffectPeriodic.dwPeriod = newDuration;
        
        FFEffectSetParameters (mpEffect, &mEffectParams, FFEP_DURATION | FFEP_TYPESPECIFICPARAMS);
    }
}

//----------------------------------------------------------------------------------------------------------------------------

- (float) duration
{
    return ((float) mEffectPeriodic.dwPeriod) / ((float) FF_SECONDS);
}

//----------------------------------------------------------------------------------------------------------------------------

- (BOOL) isActive
{
    FFEffectStatusFlag flag = FFEGES_NOTPLAYING;  
    
    FFEffectGetEffectStatus (mpEffect, &flag);
    
    return flag == FFEGES_PLAYING;
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) start
{
    FFEffectStart (mpEffect, 1 /* FF_INFINITE */, 0 /* FFES_SOLO */);
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) stop
{
    FFEffectStop (mpEffect);
}

@end

//----------------------------------------------------------------------------------------------------------------------------

@implementation FDHIDActuator

+ (id) allocWithZone: (NSZone*) zone
{
    return NSAllocateObject ([_FDHIDActuator class], 0, zone);
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) setIntensity: (float) intensity;
{
    FD_UNUSED (intensity);
    
    [self doesNotRecognizeSelector: _cmd];
}

//----------------------------------------------------------------------------------------------------------------------------

- (float) intensity
{
    [self doesNotRecognizeSelector: _cmd];
    
    return 0.0f;
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) setDuration: (float) duration
{
    FD_UNUSED (duration);
    
    [self doesNotRecognizeSelector: _cmd];
}

//----------------------------------------------------------------------------------------------------------------------------

- (float) duration
{
    [self doesNotRecognizeSelector: _cmd];
    
    return 0.0f;
}

//----------------------------------------------------------------------------------------------------------------------------

- (BOOL) isActive
{
    [self doesNotRecognizeSelector: _cmd];
    
    return NO;
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) start
{
    [self doesNotRecognizeSelector: _cmd];
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) stop
{
    [self doesNotRecognizeSelector: _cmd];
}

@end

//----------------------------------------------------------------------------------------------------------------------------
