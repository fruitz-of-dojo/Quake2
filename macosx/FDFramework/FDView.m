//----------------------------------------------------------------------------------------------------------------------------
//
// "FDView.m"
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import "FDView.h"
#import "FDViewInternal.h"
#import "FDWindow.h"
#import "FDDebug.h"

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <OpenGL/glext.h>

//----------------------------------------------------------------------------------------------------------------------------

@interface _FDView : FDView
{
@private
    NSCursor*           mCursor;
    NSOpenGLContext*    mOpenGLContext;
    NSBitmapImageRep*   mBitmapRep;
    FDResizeHandler     mpResizeHandler;
    void*               mpResizeContext;
    GLuint              mBitmapTexture;
    GLuint              mGrowBoxTexture;
    BOOL                mGrowBoxIsInitialized;
}

- (void) initGrowBoxTexture;
- (void) drawGrowbox;

- (void) setOpenGLContext: (NSOpenGLContext*) openGLContext;

- (void) setResizeHandler: (FDResizeHandler) pResizeHandler forContext: (void*) pContext;
- (void) onResizeView: (NSNotification*) notification;

- (NSBitmapImageRep*) bitmapRepresentation;

@end

//----------------------------------------------------------------------------------------------------------------------------

@implementation _FDView

- (id)initWithFrame:(NSRect) frameRect
{
    self = [super initWithFrame: frameRect];
    
    if (self != nil)
    {
        mCursor = [[NSCursor crosshairCursor] retain];
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector (onResizeView:)
                                                     name: NSViewGlobalFrameDidChangeNotification
                                                   object: self];
    }
    
    return self;
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: NSViewGlobalFrameDidChangeNotification
                                                  object: self];    
    
    [self setOpenGLContext: nil];
    [mBitmapRep release];
    
    [super dealloc];
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) initGrowBoxTexture
{
    if (mOpenGLContext != nil)
    {
        GLint   unpackAlignment = 0;
        GLint   unpackRowLength = 0;
        
        [mOpenGLContext makeCurrentContext];
        
        glGetIntegerv (GL_UNPACK_ALIGNMENT, &unpackAlignment);
        glGetIntegerv (GL_UNPACK_ROW_LENGTH, &unpackRowLength);
        
        glPixelStorei (GL_UNPACK_ALIGNMENT, 1);
        glPixelStorei (GL_UNPACK_ROW_LENGTH, (GLint) skFDGrowBoxWidth);
        
        glGenTextures (1, &mGrowBoxTexture);
        glBindTexture (GL_TEXTURE_2D, mGrowBoxTexture);	
        glTexImage2D  (GL_TEXTURE_2D, 0, GL_RGBA, skFDGrowBoxWidth, skFDGrowBoxHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE,
                       &(skFDGrowBoxBitmap[0]));
        
        glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri (GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri (GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        
        glPixelStorei (GL_UNPACK_ALIGNMENT, unpackAlignment);
        glPixelStorei (GL_UNPACK_ROW_LENGTH, unpackRowLength);
        
        mGrowBoxIsInitialized = YES;
    }
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) setResizeHandler: (FDResizeHandler) pResizeHandler forContext: (void*) pContext
{
    mpResizeHandler = pResizeHandler;
    mpResizeContext = pContext;
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) setCursor: (NSCursor*) cursor
{
    if (mCursor != cursor)
    {
        [mCursor release];
        
        if (cursor == nil)
        {
            cursor = [NSCursor arrowCursor];
        }
        
        mCursor = [cursor retain];
        
        [[self window] invalidateCursorRectsForView: self];
    }
}

//----------------------------------------------------------------------------------------------------------------------------

- (NSCursor*) cursor
{
    return mCursor;
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) resetCursorRects
{
    [self addCursorRect: [self bounds] cursor: [self cursor]];
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) setVsync: (BOOL) enabled
{
    if (mOpenGLContext != nil)
    {
        const GLint param = (enabled == YES) ? 1 : 0;
        
        [mOpenGLContext makeCurrentContext];
        
        if (CGLSetParameter (CGLGetCurrentContext (), kCGLCPSwapInterval, &param) != CGDisplayNoErr)
        {
            FDLog (@"Failed to set CGL swap interval");
        }
    }
}

//----------------------------------------------------------------------------------------------------------------------------

- (BOOL) vsync
{
    BOOL isEnabled = NO;
    
    if (mOpenGLContext != nil)
    {
        GLint param = 0;
        
        [mOpenGLContext makeCurrentContext];
        
        if (CGLGetParameter (CGLGetCurrentContext (), kCGLCPSwapInterval, &param) == CGDisplayNoErr)
        {
            isEnabled = (param != 0);
        }
    }
    
    return isEnabled;
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) setOpenGLContext: (NSOpenGLContext*) openGLContext
{
    if (mOpenGLContext != nil)
    {
        [mOpenGLContext makeCurrentContext];
        
        if (mGrowBoxIsInitialized == YES)
        {
            glDeleteTextures( 1, &mGrowBoxTexture );
            mGrowBoxIsInitialized = NO;
        }
        
        [NSOpenGLContext clearCurrentContext];
        [mOpenGLContext clearDrawable];
        [mOpenGLContext release];
        
        mOpenGLContext = nil;
    }    
    
    if (openGLContext != nil)
    {
        [openGLContext setView: self];
        
        mOpenGLContext = [openGLContext retain];
    }
}

//----------------------------------------------------------------------------------------------------------------------------

- (NSOpenGLContext*) openGLContext
{
    return mOpenGLContext;
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) onResizeView: (NSNotification*) notification
{
    if (mOpenGLContext != nil)
    {
        [mOpenGLContext update];
        
        if (mpResizeHandler != nil)
        {
            (*mpResizeHandler) (self, mpResizeContext);
        }
        else
        {
            FDLog (@"Warning: no resize handler registered with FDView!");
        }
    }
}

//----------------------------------------------------------------------------------------------------------------------------

- (NSBitmapImageRep*) bitmapRepresentation
{
    const NSRect      frame   = [self frame];
    const NSUInteger  width   = NSWidth (frame);
    const NSUInteger  height  = NSHeight (frame);
    
    if ((mBitmapRep == nil) || ([mBitmapRep pixelsWide] != width) || ([mBitmapRep pixelsHigh] != height))
    {
        [mBitmapRep release];
        
        mBitmapRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                                              pixelsWide: width
                                                              pixelsHigh: height
                                                           bitsPerSample: 8
                                                         samplesPerPixel: 4
                                                                hasAlpha: YES
                                                                isPlanar: NO
                                                          colorSpaceName: NSDeviceRGBColorSpace
                                                             bytesPerRow: width << 2
                                                            bitsPerPixel: 32];
    }
    
    if ((mBitmapRep != nil) && (mOpenGLContext != nil))
    {
        UInt8*	pBitmapBuffer = (UInt8*) [mBitmapRep bitmapData];
        
        if (pBitmapBuffer != NULL)
        {
            const UInt8*	pBitmapBufferEnd = pBitmapBuffer + (width << 2) * height;
            
            CGLFlushDrawable ([mOpenGLContext CGLContextObj]);
            
            glReadPixels (0, 0, (GLsizei) width, (GLsizei) height, GL_RGBA, GL_UNSIGNED_BYTE, pBitmapBuffer);
            
            pBitmapBuffer += 3;
            
            while (pBitmapBuffer < pBitmapBufferEnd)
            {
                *pBitmapBuffer  = 0xFF;
                pBitmapBuffer   += sizeof (UInt32);
            }
        }
    }
    
    return mBitmapRep;
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) drawGrowbox
{
    if (mOpenGLContext != nil)
    {
        const NSRect    rect    = [self frame];
        const CGFloat   width   = NSWidth (rect);
        const CGFloat   height  = NSHeight (rect);
        
        [mOpenGLContext makeCurrentContext];
        
        if (mGrowBoxIsInitialized == NO)
        {
            [self initGrowBoxTexture];
        }
        
        glPushMatrix ();
        
        glMatrixMode (GL_PROJECTION);
        glPushMatrix ();	
        glLoadIdentity ();
        glOrtho (0.0,  width, 0.0, height, -1.0, 1.0);
        
        glMatrixMode (GL_TEXTURE);
        glPushMatrix ();
        
        glMatrixMode (GL_MODELVIEW);
        glLoadIdentity ();

        glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glEnable (GL_BLEND);

        glBindTexture (GL_TEXTURE_2D, mGrowBoxTexture);
        glEnable (GL_TEXTURE_2D);
        
        glColor4f (1.0f, 1.0f, 1.0f, 1.0f);
        
        glBegin (GL_TRIANGLE_STRIP);
            glTexCoord2f (0.0f, 0.0f);
            glVertex2i (((GLint) width) - skFDGrowBoxWidth, 0);
            
            glTexCoord2f (1.0f, 0.0f);
            glVertex2i ((GLint) width, 0);
            
            glTexCoord2f (0.0f, 1.0f);
            glVertex2i (((GLint) width) - skFDGrowBoxWidth, skFDGrowBoxHeight);
            
            glTexCoord2f (1.0f, 1.0f);
            glVertex2i ((GLint) width, skFDGrowBoxHeight);
        glEnd ();
        
        glDisable (GL_BLEND);
        
        glMatrixMode (GL_PROJECTION);
        glPopMatrix ();
        
        glMatrixMode (GL_TEXTURE);
        glPopMatrix ();
        
        glMatrixMode (GL_MODELVIEW);
        glPopMatrix ();
    }
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) drawRect: (NSRect) theRect
{
}

@end

//----------------------------------------------------------------------------------------------------------------------------

@implementation FDView

+ (id) allocWithZone: (NSZone*) zone
{
    return NSAllocateObject ([_FDView class], 0, zone);
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

//----------------------------------------------------------------------------------------------------------------------------

- (id) initWithFrame: (NSRect) frameRect
{
    self = [super initWithFrame: frameRect];
    
    return self;
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) setCursor: (NSCursor*) cursor
{
    FD_UNUSED (cursor);
    
    [self doesNotRecognizeSelector: _cmd];
}

//----------------------------------------------------------------------------------------------------------------------------

- (NSCursor*) cursor
{
    [self doesNotRecognizeSelector: _cmd];
    
    return nil;
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) setVsync: (BOOL) enabled
{
    FD_UNUSED (enabled);
    
    [self doesNotRecognizeSelector: _cmd];
}

//----------------------------------------------------------------------------------------------------------------------------

- (BOOL) vsync
{
    [self doesNotRecognizeSelector: _cmd];
    
    return NO;
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) setResizeHandler: (FDResizeHandler) pResizeHandler forContext: (void*) pContext
{
    FD_UNUSED (pResizeHandler, pContext);
    
    [self doesNotRecognizeSelector: _cmd];
}

//----------------------------------------------------------------------------------------------------------------------------

- (NSOpenGLContext*) openGLContext
{
    [self doesNotRecognizeSelector: _cmd];
    
    return nil;
}

@end

//----------------------------------------------------------------------------------------------------------------------------
