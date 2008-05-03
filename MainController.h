//
//  MainController.h
//  GoogleReader
//
//  Created by Eli Dourado on 12/8/05.
//  Modified by Troels Bay (troelsbay@troelsbay.eu)
//
//

#import <Cocoa/Cocoa.h>
#import <Growl/Growl.h>
#import <IOKit/IOKitLib.h>


@interface MainController : NSObject <GrowlApplicationBridgeDelegate> {
	NSStatusItem *statusItem;
    IBOutlet NSSecureTextField *passwordField;
    IBOutlet NSTextField *usernameField;
    IBOutlet NSTextField *addNewFeedUrlField;
	IBOutlet NSTextField *torrentCastFolderPath;
	IBOutlet NSMenu *GRMenu;
	IBOutlet NSWindow *preferences; //preference window
	IBOutlet NSWindow *addfeedwindow; //addfeed window
	IBOutlet NSMenu *tempMenu;
	IBOutlet NSMenu *tempMenuSec;
    NSTimer *mainTimer;
	NSTimer *lastCheckTimer;
	NSUserDefaults *prefs;
	NSMutableArray *titles;
	NSMutableArray *sources;
	NSMutableArray *user;
	NSMutableArray *links;
	NSMutableArray *ids;
	NSMutableArray *feeds;	
	NSMutableArray *summaries;	
	NSMutableArray *torrentcastlinks;
	NSMutableArray *results;
	NSMutableArray *lastIds;
	NSMutableArray *newItems;
	NSError *xmlError;
	NSString *storedSID;
//	NSMutableString *storedUserNo;
	NSSound *theSound;
	NSImage *unreadItemsImage;
	NSImage *highlightedImage;
	NSImage *nounreadItemsImage;
	NSImage *errorImage;
	BOOL moreUnreadExistInGRInterface;
	int totalUnreadItemsInGRInterface;
	BOOL isLeopard;
	BOOL currentlyFetchingAndUpdating;
	int lastCheckMinute;
	
	NSDictionary *normalAttrsDictionary;
	NSDictionary *smallAttrsDictionary;
	
	NSString *torrentCastFolderPathString;


}

- (void)downloadFile:(NSString *)url:(NSString *)filename;
- (void)removeNumberOfItemsFromMenubar:(int) number;
- (NSString *)sendConnectionRequest:(NSString *)urlToConnectTo:(BOOL)handleCookies:(NSString *)cookieValue:(NSString *)theHTTPMethod:(NSString *)theHTTPBody;
- (NSAttributedString *)makeAttributedStatusItemString:(NSString *)text;
- (NSAttributedString *)makeAttributedMenuString:(NSString *)bigtext:(NSString *)smalltext;
- (NSString *)flattenHTML:(NSString *)stringToFlatten;
- (void)addFeed:(NSString *)url;
- (void)displayAlert:(NSString *)headerText:(NSString *)bodyText;
- (void)displayMessage:(NSString *)message;
- (NSString *)searchAndReplace:(NSString *)searchString:(NSString *)replaceString:(NSString *)inString;
- (NSString *)grabUserNo;
- (NSString *)loginToGoogle;
- (void)removeAllItemsFromMenubar;
- (IBAction)launchSite:(id)sender;
- (NSString *)getTokenFromGoogle;
- (IBAction)markAllAsRead:(id)sender;
- (IBAction)launchLink:(id)sender;
- (void)removeOneItemFromMenu:(int)index;
- (IBAction)doOptionalActionFromMenu:(id)sender;
- (void)markOneAsStarred:(int)index;
- (void)markOneAsRead:(int)index;
- (IBAction)launchErrorHelp:(id)sender;
- (IBAction)checkGoogleAuth:(id)sender;
- (void)timer:(NSTimer *)timer;
- (int)getUnreadCount;
- (void)retrieveGoogleFeed;
- (NSMutableArray *)reverseArray:(NSMutableArray *)array;
- (void)updateMenu;
- (IBAction)openPrefs:(id)sender;
- (IBAction)checkNow:(id)sender;
- (void)setTimeDelay:(int)x;
- (NSString *)getLabel;
- (void)errorImageOn;
- (NSString *)getURLPrefix;
- (void)announce;
- (NSString *)getUserPasswordFromKeychain;
- (void)growlNotificationWasClicked:(id)clickContext;
- (NSDictionary *)registrationDictionaryForGrowl;
- (NSString *)trimDownString:(NSString *)stringToTrim:(int)maxLength;
// - (IBAction)setLoginItem:(id)sender;
- (void)setupEventHandlers;
- (void)handleOpenLocationAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)reply;
- (IBAction)openAddFeedWindow:(id)sender;
- (IBAction)addFeedFromUI:(id)sender;
- (void)createLastCheckTimer;
- (void)displayLastTimeMessage:(NSString *)message;
- (void)displayTopMessage:(NSString *)message;
- (void)lastTimeCheckedTimer:(NSTimer *)timer;

- (IBAction)selectTorrentCastFolder:(id)sender;
- (void)selectTorrentCastFolderEnded:(NSOpenPanel*)panel returnCode:(int)returnCode contextInfo:(void*)contextInfo;

- (void)checkNowWithDelayDetached:(NSNumber *)delay;

@end
