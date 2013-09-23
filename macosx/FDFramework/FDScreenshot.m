//----------------------------------------------------------------------------------------------------------------------------
//
// "FDScreenshot.m" - Save screenshots (raw bitmap data) to various image formats.
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import "FDScreenshot.h"

//----------------------------------------------------------------------------------------------------------------------------

@interface FDScreenshot ()

+ (NSBitmapImageRep *) imageFromRGB24: (void *) imageData withSize: (NSSize) imageSize rowbytes: (SInt32) rowBytes;
- (id) init;

@end

//----------------------------------------------------------------------------------------------------------------------------

@implementation FDScreenshot

+ (NSBitmapImageRep *) imageFromRGB24: (void*) pImageData withSize: (NSSize) imageSize rowbytes: (SInt32) rowBytes
{
    UInt8*  bitmapPlanes[5] = {(UInt8*) pImageData, nil, nil, nil, nil};
    
    return [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: bitmapPlanes
                                                    pixelsWide: imageSize.width
                                                    pixelsHigh: imageSize.height
                                                 bitsPerSample: 8
                                               samplesPerPixel: 3
                                                      hasAlpha: NO
                                                      isPlanar: NO
                                                colorSpaceName: NSDeviceRGBColorSpace
                                                   bytesPerRow: rowBytes
                                                  bitsPerPixel: 24] autorelease];
}

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) writeToFile: (NSString*) path
              ofType: (NSBitmapImageFileType) fileType
           fromRGB24: (void*) pImageData
            withSize: (NSSize) imageSize
            rowbytes: (SInt32) rowbytes
{
    NSBitmapImageRep*	imageRep    = [FDScreenshot imageFromRGB24: pImageData withSize: imageSize rowbytes: rowbytes];
    NSData*             data		= [imageRep representationUsingType: fileType properties: NULL];

    return ([data writeToFile: path atomically: YES]);
}

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) writeToBMP: (NSString*) path
          fromRGB24: (void*) pImageData
           withSize: (NSSize) imageSize
           rowbytes: (SInt32) rowbytes
{
    return ([FDScreenshot writeToFile: path
                               ofType: NSBMPFileType
                            fromRGB24: pImageData
                             withSize: imageSize
                             rowbytes: rowbytes]);
}

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) writeToGIF: (NSString*) path
          fromRGB24: (void*) imageData
           withSize: (NSSize) imageSize
           rowbytes: (SInt32) rowbytes
{
    return ([FDScreenshot writeToFile: path
                               ofType: NSGIFFileType 
                            fromRGB24: imageData
                             withSize: imageSize
                             rowbytes: rowbytes]);
}

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) writeToJPEG: (NSString*) path
           fromRGB24: (void*) pImageData
            withSize: (NSSize) imageSize
            rowbytes: (SInt32) rowbytes
{
    return ([FDScreenshot writeToFile: path
                               ofType: NSJPEGFileType
                            fromRGB24: pImageData
                             withSize: imageSize
                             rowbytes: rowbytes]);
}

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) writeToPNG: (NSString*) path
          fromRGB24: (void*) pImageData
           withSize: (NSSize) imageSize
           rowbytes: (SInt32) rowbytes
{
    return ([FDScreenshot writeToFile: path
                               ofType: NSPNGFileType
                            fromRGB24: pImageData
                             withSize: imageSize
                             rowbytes: rowbytes]);
}

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) writeToTIFF: (NSString*) path
           fromRGB24: (void*) pImageData
            withSize: (NSSize) imageSize
            rowbytes: (SInt32) rowbytes
{
    return ([FDScreenshot writeToFile: path
                               ofType: NSTIFFFileType
                            fromRGB24: pImageData
                             withSize: imageSize
                             rowbytes: rowbytes]);
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
