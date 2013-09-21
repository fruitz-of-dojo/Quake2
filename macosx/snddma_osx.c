//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "snddma_osx.c" - MacOS X Sound driver.
//
// Written by:	awe                         [mailto:awe@fruitz-of-dojo.de].
//		        ©2001-2006 Fruitz Of Dojo   [http://www.fruitz-of-dojo.de].
//
// Quake IIª is copyrighted by id software  [http://www.idsoftware.com].
//
// Version History:
// v1.0.4: Improved sound playback if sound quality is set to "low" [propper unsigned to signed PCM conversion].
// v1.0.0: Initial release.
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#include <CoreAudio/AudioHardware.h>

#include "client.h"
#include "snd_loc.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Defines

#define OUTPUT_BUFFER_SIZE	(4 * 1024)
#define TOTAL_BUFFER_SIZE	(64 * 1024)
#define NO 			0
#define	YES			1

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark TypeDefs

typedef int				SInt;
typedef unsigned int	UInt;

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Variables

AudioDeviceID						gSNDDMASoundDeviceID;

static volatile Boolean				gSNDDMAIOProcIsInstalled = NO;
static unsigned char				gSNDDMABuffer[TOTAL_BUFFER_SIZE];
static UInt32						gSNDDMABufferPosition;
static UInt32						gSNDDMABufferByteCount;
static AudioStreamBasicDescription	gSNDDMABasicDescription;
static OSStatus						(*SNDDMA_AudioIOProc)(AudioDeviceID, const AudioTimeStamp *, const AudioBufferList *, const AudioTimeStamp *,
														  AudioBufferList *, const AudioTimeStamp *, void *);

#pragma mark -
                                                             
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Function Prototypes

static OSStatus SNDDMA_Audio8BitIOProc (AudioDeviceID, const AudioTimeStamp *, const AudioBufferList *, const AudioTimeStamp *, AudioBufferList *,
										const AudioTimeStamp *, void *);
static OSStatus SNDDMA_Audio16BitIOProc (AudioDeviceID, const AudioTimeStamp *, const AudioBufferList *, const AudioTimeStamp *, AudioBufferList *,
										 const AudioTimeStamp *, void *);

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

static OSStatus SNDDMA_Audio8BitIOProc (AudioDeviceID inDevice,
                                         const AudioTimeStamp *inNow,
                                         const AudioBufferList *inInputData,
                                         const AudioTimeStamp *inInputTime,
                                         AudioBufferList *outOutputData, 
                                         const AudioTimeStamp *inOutputTime,
                                         void *inClientData)
{
    // fixes a rare crash on app exit (race condition in CoreAudio?):
    if (gSNDDMAIOProcIsInstalled == YES)
    {
		UInt8 *		myDMA		= ((UInt8 *) gSNDDMABuffer) + gSNDDMABufferPosition / (dma.samplebits >> 3);		
		float *		myOutBuffer	= (float *) outOutputData->mBuffers[0].mData;
		UInt16		i			= 0;
		
		// convert the buffer from unsigned PCM to signed PCM and last not least to float, required by CoreAudio:
		for (; i < gSNDDMABufferByteCount; ++i)
		{
			*myOutBuffer++	= ((float) *myDMA - 128.0f) * (1.0f / 128.0f);
			*myDMA++		= 0x80;
		}
		
		// increase the bufferposition:
		gSNDDMABufferPosition += gSNDDMABufferByteCount * (dma.samplebits >> 3);
	   
		 if (gSNDDMABufferPosition >= sizeof (gSNDDMABuffer))
		{
			gSNDDMABufferPosition = 0;
		}
	}
	
    // return 0 = no error:
    return 0;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

static OSStatus SNDDMA_Audio16BitIOProc (AudioDeviceID inDevice,
                                         const AudioTimeStamp *inNow,
                                         const AudioBufferList *inInputData,
                                         const AudioTimeStamp *inInputTime,
                                         AudioBufferList *outOutputData, 
                                         const AudioTimeStamp *inOutputTime,
                                         void *inClientData)
{
	float *		myOutBuffer	= (float *) outOutputData->mBuffers[0].mData;
	UInt16		i			= 0;
	
    // fixes a rare crash on app exit:
    if (gSNDDMAIOProcIsInstalled == YES)
    {
		short *		myDMA = ((short *) gSNDDMABuffer) + gSNDDMABufferPosition / (dma.samplebits >> 3);
		
		// convert the buffer to float, required by CoreAudio:
		for (; i < gSNDDMABufferByteCount; i++)
		{
			*myOutBuffer++	= (*myDMA) * (1.0f / 32768.0f);
			*myDMA++		= 0x0000;
		}
		
		// increase the bufferposition:
		gSNDDMABufferPosition += gSNDDMABufferByteCount * (dma.samplebits >> 3);

		if (gSNDDMABufferPosition >= sizeof (gSNDDMABuffer))
		{
			gSNDDMABufferPosition = 0;
		}
	}
	else
	{
		for (; i < gSNDDMABufferByteCount; ++i)
		{
			*myOutBuffer++ = 0.0f;
		}
	}
			
    // return 0 = no error:
    return (0);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

qboolean	SNDDMA_ReserveBufferSize (void)
{
    // this function has to be called before any QuickTime movie data is loaded, so that the QuickTime handler knows about our custom buffersize!

	AudioDeviceID	myAudioDevice;
    UInt32			myPropertySize	= sizeof (AudioDeviceID);
    OSStatus		myError			= AudioHardwareGetProperty (kAudioHardwarePropertyDefaultOutputDevice, &myPropertySize, &myAudioDevice);
    
    if (!myError && myAudioDevice != kAudioDeviceUnknown)
    {
        UInt32		myBufferByteCount = OUTPUT_BUFFER_SIZE * sizeof (float);

        myPropertySize = sizeof (myBufferByteCount);

        // set the buffersize for the audio device:
        myError = AudioDeviceSetProperty (myAudioDevice, NULL, 0, NO, kAudioDevicePropertyBufferSize, myPropertySize, &myBufferByteCount);
    }
    
    return !myError;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

qboolean SNDDMA_Init (void)
{
    UInt32	myPropertySize;

    // check sample bits:
    s_loadas8bit = Cvar_Get("s_loadas8bit", "16", CVAR_ARCHIVE);
	
    if ((int) s_loadas8bit->value)
    {
		dma.samplebits = 8;
        SNDDMA_AudioIOProc = SNDDMA_Audio8BitIOProc;
    }
    else
    {
		dma.samplebits = 16;
        SNDDMA_AudioIOProc = SNDDMA_Audio16BitIOProc;
    }

    myPropertySize = sizeof (gSNDDMASoundDeviceID);
            
    // find a suitable audio device:
    if (AudioHardwareGetProperty (kAudioHardwarePropertyDefaultOutputDevice, &myPropertySize, &gSNDDMASoundDeviceID))
    {
        Com_Printf ("Audio init fails: Can\'t get audio device.\n");
        return 0;
    }
    
    // is the device valid?
    if (gSNDDMASoundDeviceID == kAudioDeviceUnknown)
    {
        Com_Printf ("Audio init fails: Unsupported audio device.\n");
        return 0;
    }
    
    // get the buffersize of the audio device [must previously be set via "SNDDMA_ReserveBufferSize ()"]:
    myPropertySize = sizeof (gSNDDMABufferByteCount);
    if (AudioDeviceGetProperty (gSNDDMASoundDeviceID, 0, NO, kAudioDevicePropertyBufferSize, &myPropertySize, &gSNDDMABufferByteCount) || gSNDDMABufferByteCount == 0)
    {
        Com_Printf ("Audio init fails: Can't get audiobuffer.\n");
        return 0;
    }
    
    //check the buffersize:
    gSNDDMABufferByteCount /= sizeof (float);
	
    if (gSNDDMABufferByteCount != OUTPUT_BUFFER_SIZE)
    {
        Com_Printf ("Audio init: Audiobuffer size is not sufficient for clean movie playback!\n");
    }
	
    if (sizeof (gSNDDMABuffer) % gSNDDMABufferByteCount != 0 || sizeof (gSNDDMABuffer) / gSNDDMABufferByteCount < 2)
    {
        Com_Printf ("Audio init: Bad audiobuffer size!\n");
        return 0;
    }
    
    // get the audiostream format:
    myPropertySize = sizeof (gSNDDMABasicDescription);
	
    if (AudioDeviceGetProperty (gSNDDMASoundDeviceID, 0, NO, kAudioDevicePropertyStreamFormat, &myPropertySize, &gSNDDMABasicDescription))
    {
        Com_Printf ("Audio init fails.\n");
        return 0;
    }
    
    // is the format LinearPCM?
    if (gSNDDMABasicDescription.mFormatID != kAudioFormatLinearPCM)
    {
        Com_Printf ("Default Audio Device doesn't support Linear PCM!\n");
        return 0;
    }
    
    // is sound ouput suppressed?
    if (!COM_CheckParm ("-nosound"))
    {
		gSNDDMAIOProcIsInstalled = YES;
		
        // add the sound FX IO:
        if (AudioDeviceAddIOProc (gSNDDMASoundDeviceID, SNDDMA_AudioIOProc, NULL))
        {
			gSNDDMAIOProcIsInstalled = NO;
            Com_Printf ("Audio init fails: Can\'t install IOProc.\n");
            return 0;
        }
        
        // start the sound FX:
        if (AudioDeviceStart (gSNDDMASoundDeviceID, SNDDMA_AudioIOProc))
        {
			gSNDDMAIOProcIsInstalled = NO;
            Com_Printf ("Audio init fails: Can\'t start audio.\n");
            return 0;
        }
    }
    else
    {
        gSNDDMAIOProcIsInstalled = NO;
    }
    
    // setup Quake sound variables:
    dma.speed				= gSNDDMABasicDescription.mSampleRate;
    dma.channels			= gSNDDMABasicDescription.mChannelsPerFrame;
    dma.samples				= sizeof (gSNDDMABuffer) / (dma.samplebits >> 3);
    dma.samplepos			= 0;
    dma.submission_chunk	= gSNDDMABufferByteCount;
    dma.buffer				= gSNDDMABuffer;
    gSNDDMABufferPosition	= 0;

    return 1;
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	SNDDMA_Shutdown (void)
{
    // shut everything down:
    if (gSNDDMAIOProcIsInstalled == YES)
    {
		gSNDDMAIOProcIsInstalled = NO;
		
        AudioDeviceStop (gSNDDMASoundDeviceID, SNDDMA_AudioIOProc);
        AudioDeviceRemoveIOProc (gSNDDMASoundDeviceID, SNDDMA_AudioIOProc);
    }
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

int	SNDDMA_GetDMAPos (void)
{
    return gSNDDMAIOProcIsInstalled == NO ? 0 : gSNDDMABufferPosition / (dma.samplebits >> 3);
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	SNDDMA_Submit (void)
{
    // not required!
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------

void	SNDDMA_BeginPainting (void)
{
    // not required!
}

//------------------------------------------------------------------------------------------------------------------------------------------------------------
