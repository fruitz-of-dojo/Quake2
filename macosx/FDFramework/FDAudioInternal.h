//----------------------------------------------------------------------------------------------------------------------------
//
// "FDAudioInternal.h"
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import "FDAudioMixer.h"

#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>

//----------------------------------------------------------------------------------------------------------------------------

@interface FDAudioMixer ()

- (void) setVolume: (float) volume forBus: (AudioUnitElement) busNumber;
- (float) volumeForBus: (AudioUnitElement) busNumber;

@property (readonly) AUGraph audioGraph;
@property (readonly) AUNode mixerNode;

- (AudioUnitElement) allocateBus;
- (void) deallocateBus: (AudioUnitElement) busNumber;

- (void) addObserver: (id) object;
- (void) removeObserver: (id) object;

@end

//----------------------------------------------------------------------------------------------------------------------------
