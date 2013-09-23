//----------------------------------------------------------------------------------------------------------------------------
//
// "FDGLScreenshot.m" - Save screenshots (of the current OpenGL context) to various image formats.
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import "FDGLScreenshot.h"

#import <OpenGL/gl.h>

//----------------------------------------------------------------------------------------------------------------------------

@implementation FDGLScreenshot

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) writeToFile: (NSString*) path ofType: (NSBitmapImageFileType) fileType
{
    GLint   viewport[4];
    BOOL    success = NO;
    
    // get the window dimensions of the current OpenGL context:
    glGetIntegerv (GL_VIEWPORT, &(viewport[0]));
    
    if (viewport[2] > 0 && viewport[3] > 0)
    {
        const UInt32	width		= viewport[2];
        const UInt32    height      = viewport[3];
        const UInt32    rowbytes	= width * 3;
        UInt32          i           = 0;
        UInt8*          pBuffer     = nil;
        UInt8*          pBottom     = nil;
        UInt8*          pTop		= nil;

        // get memory to cache the current OpenGL scene:
        pBuffer = (UInt8 *) malloc (rowbytes * height);
        
        if (pBuffer != nil)
        {
            // copy the current OpenGL context to memory:
            glReadPixels (viewport[0], viewport[1], width, height, GL_RGB, GL_UNSIGNED_BYTE, pBuffer);
        
            // mirror the buffer [only vertical]:
            pTop    = pBuffer;
            pBottom = pBuffer + rowbytes * (height - 1);
            
            while (pTop < pBottom)
            {
                for (i = 0; i < rowbytes; i++)
                {
                    UInt8   tmp = pTop[i];
                    
                    pTop[i]     = pBottom[i];
                    pBottom[i]  = tmp;
                }
                
                pTop    += rowbytes;
                pBottom -= rowbytes;
            }
            
            // write the file:
            success = [FDGLScreenshot writeToFile: path
                                           ofType: fileType
                                        fromRGB24: pBuffer
                                         withSize: NSMakeSize ((float) width, (float) height)
                                         rowbytes: rowbytes];

            // get rid of the buffer:
            free (pBuffer);
        }
    }
    
    return success;
}

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) writeToBMP: (NSString*) path
{
    return [FDGLScreenshot writeToFile: path ofType: NSBMPFileType];
}

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) writeToGIF: (NSString*) path
{
    return [FDGLScreenshot writeToFile: path ofType: NSGIFFileType];
}

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) writeToJPEG: (NSString*) path
{
    return [FDGLScreenshot writeToFile: path ofType: NSJPEGFileType];
}

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) writeToPNG: (NSString*) path
{
    return [FDGLScreenshot writeToFile: path ofType: NSPNGFileType];
}

//----------------------------------------------------------------------------------------------------------------------------

+ (BOOL) writeToTIFF: (NSString*) path
{
    return [FDGLScreenshot writeToFile: path ofType: NSTIFFFileType];
}

@end

//----------------------------------------------------------------------------------------------------------------------------
