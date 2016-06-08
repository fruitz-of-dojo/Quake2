//----------------------------------------------------------------------------------------------------------------------------
//
// "FDAudioFile.h" - Sound file playback.
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import "FDAudioMixer.h"

#import <Cocoa/Cocoa.h>

//----------------------------------------------------------------------------------------------------------------------------

@interface FDAudioFile : NSObject

- (instancetype) initWithMixer: (FDAudioMixer*) mixer;

@property float volume;

- (BOOL) startFile: (NSURL*) url loop: (BOOL) loop;
- (BOOL) stop;

- (void) pause;
- (void) resume;

@property (readonly, getter=isPlaying) BOOL playing;
@property (readonly, getter=isFinished) BOOL finished;
@property (readonly) BOOL loops;

@end

//----------------------------------------------------------------------------------------------------------------------------
