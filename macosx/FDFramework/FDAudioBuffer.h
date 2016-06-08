//----------------------------------------------------------------------------------------------------------------------------
//
// "FDAudioBuffer.h" - Audio buffer playback.
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import "FDAudioMixer.h"

#import <Cocoa/Cocoa.h>

//----------------------------------------------------------------------------------------------------------------------------

typedef NSUInteger (*FDAudioBufferCallback) (void* pDst, NSUInteger numBytes, void* pContext);

//----------------------------------------------------------------------------------------------------------------------------

@interface FDAudioBuffer : NSObject

- (instancetype) initWithMixer: (FDAudioMixer*) mixer
                     frequency: (NSUInteger) frequency
                bitsPerChannel: (NSUInteger) bitsPerChannel
                      channels: (NSUInteger) channels
                      callback: (FDAudioBufferCallback) pCallback
                       context: (void*) pContext;

@property float volume;

@end

//----------------------------------------------------------------------------------------------------------------------------
