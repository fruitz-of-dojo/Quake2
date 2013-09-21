//------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// "Quake2.h"
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2006 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
// Quake IIª is copyrighted by id software  [http://www.idsoftware.com].
//
//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Includes

#import <Cocoa/Cocoa.h>
#import "FDLinkView.h"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

#pragma mark Defines

#define	SYS_ABOUT_TOOLBARITEM		@"Quake2 About ToolbarItem"
#define	SYS_AUDIO_TOOLBARITEM		@"Quake2 Sound ToolbarItem"
#define	SYS_PARAM_TOOLBARITEM		@"Quake2 Parameters ToolbarItem"
#define	SYS_START_TOOLBARITEM		@"Quake2 Start ToolbarItem"

#pragma mark -

//------------------------------------------------------------------------------------------------------------------------------------------------------------

@interface Quake2 : NSObject
{
    IBOutlet NSWindow *				mediascanWindow;
    
    IBOutlet NSTextField *			mediascanText;
    IBOutlet NSProgressIndicator *	mediascanProgressIndicator;
    
    IBOutlet NSWindow *				startupWindow;
    
	IBOutlet NSView *				aboutView;
	IBOutlet NSView *				audioView;	
	IBOutlet NSView *				parameterView;
    IBOutlet FDLinkView	*			linkView;
			
    IBOutlet NSButton *				mp3CheckBox;
    IBOutlet NSButton *				mp3Button;
    IBOutlet NSTextField *			mp3TextField;
    
    IBOutlet NSButton *				optionCheckBox;
    IBOutlet NSButton *				parameterCheckBox;
    IBOutlet NSTextField *			parameterTextField;
    IBOutlet NSMenuItem *			pasteMenuItem;

    IBOutlet NSView *				mp3HelpView;

    NSView *						mEmptyView;

	NSTimer *						mFrameTimer;
	NSDate *						mDistantPast;
	
    NSString *						mMP3Folder;
	NSString *						mModFolder;

    NSMutableDictionary	*			mToolbarItems;									
	NSMutableArray *				mRequestedCommands;
	
	int								mLastFrameTime;
    BOOL							mOptionPressed;
	BOOL							mDenyDrag;
	BOOL							mAllowAppleScriptRun;
	BOOL							mHostInitialized;
	BOOL							mMediaScanCanceled;
}

+ (void) initialize;
- (void) dealloc;

- (BOOL) application: (NSApplication *) theSender openFile: (NSString *) theFilePath;
- (void) applicationDidResignActive: (NSNotification *) theNote;
- (void) applicationDidBecomeActive: (NSNotification *) theNote;
- (void) applicationWillHide: (NSNotification *) theNote;
- (void) applicationDidFinishLaunching: (NSNotification *) theNote;
- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *) theSender;

- (void) setupDialog: (NSTimer *) theTimer;
- (void) saveCheckBox: (NSButton *) theButton initial: (NSString *) theInitial
              default: (NSString *) theDefault userDefaults: (NSUserDefaults *) theUserDefaults;
- (void) saveString: (NSString *) theString initial: (NSString *) theInitial
            default: (NSString *) theDefault userDefaults: (NSUserDefaults *) theUserDefaults;
- (void) stringToParameters: (NSString *) theString;
- (BOOL) isEqualTo: (NSString *) theString;
- (void) installFrameTimer;
- (void) renderFrame: (NSTimer *) theTimer;
- (void) scanMediaThread: (id) theSender;
- (void) fireFrameTimer: (NSNotification *) theNotification;

- (IBAction) pasteString: (id) theSender;
- (IBAction) startQuake2: (id) theSender;
- (IBAction) visitFOD: (id) theSender;
- (IBAction) toggleParameterTextField: (id) theSender;
- (IBAction) toggleMP3Playback: (id) theSender;
- (IBAction) selectMP3Folder: (id) theSender;
- (IBAction) stopMediaScan: (id) theSender;

- (void) closeMP3Sheet: (NSOpenPanel *) theSheet returnCode: (int) theCode contextInfo: (void *) theInfo;
- (void) connectToServer: (NSPasteboard *) thePasteboard userData:(NSString *) theData error:(NSString **)theError;

- (BOOL) hostInitialized;
- (void) setHostInitialized: (BOOL) theState;

- (BOOL) allowAppleScriptRun;
- (void) enableAppleScriptRun: (BOOL) theState;
- (void) requestCommand: (NSString *) theCommand;

- (NSString *) modFolder;
- (NSString *) mediaFolder;
- (BOOL) abortMediaScan;
- (BOOL) wasDragged;

@end

//------------------------------------------------------------------------------------------------------------------------------------------------------------
