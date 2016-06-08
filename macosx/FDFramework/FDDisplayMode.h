//----------------------------------------------------------------------------------------------------------------------------
//
// "FDDisplayMode.h"
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>

//----------------------------------------------------------------------------------------------------------------------------

@interface FDDisplayMode : NSObject

@property (readonly) NSUInteger width;
@property (readonly) NSUInteger height;
@property (readonly) NSUInteger bitsPerPixel;
@property (readonly, getter=isStretched) BOOL stretched;
@property (readonly, getter=isDefault) BOOL isDefault;
@property (readonly) double refreshRate;

- (NSString*) description;

- (BOOL) isEqualTo: (FDDisplayMode*) object;
- (NSComparisonResult) compare: (FDDisplayMode*) rhs;

@end

//----------------------------------------------------------------------------------------------------------------------------
