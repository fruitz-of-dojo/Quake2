//----------------------------------------------------------------------------------------------------------------------------
//
// "snddma_osx.m" - MacOS X Sound driver.
//
// Written by:	Axel 'awe' Wefers           [mailto:awe@fruitz-of-dojo.de].
//              ©2001-2013 Fruitz Of Dojo   [http://www.fruitz-of-dojo.de].
//
// Quakeª is copyrighted by id software     [http://www.idsoftware.com].
//
// Version History:
// v1.2.0: Rewritten. Uses now AudioGraph/AudioUnit.
// v1.0.4: Improved sound playback if sound quality is set to "low" [propper unsigned to signed PCM conversion].
// v1.0.0: Initial release.
//
//----------------------------------------------------------------------------------------------------------------------------

#import "FDFramework/FDFramework.h"

#include "client.h"
#include "snd_loc.h"

//----------------------------------------------------------------------------------------------------------------------------

static FDAudioBuffer*   sSndAudioBuffer         = nil;
static UInt8            sSndBuffer[64*1024]     = { 0 };
static UInt32			sSndBufferPosition      = 0;
static const UInt32     skSndBufferByteCount    = 4 * 1024;

//----------------------------------------------------------------------------------------------------------------------------

static NSUInteger SNDDMA_Callback (void* pDst, NSUInteger numBytes, void* pContext);

//----------------------------------------------------------------------------------------------------------------------------

NSUInteger SNDDMA_Callback (void* pDst, NSUInteger numBytes, void* pContext)
{
    while (numBytes)
    {
        if (sSndBufferPosition >= FD_SIZE_OF_ARRAY (sSndBuffer))
        {
            sSndBufferPosition = 0;
        }
        
        NSUInteger toCopy = FD_SIZE_OF_ARRAY (sSndBuffer) - sSndBufferPosition;
        
        if (toCopy > numBytes)
        {
            toCopy = numBytes;
        }
        
        FD_MEMCPY (pDst, &(sSndBuffer[sSndBufferPosition]), toCopy);
        
        pDst                += toCopy;
        numBytes            -= toCopy;
        sSndBufferPosition  += toCopy;
    }
    
    return 0;
}

//----------------------------------------------------------------------------------------------------------------------------

qboolean SNDDMA_Init (void)
{
    qboolean        success         = true;
    UInt32          bitsPerChannel  = 16;
    UInt32          sampleRate      = 44100;
    const UInt32    kNumChannels    = 2;
    
    s_loadas8bit = Cvar_Get ("s_loadas8bit", "16", CVAR_ARCHIVE);
    
    if ((int) s_loadas8bit->value)
    {
		bitsPerChannel  = 8;
        sampleRate      = 22050;
    }    
    
    FD_MEMSET (&(sSndBuffer[0]), 0, FD_SIZE_OF_ARRAY (sSndBuffer));
    sSndBufferPosition  = 0;
    
    if (!COM_CheckParm ("-nosound"))
    {
        sSndAudioBuffer = [[FDAudioBuffer alloc] initWithMixer: [FDAudioMixer sharedAudioMixer]
                                                     frequency: sampleRate
                                                bitsPerChannel: bitsPerChannel
                                                      channels: kNumChannels
                                                      callback: &SNDDMA_Callback
                                                       context: nil];
        
        success = (sSndAudioBuffer != nil);
        
        if (!success)
        {
            Com_Printf ("Audio init: Failed to initialize!\n");
        }
    }
    
    if (success)
    {
        dma.speed				= sampleRate;
        dma.channels			= kNumChannels;
        dma.samplebits          = bitsPerChannel;
        dma.samples				= sizeof (sSndBuffer) / (dma.samplebits >> 3);
        dma.samplepos			= 0;
        dma.submission_chunk	= skSndBufferByteCount;
        dma.buffer				= sSndBuffer;
        sSndBufferPosition      = 0;
            
        [[FDAudioMixer sharedAudioMixer] start];
    }

    return success;
}

//----------------------------------------------------------------------------------------------------------------------------

void	SNDDMA_Shutdown (void)
{
    [[FDAudioMixer sharedAudioMixer] stop];
    
    [sSndAudioBuffer release];
    sSndAudioBuffer = nil;
}

//----------------------------------------------------------------------------------------------------------------------------

int     SNDDMA_GetDMAPos (void)
{
    int pos = 0;
    
    if (sSndAudioBuffer != nil)
    {
        pos = sSndBufferPosition / (dma.samplebits >> 3);
    }
	
    return pos;
}

//----------------------------------------------------------------------------------------------------------------------------

void	SNDDMA_Submit (void)
{
}

//----------------------------------------------------------------------------------------------------------------------------

void	SNDDMA_BeginPainting (void)
{
}

//----------------------------------------------------------------------------------------------------------------------------
