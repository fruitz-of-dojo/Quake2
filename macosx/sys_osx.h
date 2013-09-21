//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "sys_osx.h"
//
// Written by:	awe                         [mailto:awe@fruitz-of-dojo.de].
//		        ©2001-2006 Fruitz Of Dojo   [http://www.fruitz-of-dojo.de].
//
// Quake IIª is copyrighted by id software  [http://www.idsoftware.com].
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#include "client.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Macros

#define SYS_CHECK_MALLOC(MEM_PTR)		if ((MEM_PTR) == NULL)															\
                                        {																				\
                                            Sys_Error ("Out of memory!");												\
                                        }

#define SYS_CHECK_MOUSE_ENABLED()		if ((vid_fullscreen != NULL && vid_fullscreen->value == 0.0f &&					\
											(_windowed_mouse == NULL ||													\
											(_windowed_mouse != NULL && _windowed_mouse->value == 0.0f))) ||			\
                                            [NSApp isActive] == NO || gSysIsMinimized->value != 0.0f ||					\
                                            (in_mouse == NULL || (in_mouse != NULL && in_mouse->value == 0.0f)))		\
                                        {																				\
                                            return;																		\
                                        }	

#define SYS_Q2_DURING					NS_DURING
#define	SYS_Q2_HANDLER					NS_HANDLER																		\
                                        {																				\
                                            NSString	*myException = [localException reason];							\
																														\
                                            if (myException == NULL)													\
                                            {																			\
                                                myException = @"Unknown exception!";									\
                                            }																			\
                                            NSLog (@"An exception has occured: %@\n", myException);						\
                                            NSRunCriticalAlertPanel (@"An exception has occured:", myException,			\
                                                                     NULL, NULL, NULL);									\
                                            exit (1);																	\
                                        }																				\
                                        NS_ENDHANDLER;

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Defines

#define	SYS_STRING_SIZE					1024						// string size for vsnprintf ().
#define	SYS_MOUSE_BUTTONS				5							// number of supported mouse buttons [max. 32].
#define	SYS_DEFAULT_BASE_PATH			@"Quake II baseq2 Path"
#define	SYS_DEFAULT_USE_MP3				@"Quake II Use MP3"
#define	SYS_INITIAL_USE_MP3				@"NO"
#define	SYS_DEFAULT_MP3_PATH			@"Quake II MP3 Path"
#define	SYS_INITIAL_MP3_PATH			@""
#define	SYS_DEFAULT_OPTION_KEY			@"Quake II Dialog Requires Option Key"
#define	SYS_INITIAL_OPTION_KEY			@"NO"
#define SYS_DEFAULT_USE_PARAMETERS		@"Quake II Use Command-Line Parameters"
#define SYS_INITIAL_USE_PARAMETERS		@"NO"
#define SYS_DEFAULT_PARAMETERS			@"Quake II Command-Line Parameters"
#define SYS_INITIAL_PARAMETERS			@""
#define SYS_BASEQ2_PATH					@"baseq2"
#define	SYS_VALIDATION_FILE1			@"GameMac.q2plug/Contents/MacOS/GameMac"
#define	SYS_VALIDATION_FILE2			@"GamePPC.q2plug/Contents/MacOS/GamePPC"
#define	SYS_VALIDATION_FILE3			@"GamePPC.bundle/Contents/MacOS/GamePPC"
#define SYS_CD_PATH						"/Volumes/QUAKE2/Quake2InstallData"
#define SYS_FRUITZ_OF_DOJO_URL			@"http://www.fruitz-of-dojo.de/"
#define	SYS_SET_COMMAND					"+set"
#define	SYS_GAME_COMMAND				"game"
#define	SYS_CDDIR_COMMAND				"cddir"
#define SYS_COMMAND_BUFFER_SIZE			1024

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Variables

extern int								gSysArgCount;
extern char **							gSysArgValues;
extern cvar_t *							gSysNoStdOut;

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Function Prototypes

void	Sys_DoEvents (NSEvent *myEvent, NSEventType myType);
void 	Sys_CheckForCDDirectory (void);
void	Sys_CheckForIDDirectory (void);

//------------------------------------------------------------------------------------------------------------------------------------------------------------
