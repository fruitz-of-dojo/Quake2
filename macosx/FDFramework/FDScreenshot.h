//----------------------------------------------------------------------------------------------------------------------------
//
// "FDScreenshot.h" - Save screenshots (raw bitmap data) to various image formats.
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

//----------------------------------------------------------------------------------------------------------------------------

@interface FDScreenshot : NSObject
{
}

+ (BOOL) writeToFile: (NSString*) path
              ofType: (NSBitmapImageFileType) fileType
           fromRGB24: (void*) imageData
            withSize: (NSSize) imageSize
            rowbytes: (SInt32) rowbytes;

+ (BOOL) writeToBMP: (NSString*) path
          fromRGB24: (void*) imageData
           withSize: (NSSize) imageSize
           rowbytes: (SInt32) rowbytes;

+ (BOOL) writeToGIF: (NSString*) path
          fromRGB24: (void*) imageData
           withSize: (NSSize) imageSize
           rowbytes: (SInt32) rowbytes;

+ (BOOL) writeToJPEG: (NSString*) path
           fromRGB24: (void*) imageData
            withSize: (NSSize) imageSize
            rowbytes: (SInt32) rowbytes;

+ (BOOL) writeToPNG: (NSString*) path
          fromRGB24: (void*) imageData
           withSize: (NSSize) imageSize
           rowbytes: (SInt32) rowbytes;

+ (BOOL) writeToTIFF: (NSString*) path
           fromRGB24: (void*) imageData
            withSize: (NSSize) imageSize
            rowbytes: (SInt32) rowbytes;

@end

//----------------------------------------------------------------------------------------------------------------------------
