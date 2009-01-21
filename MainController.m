//
//  MainController.m
//  Reader Notifier
//
//

#import "MainController.h"
#import "Keychain.h"



// changelog since 1.02
//  - we have made it so that the lag of the count will be minor when marking something as read.


// 27 with special icons, 29 else
#define ourStatusItemWithLength 29 

#define versionBuildNumber 110
#define indexOfPreviewFields 4
#define itemsExclPreviewFields 6
#define maxLettersInSummary 500
#define maxLettersInSource 20

#define runningDebug 0


// disregard
// #define itemsExclPreviewFields 7 // changed from 6, back before "open all in windows" feature


@interface Delegate : NSObject
{
}
@end

@implementation Delegate
- (void) sound: (NSSound *) sound didFinishPlaying: (BOOL) aBool
{
//  [[NSApplication sharedApplication] terminate: nil];
}
@end


@implementation MainController


- (id)init
{
	[super init];
	
	[self setupEventHandlers];
	
	
	NSMutableDictionary *defaultPrefs = [NSMutableDictionary dictionary];
	
	[defaultPrefs setObject:@"20" forKey:@"maxItems"];
	[defaultPrefs setObject:@"10" forKey:@"timeDelay"];
	[defaultPrefs setObject:@"" forKey:@"Label"];
	[defaultPrefs setObject:@"5" forKey:@"maxNotifications"];
	[defaultPrefs setObject:@"NO" forKey:@"EnableTorrentCastMode"];

	
	prefs = [[NSUserDefaults standardUserDefaults] retain];
	[prefs registerDefaults:defaultPrefs];
	
	
	// in earlier versions this was set to the actual user password, which we would want to override
	[prefs setObject:@"NotForYourEyes" forKey:@"Password"];
	
	normalAttrsDictionary = [[NSDictionary alloc] initWithObjects:[NSArray arrayWithObjects: [NSFont fontWithName:@"Lucida Grande" size:14.0], nil] forKeys:[NSArray arrayWithObjects: NSFontAttributeName, nil ]];
	smallAttrsDictionary = [[NSDictionary alloc] initWithObjects:[NSArray arrayWithObjects: [NSFont fontWithName:@"Lucida Grande" size:12.0], [NSColor grayColor], nil] forKeys:[NSArray arrayWithObjects: NSFontAttributeName, NSForegroundColorAttributeName, nil ]];

	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];

	[nc addObserver:self selector:@selector(notificationTest1)
			name:@"PleaseUpdateMenu"
			object:GRMenu];


	// we need this to know when the computer wakes from sleep
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(notificationTest2) name:NSWorkspaceDidWakeNotification object:nil];
/*	NSNotificationCenter * wc = [[NSWorkspace sharedWorkspace] notificationCenter];

	[nc addObserver:self selector:@selector(notificationTest2)
			name:@"PleaseUpdateMenu"
			object:nil];
*/

	
	
	return self;
}

- (void)notificationTest1
{
	// if (runningDebug == 1) NSLog(@"Notification Center message to Update Menu");
	[self performSelectorOnMainThread:@selector(updateMenu) withObject:nil waitUntilDone:NO];
	/// [NSThread detachNewThreadSelector:@selector(updateMenu) toTarget:self withObject:nil];
}

- (void)notificationTest2
{

		NSDate *sleepUntil = [NSDate dateWithTimeIntervalSinceNow:8.0];
		[NSThread sleepUntilDate:sleepUntil];

		[lastCheckTimer invalidate];
		[self createLastCheckTimer];
		[lastCheckTimer fire];


	// [self checkNowWithDelayDetached:[NSNumber numberWithInt:5]];
	

}

- (void)windowWillClose:(NSNotification *)aNotification
{
	// when window closes, we update the shit
	// if (runningDebug == 1) NSLog([aNotification name]);
	
	// we disable this, because the app crashes if you put in new usercreds and then exit the prefwin at the same time
	// [self checkNow:nil];
	
}

- (void)awakeFromNib
{
	[NSApp activateIgnoringOtherApps:YES];
	
	
	// Get system version
	
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
	NSString *versionString = [dict objectForKey:@"ProductVersion"];
	NSArray *array = [versionString componentsSeparatedByString:@"."];
	int count = [array count];
	int major = (count >= 1) ? [[array objectAtIndex:0] intValue] : 0;
	int minor = (count >= 2) ? [[array objectAtIndex:1] intValue] : 0;
	int bugfix = (count >= 3) ? [[array objectAtIndex:2] intValue] : 0;

	if (major > 10 || major == 10 && minor >= 5) {
		isLeopard = YES;
	} else {
		isLeopard = NO;
	}
		
		
	// Growl
	[GrowlApplicationBridge setGrowlDelegate:self];
	
	[prefs setObject:@"" forKey:@"storedSID"];

	if ([[prefs valueForKey:@"useColoredNoUnreadItemsIcon"] intValue] == 1) {
		nounreadItemsImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"nounreadalt" ofType:@"png"]];	
	} else {
		// intValue == 0
		nounreadItemsImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"nounread" ofType:@"png"]];
	}

	if ([[prefs valueForKey:@"useColoredNoUnreadItemsIcon"] intValue] == 2) {
		unreadItemsImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"nounread" ofType:@"png"]];
		errorImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"bwerror" ofType:@"png"]];
	} else {
		unreadItemsImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"unread" ofType:@"png"]];
		errorImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"error" ofType:@"png"]];
	}
	
	highlightedImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"highunread" ofType:@"png"]];


		
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:ourStatusItemWithLength] retain]; //NSVariableStatusItemLength] retain];
	[statusItem setHighlightMode:YES];
	[statusItem setTitle:@""];
	[statusItem setMenu:GRMenu];
    [statusItem setImage:nounreadItemsImage];
    [statusItem setAlternateImage:highlightedImage];

	[statusItem setEnabled:YES];


	
	user = [[NSMutableArray alloc] init];
	titles = [[NSMutableArray alloc] init];
	links = [[NSMutableArray alloc] init];
	results = [[NSMutableArray alloc] init];
	lastIds = [[NSMutableArray alloc] init];
	feeds = [[NSMutableArray alloc] init];
	ids = [[NSMutableArray alloc] init];
	sources = [[NSMutableArray alloc] init];
	newItems = [[NSMutableArray alloc] init];
	summaries = [[NSMutableArray alloc] init];
	torrentcastlinks = [[NSMutableArray alloc] init];
	
	lastCheckMinute = 0;
	
	[[tempMenuSec insertItemWithTitle:NSLocalizedString(@"Go to Reader",nil) action:@selector(launchSite:) keyEquivalent:@"" atIndex:0] setTarget:self];
	[[tempMenuSec insertItemWithTitle:NSLocalizedString(@"Subscribe to Feed",nil) action:@selector(openAddFeedWindow:) keyEquivalent:@"" atIndex:1] setTarget:self];
	[[tempMenuSec insertItemWithTitle:NSLocalizedString(@"Check Now",nil) action:@selector(checkNow:) keyEquivalent:@"" atIndex:2] setTarget:self];	
	[[tempMenuSec itemAtIndex:2] setAttributedTitle:[self makeAttributedMenuString:NSLocalizedString(@"Check Now",nil):@""]];
	[tempMenuSec insertItem:[NSMenuItem separatorItem] atIndex:3];	
	[[tempMenuSec insertItemWithTitle:NSLocalizedString(@"Preferences...",nil) action:@selector(openPrefs:) keyEquivalent:@"" atIndex:4] setTarget:self];
	[[tempMenuSec itemAtIndex:2] setAttributedTitle:[self makeAttributedMenuString:NSLocalizedString(@"Check Now",nil):NSLocalizedString(@"Updating...",nil)]];
	
	[[GRMenu insertItemWithTitle:NSLocalizedString(@"Go to Reader",nil) action:@selector(launchSite:) keyEquivalent:@"" atIndex:0] setTarget:self];
	[[GRMenu insertItemWithTitle:NSLocalizedString(@"Subscribe to Feed",nil) action:@selector(openAddFeedWindow:) keyEquivalent:@"" atIndex:1] setTarget:self];
	[[GRMenu insertItemWithTitle:NSLocalizedString(@"Check Now",nil) action:@selector(checkNow:) keyEquivalent:@"" atIndex:2] setTarget:self];	
	[[GRMenu itemAtIndex:2] setAttributedTitle:[self makeAttributedMenuString:NSLocalizedString(@"Check Now",nil):@""]];
	[GRMenu insertItem:[NSMenuItem separatorItem] atIndex:3];
	[[GRMenu insertItemWithTitle:NSLocalizedString(@"Preferences...",nil) action:@selector(openPrefs:) keyEquivalent:@"" atIndex:4] setTarget:self];
	
	storedSID = [[NSString alloc] init];
	storedSID = @"";
	
	if ([prefs valueForKey:@"Username"] && [Keychain checkForExistanceOfKeychain] > 0) {
		[self setTimeDelay:[[prefs valueForKey:@"timeDelay"] intValue]];
		[mainTimer fire];
		[self createLastCheckTimer];
		[lastCheckTimer fire];
	} else {
		[self displayAlert:@"Please fill in your Google Account login in the preference pane":@"In order to connect to your feed you need to type in your username and password."];
		[self displayMessage:@"please enter login details"];
	}
	
	
	
	// Get the info dictionary (Info.plist)
    NSDictionary *infoDictionary;
	infoDictionary = [[NSBundle mainBundle] infoDictionary];
	
	if (runningDebug == 1) if (runningDebug == 1) NSLog(@"Hello. %@ Build %@", [infoDictionary objectForKey:@"CFBundleName"], [infoDictionary objectForKey:@"CFBundleVersion"]);

	if ([prefs valueForKey:@"torrentCastFolderPath"] != NULL) {
		[torrentCastFolderPath setStringValue:[prefs valueForKey:@"torrentCastFolderPath"]];
	}
	
	
	NSProcessInfo *procInfo = [NSProcessInfo processInfo];
	if (runningDebug == 1) if (runningDebug == 1) NSLog(@"We're on %@", [procInfo operatingSystemVersionString]);
	

}

- (void)createLastCheckTimer
{
		lastCheckMinute = 0;
		lastCheckTimer = [[NSTimer scheduledTimerWithTimeInterval:(60) target:self selector:@selector(lastTimeCheckedTimer:) userInfo:nil repeats:YES] retain];
}

- (void)setTimeDelay:(int) x //creates a timer with a user-specified delay, fires the timer
{
	
	//if (runningDebug == 1) if (runningDebug == 1) NSLog(@"creating timer with %d minute delay", [[prefs stringForKey:@"timeDelay"] intValue]);
    mainTimer = [[NSTimer scheduledTimerWithTimeInterval:(60 * x) target:self selector:@selector(timer:) userInfo:nil repeats:YES] retain];
	
}

- (void)timer:(NSTimer *)timer 
{	
	if (currentlyFetchingAndUpdating != YES) {
	
		if (![[self loginToGoogle] isEqualToString:@""]) {
			[self retrieveGoogleFeed];
		}
		
	}
}

- (void)lastTimeCheckedTimer:(NSTimer *)timer
{

	if (lastCheckMinute > [[prefs valueForKey:@"timeDelay"] intValue]) {
	
		if (runningDebug == 1) if (runningDebug == 1) NSLog(@"lastTimeChecked is more than it should be, so we run update");

		if (currentlyFetchingAndUpdating != YES) {
			[NSThread detachNewThreadSelector:@selector(checkNow:) toTarget:self withObject:nil];
		}
	
	} else {
		
		if (runningDebug == 1) if (runningDebug == 1) NSLog(@"lastTimeCheckedTimer run %d", lastCheckMinute);

		if (lastCheckMinute == 0) {
			[self displayLastTimeMessage:[NSString stringWithString:NSLocalizedString(@"Checked less than 1 min ago",nil)]]; /* ok */
		} else if (lastCheckMinute == 1) {
			[self displayLastTimeMessage:[NSString stringWithString:NSLocalizedString(@"Checked 1 min ago",nil)]]; /* ok */
		} else if (lastCheckMinute < 60) {
			[self displayLastTimeMessage:[NSString stringWithFormat:NSLocalizedString(@"Checked %d min ago",nil), lastCheckMinute]];
		} else if (59 < lastCheckMinute < 120) {
			[self displayLastTimeMessage:[NSString stringWithString:NSLocalizedString(@"Checked 1 hour ago",nil)]]; /* ok */
		} else if (119 < lastCheckMinute < 180) {
			[self displayLastTimeMessage:[NSString stringWithString:NSLocalizedString(@"Checked 2 hours ago",nil)]]; /* ok */
		} else if (179 < lastCheckMinute < 240) {
			[self displayLastTimeMessage:[NSString stringWithString:NSLocalizedString(@"Checked 3 hours ago",nil)]]; /* ok */
		} else if (239 < lastCheckMinute) {
			[self displayLastTimeMessage:[NSString stringWithString:NSLocalizedString(@"Checked more than 4 hours ago",nil)]]; /* ok */
		}
		
		lastCheckMinute++;
		
	}

}


- (NSString *)sendConnectionRequest:(NSString *)urlToConnectTo:(BOOL)handleCookies:(NSString *)cookieValue:(NSString *)theHTTPMethod:(NSString *)theHTTPBody
{

	NSError *error;
	NSURLResponse *response;
	NSData *dataReply;
	NSString *stringReply;
	NSMutableURLRequest *request = [NSMutableURLRequest  requestWithURL: [NSURL URLWithString:urlToConnectTo]];
	[request setTimeoutInterval:5.0];
		
	if (isLeopard) {
		[request setHTTPShouldHandleCookies:NO];
	} else {
		[request setHTTPShouldHandleCookies:handleCookies];
	}

	[request setValue:cookieValue forHTTPHeaderField:@"Cookie"];
	[request setHTTPMethod:theHTTPMethod]; // Changing the setHTTPMethod to "POST" sends the HTTPBody
	[request setHTTPBody: [theHTTPBody dataUsingEncoding: NSUTF8StringEncoding]];
	
	dataReply = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
	
	if (error==nil) {
		
		stringReply = [[NSString alloc] initWithData:dataReply encoding:NSUTF8StringEncoding];

		return stringReply;
	
		[stringReply release];
	
	} else {
	
		return @"";
	
	}
}

- (int)getUnreadCount
{

	if (runningDebug == 1) if (runningDebug == 1) NSLog(@"Total count (getUnreadCount) method initiated");

	// since .99 this has provided a memory error (case of Moore).
	// we've tried to fix it with releasing atomdoc2 and temparray5 (and not releasing dstring)

	// http://www.google.com/reader/api/0/unread-count?all=true&autorefresh=true&output=json&ck=1165697710220&client=scroll

	NSError *newError;
	NSURLResponse *newResponse;
	NSData *newDataReply;
	// NSString *newReply;
	
	NSMutableURLRequest *newRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@://www.google.com/reader/api/0/unread-count?all=true&autorefresh=true&output=xml&client=scroll",[self getURLPrefix]]]];
	// [request setHTTPMethod: @"PUT"]; // With the setHTTPMethod set to "PUT" the HTTPBody is not being sent

	// we need to do this, otherwise we can risk get an old one :(  - seriously, we did!
	[newRequest setCachePolicy:NSURLRequestReloadIgnoringCacheData];
	[newRequest setTimeoutInterval:5.0];
	if (isLeopard) {
		[newRequest setHTTPShouldHandleCookies:NO];
	} else {
		[newRequest setHTTPShouldHandleCookies:YES];
	}
	[newRequest setValue:[self loginToGoogle] forHTTPHeaderField:@"Cookie"];
	[newRequest setHTTPMethod:@"GET"]; // Changing the setHTTPMethod to "POST" sends the HTTPBody

	newDataReply = [NSURLConnection sendSynchronousRequest:newRequest returningResponse:&newResponse error:&newError];
	
	// NSString *stringReply = [[NSString alloc] initWithData:newDataReply encoding:NSUTF8StringEncoding];
	// if (runningDebug == 1) if (runningDebug == 1) NSLog(stringReply);
	


	if (newError==nil) {


		NSXMLDocument *atomdoc2 = [[NSXMLDocument alloc] initWithData:newDataReply options:0 error:&xmlError];	
		
		if (runningDebug == 1) if (runningDebug == 1) NSLog(@"getUnreadCount1");

		NSMutableArray *tempArray5 = [[NSMutableArray alloc] init];
		// [tempArray5 autorelease];
		
		if (runningDebug == 1) if (runningDebug == 1) NSLog(@"getUnreadCount2");

		// if the user is on labels, use that to check instead!
		if ([[prefs valueForKey:@"Label"] isEqualToString:@""])
		{
			// [tempArray5 addObjectsFromArray:[atomdoc2 objectsForXQuery:@"/object/list/object/number/text()" error:NULL]];
			// [tempArray5 addObjectsFromArray:[atomdoc2 objectsForXQuery:@"for $x in /object/list/object where $x/string[contains(., 'feed/http://')] return $x/number/text()" error:NULL]];	
			[tempArray5 addObjectsFromArray:[atomdoc2 objectsForXQuery:@"for $x in /object/list/object where $x/string[contains(., 'feed/http://')] return $x/number[@name=\"count\"]/text()" error:NULL]];  // peters add
		} else {

			if (runningDebug == 1) if (runningDebug == 1) NSLog(@"getUnreadCount haslabel");

			// if (runningDebug == 1) if (runningDebug == 1) NSLog(@"Hello");
			// [tempArray5 addObjectsFromArray:[atomdoc2 objectsForXQuery:@"/object/list/object/number/text()" error:NULL]];
			// REAL ONE [tempArray5 addObjectsFromArray:[atomdoc2 objectsForXQuery:[NSString stringWithFormat:@"for $x in /object/list/object where $x/string[contains(., '/%@')] return $x/number/text()", [self getLabel]] error:NULL]];
			// if (runningDebug == 1) if (runningDebug == 1) NSLog(@"We use labels");
			// [tempArray5 addObjectsFromArray:[atomdoc2 objectsForXQuery:[NSString stringWithFormat:@"for $x in /object/list/object where $x/string[contains(., '/label/%@')] return $x/number/text()", [prefs valueForKey:@"Label"]] error:NULL]];
			[tempArray5 addObjectsFromArray:[atomdoc2 objectsForXQuery:[NSString stringWithFormat:@"for $x in /object/list/object where $x/string[contains(., '/label/%@')] return $x/number[@name=\"count\"]/text()", [prefs valueForKey:@"Label"]] error:NULL]]; // peters add
		}
		

		int k,t;
		t = 0;
		NSString *dString;
		
		for (k=0; k<[tempArray5 count]; k++) {
			dString = [[tempArray5 objectAtIndex:k] stringValue];
			t = t + [dString intValue];
		}
		
		if (runningDebug == 1) NSLog(@"getUnreadCount3");

		
		// [dString release];
		[tempArray5 release];
		[atomdoc2 release];
		
		if (runningDebug == 1) NSLog(@"The total count of unread items is now %d", t);

		totalUnreadItemsInGRInterface = t;

	} else {
	
	    // there was an error
		totalUnreadItemsInGRInterface = -1;
				
		[self errorImageOn]; 
		currentlyFetchingAndUpdating = NO;
	
		[lastCheckTimer invalidate];
		[self createLastCheckTimer];
		[lastCheckTimer fire];
		
		[statusItem setMenu:GRMenu];
	
	}
	
	
	
	
	
	//if (runningDebug == 1) NSLog([NSString stringWithFormat:@"%d", t]);


	// if (runningDebug == 1) NSLog([NSString stringWithFormat:@"totalUnreadItemsInGRInterface is %d+", totalUnreadItemsInGRInterface]);
	
	return totalUnreadItemsInGRInterface;
}

- (void)retrieveGoogleFeed
{
	// threading
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	if (runningDebug == 1) NSLog(@"retrieveGoogleFeed begin");

	currentlyFetchingAndUpdating = YES;
	[statusItem setMenu:tempMenuSec];
		
	// in case we had an error before, clear the highlightedimage and displaymessage
	[statusItem setAlternateImage:highlightedImage];


	xmlError = [[NSError alloc] init];
	[lastIds setArray:ids];
	[results removeAllObjects];
	[titles removeAllObjects];
	[sources removeAllObjects];
	[links removeAllObjects];
	[feeds removeAllObjects];
	[ids removeAllObjects];
	[newItems removeAllObjects];
	[summaries removeAllObjects];
	[torrentcastlinks removeAllObjects];
	[user removeAllObjects]; // if this is not done, we cannot be sure that a user will get a new userNo on re-entering login details
	
	/* new */
	
	NSError *newError;
	NSURLResponse *newResponse;
	NSData *newDataReply;
	
	NSMutableURLRequest *newRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@://www.google.com/reader/atom/user/-/%@?r=d&xt=user/-/state/com.google/read&n=%d",[self getURLPrefix],[self getLabel],[[prefs valueForKey:@"maxItems"] intValue]+1]]];
	[newRequest setTimeoutInterval:5.0];
	[newRequest setCachePolicy:NSURLRequestReloadIgnoringCacheData];
	if (isLeopard) {
		[newRequest setHTTPShouldHandleCookies:NO];
	} else {
		[newRequest setHTTPShouldHandleCookies:YES];
	}
	

	[newRequest setHTTPMethod:@"GET"]; // Changing the setHTTPMethod to "POST" sends the HTTPBody
	[newRequest setValue:[self loginToGoogle] forHTTPHeaderField:@"Cookie"];		

	newDataReply = [NSURLConnection sendSynchronousRequest:newRequest returningResponse:&newResponse error:&newError];

	if (newError!=nil) {
		
		[self errorImageOn]; 
		currentlyFetchingAndUpdating = NO;
	
		[lastCheckTimer invalidate];
		[self createLastCheckTimer];
		[lastCheckTimer fire];
		
		[statusItem setMenu:GRMenu];
	
		return;
	}
			
	NSXMLDocument *atomdoc = [[NSXMLDocument alloc] initWithData:[newDataReply retain] options:0 error:&xmlError];	


	
	[titles addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/entry/title/text()" error:NULL]];
	// [summaries addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/entry/summary/text()" error:NULL]];
	[sources addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/entry/source/title/text()" error:NULL]];
	[ids addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/entry/id/text()" error:NULL]];
	//[user addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/id/text()" error:NULL]];
	//[links addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/entry/link[@rel='alternate']/@href" error:NULL]];
	//[feeds addObjectsFromArray:[atomdoc objectsForXQuery:@"for $f in /feed/entry/source return $f/@gr:stream-id" error:NULL]];
	[feeds addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/entry/source/@gr:stream-id" error:NULL]];
	[user addObjectsFromArray:[atomdoc objectsForXQuery:@"/feed/id/text()" error:NULL]];



	
	// NSMutableArray *tempArray = [[NSMutableArray alloc] init];
	// [tempArray autorelease];
	
	//NSMutableArray *tempArray0 = [[NSMutableArray alloc] init];
	
	if (runningDebug == 1) NSLog(@"retrieveGoogleFeed 1");
	
	int k;
	for(k=0; k<[titles count]; k++){
		
		NSMutableArray *tempArray0 = [[NSMutableArray alloc] initWithArray:[atomdoc objectsForXQuery:[NSString stringWithFormat:@"/feed/entry[%d]/link[@rel='alternate']/@href",k+1] error:NULL]];
		if([tempArray0 count]>0){
			[links insertObject:[[tempArray0 objectAtIndex:0] stringValue] atIndex:k];
		} else {
			[links insertObject:@"" atIndex:k];
		}
		[tempArray0 release];
	}
	
	/*
	for(k=0; k<[titles count]; k++){
		
		NSMutableArray *tempArray0 = [[NSMutableArray alloc] initWithArray:[atomdoc objectsForXQuery:[NSString stringWithFormat:@"/feed/entry[%d]/link[@rel='alternate']/@href",k+1] error:NULL]];
		if([tempArray0 count]>0){
			[links insertObject:[[tempArray0 objectAtIndex:0] stringValue] atIndex:k];
		} else {
			[links insertObject:@"" atIndex:k];
		}
		[tempArray0 release];
	}
	*/
	

	if (runningDebug == 1) NSLog(@"retrieveGoogleFeed 2");
	
	int m;
	for (m=0; m<[titles count]; m++) {
		NSMutableArray *tempArray2 = [[NSMutableArray alloc] initWithArray:[atomdoc objectsForXQuery:[NSString stringWithFormat:@"/feed/entry[%d]/summary/text()",m+1] error:NULL]];
		if ( [tempArray2 count]>0 ) {
			[summaries insertObject:[NSString stringWithFormat:@"\n\n%@", [self flattenHTML:[self trimDownString:[[tempArray2 objectAtIndex:0] stringValue]:maxLettersInSummary]]] atIndex:m];
		} else {
			NSMutableArray *tempArray3 = [[NSMutableArray alloc] initWithArray:[atomdoc objectsForXQuery:[NSString stringWithFormat:@"/feed/entry[%d]/content/text()",m+1] error:NULL]];
			if( [tempArray3 count]>0 ) {
				[summaries insertObject:[NSString stringWithFormat:@"\n\n%@", [self flattenHTML:[self trimDownString:[[tempArray3 objectAtIndex:0] stringValue]:maxLettersInSummary]]] atIndex:m];
			} else {
				[summaries insertObject:@"" atIndex:m];
			}
			[tempArray3 release];
		}
		[tempArray2 release];
	}
	
	if (runningDebug == 1) NSLog(@"retrieveGoogleFeed 2a");

	// torrentcasting
	int l;
	for (l=0; l<[titles count]; l++) {
		NSMutableArray *tempArray2 = [[NSMutableArray alloc] initWithArray:[atomdoc objectsForXQuery:[NSString stringWithFormat:@"/feed/entry[%d]/link[@type='application/x-bittorrent']/@href",l+1] error:NULL]];
		if ( [tempArray2 count]>0 ) {
			[torrentcastlinks insertObject:[[tempArray2 objectAtIndex:0] stringValue] atIndex:l];
		} else {
			[torrentcastlinks insertObject:@"" atIndex:l];
		}
		[tempArray2 release];
	}


	
	// cannot release here, because we'll release atomdoc as well
	// [tempArray2 release];
	// [tempArray3 release];
	

	//if (runningDebug == 1) NSLog([self grabUserNo]);
	
	//if (runningDebug == 1) NSLog([links description]);
	
	/*	int i;
	for(i=0; i<[links count]; i++){
		[links replaceObjectAtIndex:i withObject:[[links objectAtIndex:i] stringValue]];
	}*/
	
	if (runningDebug == 1) NSLog(@"retrieveGoogleFeed 3");
	
	int j;
	for(j=0; j<[feeds count]; j++){
		[feeds replaceObjectAtIndex:j withObject:[[feeds objectAtIndex:j] stringValue]];
	}
	
	
	if (runningDebug == 1) NSLog(@"retrieveGoogleFeed 4");
	
	int d;
	for(d=0; d<[ids count]; d++){
		[ids replaceObjectAtIndex:d withObject:[[ids objectAtIndex:d] stringValue]];
	}

		
	if (runningDebug == 1) NSLog(@"retrieveGoogleFeed 5");
	
	// to sort everything with the newest on top

//	titles = [self reverseArray:titles];
//	sources = [self reverseArray:sources];
//	ids = [self reverseArray:ids];
//	feeds = [self reverseArray:feeds];
//	links = [self reverseArray:links];
//	summaries = [self reverseArray:summaries];

	
	
	

	
	
	//if (runningDebug == 1) NSLog([[links objectAtIndex:0] stringValue]);
	//if (runningDebug == 1) NSLog([feeds description]);
	
	[atomdoc release];

	//[tempArray2 release];
	//[tempArray3 release];
	
	// NSMutableURLRequest *newRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@://www.google.com/reader/api/0/unread-count?all=true&autorefresh=true&output=xml&client=scroll",[self getURLPrefix]]]];

	if (runningDebug == 1) NSLog(@"retrieveGoogleFeed 6");


	// [atomdoc autorelease];
	
	if (xmlError!=nil) {
	
		/*
	     if (runningDebug == 1) NSLog(@"%@ %d %@", [ xmlError domain], [ xmlError code], [ xmlError localizedDescription]);
		
		/// if ([[prefs valueForKey:@"Label"] containsObject:[NSString stringWithString:@" "]]) {
		///	[self displayMessage:@"error with Labels - only one allowed."];
		/// } else {
			[self displayMessage:@"no Internet connection"];
			// if (runningDebug == 1) NSLog(@"no internet connection it seems!");
		/// }
		
		[self errorImageOn]; 
		// NSImage *errorMenuicon = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"error" ofType:@"png"]];
		// [statusItem setImage:[[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"error" ofType:@"png"]]];
		// [statusItem setAlternateImage:[[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"error" ofType:@"png"]]];

		// [statusItem setMenu:GRMenu];
		
		currentlyFetchingAndUpdating = NO;
		*/


	} else {
	
		// We need to set the global whether there are (at least one) more unread items online in the google reader interface
		if ([titles count] > [[prefs valueForKey:@"maxItems"] intValue]) {
			moreUnreadExistInGRInterface = YES;
			// We also remove the last item, since we do not wish to display it anywhere, or fuck up the count
			//  note, we remove the first item, which is actually the oldest (we reversed the array earlier)
			//  ! we could actually skip all the maxItems checks later, but they're nice to have.
			/// UPDATE! We do not reverse it any longer! So now we just remove the last item

			if (runningDebug == 1) NSLog(@"retrieveGoogleFeed 6");

			if ([ids count] > 0) {
			
				[titles removeLastObject];
				[sources removeLastObject];
				[ids removeLastObject];
				[feeds removeLastObject];
				[links removeLastObject];
				[summaries removeLastObject];
				[torrentcastlinks removeLastObject];

				
				// [titles removeObjectAtIndex:0];
				// [sources removeObjectAtIndex:0];
				// [ids removeObjectAtIndex:0];
				// [feeds removeObjectAtIndex:0];
				// [links removeObjectAtIndex:0];
				// [summaries removeObjectAtIndex:0];

			}
			
			if (runningDebug == 1) NSLog(@"retrieveGoogleFeed 7");
			
			// while we know that there are extra unread items, we want to get the exact count of them, 
			// the totalUnreadItemsInGRInterface will be updated automatically
			
			//// HERE THERE IS AN ERROR!!! **** this call makes a memory-error
			[self getUnreadCount];
			
		} else {
			moreUnreadExistInGRInterface = NO;
		}
				
		// threading
		// [self performSelectorOnMainThread:@selector(updateMenu) withObject:self waitUntilDone:YES];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"PleaseUpdateMenu" object:nil];
		
		// threading off
		// [self updateMenu];
	}
		
	// if (runningDebug == 1) NSLog(@"Test");
	
	// [newDataReply release];
	// [newReply release];
	// [newRequest release];
	
	 if (runningDebug == 1) NSLog(@"retrieveGoogleFeed end");
	
	// threading
	[pool release];

}



- (void)updateMenu //updates the icon if necessary, updates the unread item
{

	// threading
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	
	[lastCheckTimer invalidate];
	[self createLastCheckTimer];
	[lastCheckTimer fire];

	
	if (runningDebug == 1) NSLog(@"updateMenu begin");

	// if (runningDebug == 1) NSLog(@"Updating menu");

	currentlyFetchingAndUpdating = YES;

	// [self performSelectorOnMainThread:@selector(removeAllItemsFromMenubar) withObject:nil waitUntilDone:YES];
	
	int n;
	n = [GRMenu numberOfItems];
	int v;
	for(v=itemsExclPreviewFields; v<n; v++) {
		// [[GRMenu itemAtIndex:indexOfPreviewFields] release];
		[GRMenu removeItemAtIndex:indexOfPreviewFields];
	//	[GRMenu removeItem:[GRMenu itemAtIndex:indexOfPreviewFields]];
	}	
	

	

	// if (runningDebug == 1) NSLog(@"All items removed from Menubar");
	
	// EXPERIMENTAL
	/// This is a feature in development!
	/// The automatical downloading of certain feeds

	// TORRENTCASTING

	if ([prefs boolForKey:@"EnableTorrentCastMode"] == YES) {

		int i;		
		for(i=0; i<[titles count]; i++){
		
			if (![[torrentcastlinks objectAtIndex:i] isEqualToString:@""]) {
			
				NSFileManager *fm = [NSFileManager defaultManager];	
				if ([fm fileExistsAtPath:[prefs valueForKey:@"torrentCastFolderPath"]] == YES) { 
				
					[self downloadFile:[torrentcastlinks objectAtIndex:i]:[NSString stringWithFormat:@"%@.torrent", [titles objectAtIndex:i]]];
						
					NSMutableString *feedstring = [[NSMutableString alloc] initWithString:[feeds objectAtIndex:i]];
					[feedstring replaceOccurrencesOfString:@"=" withString:@"-" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [feedstring length])];
					[self sendConnectionRequest:[NSString stringWithFormat:@"%@://www.google.com/reader/api/0/edit-tag?s=%@&i=%@&ac=edit-tags&a=user/-/state/com.google/read&r=user/-/state/com.google/kept-unread&T=%@",[self getURLPrefix],feedstring,[ids objectAtIndex:i],[self getTokenFromGoogle]]:YES:[self loginToGoogle]:@"POST":@""];
					[feedstring release];
					
					if ([[prefs valueForKey:@"openTorrentAfterDownloading"] boolValue] == YES) {
						if (runningDebug == 1) NSLog([NSString stringWithFormat:@"%@/%@", [prefs valueForKey:@"torrentCastFolderPath"], [NSString stringWithFormat:@"%@.torrent", [titles objectAtIndex:i]]]);
						[[NSWorkspace sharedWorkspace] openFile:[NSString stringWithFormat:@"%@/%@", [prefs valueForKey:@"torrentCastFolderPath"], [NSString stringWithFormat:@"%@.torrent", [titles objectAtIndex:i]]]];
					}					
					
					[feeds removeObjectAtIndex:i];
					[ids removeObjectAtIndex:i];
					[links removeObjectAtIndex:i];
					[titles removeObjectAtIndex:i];
					[sources removeObjectAtIndex:i];
					[summaries removeObjectAtIndex:i];
					[torrentcastlinks removeObjectAtIndex:i];
										
				} else {
				
					[self displayAlert:NSLocalizedString(@"TorrentCast Error",nil):NSLocalizedString(@"Reader Notifier has found a new TorrentCast. However we are unable to download it because the folder you've specified does not exists. Please choose a new folder in the preferences. In addition, TorrentCasting has been disabled.",nil)];
					[prefs setValue:NO forKey:@"EnableTorrentCastMode"];
					
				
				}
				
			
			}

		}
		
	}

	
	
	
	
	
	int c;
	for(c=0; c<[titles count]; c++){
	
		[results addObject:[NSString stringWithFormat:@"%d", c]];

	}
	
	// if we have any items in the list, we should put a nice little bar between the normal buttons and the feeditems
	if ([results count] > 0 && [[prefs valueForKey:@"minimalFunction"] boolValue] != YES) {
		[GRMenu insertItem:[NSMenuItem separatorItem] atIndex:3];
	}
	
	// if (runningDebug == 1) NSLog(@"Putting in the new standard stuff");
	
	// this will actually be put at the bottom
	// if ([results count] == 1 && [[prefs valueForKey:@"minimalFunction"] boolValue] != YES) {

	
			// [[GRMenu insertItemWithTitle:NSLocalizedString(@"Mark as read",nil) action:@selector(markAllAsRead:) keyEquivalent:@"" atIndex:indexOfPreviewFields] setTarget:self];
			// [GRMenu insertItemWithTitle:NSLocalizedString(@"Open all items",nil) action:@selector(openAllItems:) keyEquivalent:@"" atIndex:indexOfPreviewFields];
			// [GRMenu insertItem:[NSMenuItem separatorItem] atIndex:indexOfPreviewFields];


	// } else if ([results count] > 0 && [[prefs valueForKey:@"minimalFunction"] boolValue] != YES && moreUnreadExistInGRInterface == YES) {
	if ([results count] > 0 && [[prefs valueForKey:@"minimalFunction"] boolValue] != YES && moreUnreadExistInGRInterface == YES) {

			// we don't want to display the Mark all as read if there are more items in the Google Reader Interface
			// though we check if the users wants to override this
			
			if ([[prefs valueForKey:@"alwaysEnableMarkAllAsRead"] boolValue] != YES) {
			
				[GRMenu insertItemWithTitle:[NSString stringWithString:NSLocalizedString(@"More unread items exist",nil)] action:nil keyEquivalent:@"" atIndex:indexOfPreviewFields]; 
				[[GRMenu itemAtIndex:indexOfPreviewFields] setToolTip:NSLocalizedString(@"Mark all as read has been disabled",nil)];
			
			} else {
			
				[[GRMenu insertItemWithTitle:NSLocalizedString(@"Mark all as read",nil) action:@selector(markAllAsRead:) keyEquivalent:@"" atIndex:indexOfPreviewFields] setTarget:self];
				[[GRMenu itemAtIndex:indexOfPreviewFields] setAttributedTitle:[self makeAttributedMenuString:NSLocalizedString(@"Mark all as read",nil):NSLocalizedString(@"Warning, items online will be marked read",nil)]];
				[[GRMenu itemAtIndex:indexOfPreviewFields] setToolTip:NSLocalizedString(@"There are more unread items online in the Google Reader interface. This function will cause Google Reader Notifier to mark all as read - whether or not they are visible in the menubar",nil)];
			
			}

		[[GRMenu insertItemWithTitle:NSLocalizedString(@"Open all items",nil) action:@selector(openAllItems:) keyEquivalent:@"" atIndex:indexOfPreviewFields] setTarget:self];
			
			[GRMenu insertItem:[NSMenuItem separatorItem] atIndex:indexOfPreviewFields];

	} else if ([results count] > 0 && [[prefs valueForKey:@"minimalFunction"] boolValue] != YES) {

			[[GRMenu insertItemWithTitle:NSLocalizedString(@"Mark all as read",nil) action:@selector(markAllAsRead:) keyEquivalent:@"" atIndex:indexOfPreviewFields] setTarget:self]; 

			[[GRMenu insertItemWithTitle:NSLocalizedString(@"Open all items",nil) action:@selector(openAllItems:) keyEquivalent:@"" atIndex:indexOfPreviewFields] setTarget:self];

			[GRMenu insertItem:[NSMenuItem separatorItem] atIndex:indexOfPreviewFields];

	}
	


	int newCount;
	int currentIndexCount;

	newCount = 0;
	currentIndexCount = indexOfPreviewFields;
	
	// if (runningDebug == 1) NSLog(@"Looping through the results array");
	
	// we loop through the results count, but we cannot go above the maxItems, even though we always fetch one row more than max
	int j;
	for (j = 0; j < [results count] && j < [[prefs valueForKey:@"maxItems"] intValue]; j++) {
		
		if ([[prefs valueForKey:@"minimalFunction"] boolValue] != YES) {


			NSString *trimmedTitleTag = [[NSString alloc] initWithString:[self trimDownString:[self flattenHTML:[[titles objectAtIndex:j] stringValue]]:60]];
			NSString *trimmedSourceTag = [[NSString alloc] initWithString:[self trimDownString:[self flattenHTML:[[sources objectAtIndex:j] stringValue]]:maxLettersInSource]];


			// trimmedSourceTag = [self trimDownString:[self flattenHTML:[[sources objectAtIndex:j] stringValue]]:maxLettersInSource];
			// trimmedTitleTag = [self trimDownString:[self flattenHTML:[[titles objectAtIndex:j] stringValue]]:60];

			NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchLink:) keyEquivalent:@""];

			[item setAttributedTitle:[self makeAttributedMenuString:trimmedSourceTag:trimmedTitleTag]];
			if ([[prefs valueForKey:@"dontShowTooltips"] boolValue] != YES) {
				[item setToolTip:[NSString stringWithFormat:NSLocalizedString(@"Title: %@\nFeed: %@\nGoes to: %@%@",nil), [titles objectAtIndex:j], [[sources objectAtIndex:j] stringValue], [links objectAtIndex:j], [summaries objectAtIndex:j]]];
			}
			

			[item setTitle:[ids objectAtIndex:j]];


			if ([[links objectAtIndex:j] length] > 0) {
				[item setTarget:self];
			}
			
			// [[GRMenu itemAtIndex:currentIndexCount] setTitle:];
			[item setKeyEquivalentModifierMask:0];
			
			[GRMenu insertItem:item atIndex:currentIndexCount];
			
			// and then set the alternate 
			NSMenuItem *itemSecondary = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(doOptionalActionFromMenu:) keyEquivalent:@""];
			// [GRMenu insertItemWithTitle:@"" action:@selector(doOptionalActionFromMenu:) keyEquivalent:@"" atIndex:currentIndexCount+1];
			
			if ([[prefs valueForKey:@"onOptionalActAlsoStarItem"] boolValue] == YES) {
				[itemSecondary setAttributedTitle:[self makeAttributedMenuString:trimmedSourceTag:NSLocalizedString(@"Star item and mark as read",nil)]];
			} else {
				[itemSecondary setAttributedTitle:[self makeAttributedMenuString:trimmedSourceTag:NSLocalizedString(@"Mark item as read",nil)]];
			}

			[itemSecondary setKeyEquivalentModifierMask:NSCommandKeyMask];
			[itemSecondary setAlternate:YES];
			// even though setting the title twice seems like doing double work, we have to, because [sender title] will always be the last set title!
			[itemSecondary setTitle:[ids objectAtIndex:j]];
			
			if ([[links objectAtIndex:j] length] > 0) {
				[itemSecondary setTarget:self];
			}

			[GRMenu insertItem:itemSecondary atIndex:currentIndexCount+1];
						
			[trimmedTitleTag release];
			[trimmedSourceTag release];
			
			[item release];
			[itemSecondary release];

			
		}
		
		
		// if (runningDebug == 1) NSLog(@"Checking if last time had same");
			
		if (![lastIds containsObject:[ids objectAtIndex:j]]){
			
			// Growl help
			[newItems addObject:[results objectAtIndex:j]];
			newCount++;

		}
		
		currentIndexCount++;
		currentIndexCount++; // the extra one is because we add two menuitems now, one for command-tabbing

	}
											
	if ([results count] == 0) {

		[statusItem setImage:nounreadItemsImage];

	} else {

		[statusItem setImage:unreadItemsImage];

		if (newCount != 0) {
			// Growl
			[self announce];
		}

		if (newCount != 0 && [[prefs valueForKey:@"dontPlaySound"] boolValue] != YES) {
					
			// Sound notification
			theSound = [NSSound soundNamed:@"beep.aiff"];
			[theSound play];
			[theSound release];
		}

		if ([results count] == 0) {
			[self displayMessage:[NSString stringWithFormat:NSLocalizedString(@"No unread items",nil),[results count]]];
		} else if ([results count] > 0 && [[prefs valueForKey:@"minimalFunction"] boolValue] == YES && moreUnreadExistInGRInterface == YES) {
			[self displayMessage:[NSString stringWithFormat:NSLocalizedString(@"More than %d unread items",nil),[results count]]];
		// } else if ([results count] > 0 && [[prefs valueForKey:@"minimalFunction"] boolValue] == YES) {
		//	[self displayMessage:[NSString stringWithFormat:NSLocalizedString(@"%d Unread",nil),[results count]]];
		}

	}

	if ([[prefs valueForKey:@"showCount"] boolValue] == YES) {

		if (moreUnreadExistInGRInterface == YES) {
			[statusItem setLength:NSVariableStatusItemLength];
			// [statusItem setTitle:[NSString stringWithFormat:@"%d+",[results count]]];
			[statusItem setAttributedTitle:[self makeAttributedStatusItemString:[NSString stringWithFormat:@"%d+",totalUnreadItemsInGRInterface]]];
		} else if ([results count] > 0) {
			[statusItem setLength:NSVariableStatusItemLength];			
			// [statusItem setTitle:[NSString stringWithFormat:@"%d",[results count]]];
			[statusItem setAttributedTitle:[self makeAttributedStatusItemString:[NSString stringWithFormat:@"%d",[results count]]]];
		} else {
			// [statusItem setTitle:@""];
			[statusItem setAttributedTitle:[self makeAttributedStatusItemString:@""]];
			[statusItem setLength:ourStatusItemWithLength];
		}
		
	} else {
		[statusItem setLength:ourStatusItemWithLength];
	}
	
	if (moreUnreadExistInGRInterface == YES) {
		// [statusItem setToolTip:[NSString stringWithFormat:@"Unread Items: %d+",[results count]]];
		[statusItem setToolTip:[NSString stringWithFormat:NSLocalizedString(@"Unread Items: %d+",nil),totalUnreadItemsInGRInterface]];
		[self displayTopMessage:[NSString stringWithFormat:NSLocalizedString(@"%d+ Unread",nil),totalUnreadItemsInGRInterface]];
	} else if ([results count] > 0) {
		[statusItem setToolTip:[NSString stringWithFormat:NSLocalizedString(@"Unread Items: %d",nil),[results count]]];
		[self displayTopMessage:[NSString stringWithFormat:NSLocalizedString(@"%d Unread",nil),[results count]]];
	} else {
		[statusItem setToolTip:NSLocalizedString(@"No Unread Items",nil)];
		// [self displayMessage:[NSString stringWithFormat:@"%d Unread",[results count]]]
		[self displayTopMessage:@""];
	}
	
	int n1;
	n1 = [GRMenu numberOfItems];
	int v1;
	for(v1=0; v1<n1; v1++) {
		[GRMenu itemChanged:[GRMenu itemAtIndex:v1]];
	}	
	
	[statusItem setMenu:GRMenu];


	
	currentlyFetchingAndUpdating = NO;
		
	// if (runningDebug == 1) NSLog(@"Done updating menu");
	
	// [statusItem setMenu:tempMenuSec];
	
	if (runningDebug == 1) NSLog(@"updateMenu end");
	
	
	
	
	
	// debug
	
		if (runningDebug == 1) NSLog(@"feeds count: %d", [feeds count]);
		if (runningDebug == 1) NSLog(@"ids count: %d", [ids count]);
		if (runningDebug == 1) NSLog(@"links count: %d", [links count]);
		if (runningDebug == 1) NSLog(@"titles count: %d", [titles count]);
		if (runningDebug == 1) NSLog(@"sources count: %d", [sources count]);
		if (runningDebug == 1) NSLog(@"summaries count: %d", [summaries count]);
		if (runningDebug == 1) NSLog(@"torrentcastlinks count: %d", [torrentcastlinks count]);

		
	// threading
	[pool release];

		
}

- (void)downloadFile:(NSString *)url:(NSString *)filename
{


				NSError *error;
				NSURLResponse *response;
				NSData *dataReply;
				NSMutableURLRequest *DownloadRequest = [NSMutableURLRequest  requestWithURL: [NSURL URLWithString:url]];
				[DownloadRequest setTimeoutInterval:5.0];
				[DownloadRequest setHTTPMethod:@"GET"]; // Changing the setHTTPMethod to "POST" sends the HTTPBody
	
				dataReply = [NSURLConnection sendSynchronousRequest:DownloadRequest returningResponse:&response error:&error];

				[dataReply writeToFile:[NSString stringWithFormat:@"%@/%@", [prefs valueForKey:@"torrentCastFolderPath"], filename] atomically:YES];



}


- (void)displayAlert:(NSString *) headerText:(NSString *) bodyText
{

		[NSApp activateIgnoringOtherApps:YES];		
	    NSAlert *theAlert = [[NSAlert alloc] init];
		theAlert = [NSAlert alertWithMessageText:headerText
			defaultButton:NSLocalizedString(@"Thanks",nil)
			alternateButton:nil
			otherButton:nil
			informativeTextWithFormat:bodyText];
		
		[self performSelectorOnMainThread:@selector(displayAlertOnMainThread:) withObject:theAlert waitUntilDone:YES];

		// [theAlert runModal];
		// [theAlert release];

}

- (void)displayAlertOnMainThread:(NSAlert *)aAlert
{

	[aAlert runModal];

}

- (void)removeNumberOfItemsFromMenubar:(int) number
{

	int n;
	n = number;
	int v;
	for(v=itemsExclPreviewFields; v<n; v++) {
		// [[GRMenu itemAtIndex:indexOfPreviewFields] release];
		[[GRMenu itemAtIndex:indexOfPreviewFields] setEnabled:NO];
		[GRMenu removeItemAtIndex:indexOfPreviewFields];
	//	[GRMenu removeItem:[GRMenu itemAtIndex:indexOfPreviewFields]];
	}	
	
}

- (void)clearMenuAndSetUpdatingState
{
	int n;
	n = [GRMenu numberOfItems];
	int v;
	for(v=itemsExclPreviewFields; v<n; v++) {
		// [[GRMenu itemAtIndex:indexOfPreviewFields] release];
		[[GRMenu itemAtIndex:indexOfPreviewFields] setEnabled:NO];
		[GRMenu removeItemAtIndex:indexOfPreviewFields];
	//	[GRMenu removeItem:[GRMenu itemAtIndex:indexOfPreviewFields]];
	}	

	[GRMenu insertItem:[NSMenuItem separatorItem] atIndex:indexOfPreviewFields];
	[GRMenu insertItemWithTitle:NSLocalizedString(@"Updating...",nil) action:nil keyEquivalent:@"" atIndex:indexOfPreviewFields];
}

- (void)removeAllItemsFromMenubar
{

	int n;
	n = [GRMenu numberOfItems];
	int v;
	for(v=itemsExclPreviewFields; v<n; v++) {
		// [[GRMenu itemAtIndex:indexOfPreviewFields] release];
		[[GRMenu itemAtIndex:indexOfPreviewFields] setEnabled:NO];
		[GRMenu removeItemAtIndex:indexOfPreviewFields];
	//	[GRMenu removeItem:[GRMenu itemAtIndex:indexOfPreviewFields]];
	}	
	
}

- (void)displayMessage:(NSString *)message
{

	// clear out the previewField so that we can put a "No connection" error
	int v,a;
	a = [GRMenu numberOfItems];

	for(v=itemsExclPreviewFields; v<a; v++) {
		[[GRMenu itemAtIndex:indexOfPreviewFields] setEnabled:NO];
		[GRMenu removeItemAtIndex:indexOfPreviewFields];
	}

	// put in the message
	[[GRMenu itemAtIndex:2] setAttributedTitle:[self makeAttributedMenuString:NSLocalizedString(@"Check Now",nil):message]];
	// [GRMenu insertItem:[NSMenuItem separatorItem] atIndex:3];
	// [GRMenu insertItemWithTitle:message action:@selector(launchSite:) keyEquivalent:@"" atIndex:indexOfPreviewFields];

}

- (void)displayLastTimeMessage:(NSString *)message
{
	[[GRMenu itemAtIndex:2] setAttributedTitle:[self makeAttributedMenuString:NSLocalizedString(@"Check Now",nil):message]];
}

- (void)displayTopMessage:(NSString *)message
{

	// clear out the previewField so that we can put a "No connection" error
	// int v,a;
	// a = [GRMenu numberOfItems];

	// for(v=itemsExclPreviewFields; v<a; v++) {
	//	[[GRMenu itemAtIndex:indexOfPreviewFields] setEnabled:NO];
	// 	[GRMenu removeItemAtIndex:indexOfPreviewFields];
	// }

	// put in the message
	[[GRMenu itemAtIndex:0] setAttributedTitle:[self makeAttributedMenuString:NSLocalizedString(@"Go to Reader",nil):message]];
	// [GRMenu insertItem:[NSMenuItem separatorItem] atIndex:3];
	// [GRMenu insertItemWithTitle:message action:@selector(launchSite:) keyEquivalent:@"" atIndex:indexOfPreviewFields];

}

- (NSString *)searchAndReplace:(NSString *)searchString:(NSString *)replaceString:(NSString *)inString
{

	NSMutableString *mstr;
	NSRange substr;
	
	mstr = [NSMutableString stringWithString:inString];
	substr = [mstr rangeOfString:searchString];
	
	while (substr.location != NSNotFound) {
		[mstr replaceCharactersInRange:substr withString:replaceString];
        substr = [mstr rangeOfString:searchString];
    }
	
	// [mstr autorelease]; // denne skal mŒske ind igen?
	
	// return [NSString stringWithString:mstr];
	return mstr;

}

- (NSString *)grabUserNo
{

		NSString *storedUserNo;

		NSScanner *theScanner;
		theScanner = [NSScanner scannerWithString:[[user objectAtIndex:0] stringValue]];
	
		if ([theScanner scanString:@"tag:google.com,2005:reader/user/" intoString:NULL] &&
			[theScanner scanUpToString:@"/" intoString:&storedUserNo]) {
			// [theScanner scanUpToString:@"/state/com.google/reading-list" intoString:&storedUserNo]) {
			storedUserNo = [NSString stringWithString:storedUserNo];
			// if (runningDebug == 1) NSLog(storedUserNo);
			
		} else {
			storedUserNo = @"";
			if (runningDebug == 1) NSLog(@"Something wrong with the userNo retrieval");
			[self displayMessage:@"no user on server"];
			[self displayAlert:NSLocalizedString(@"No user",nil):NSLocalizedString(@"We cannot find your user, which is pretty strange. Report this if you are sure to be connected to the internet.",nil)];
		}


return storedUserNo;

}


- (NSString *)getGoogleSIDClean
{

	// the problem with loginToGoogle is that you get SID=34935785; Ð we need it without the SID= and ; at the end.

	NSString *stringReply;
	stringReply = [self loginToGoogle];
	
	if (![stringReply isEqualToString:@""]) {
			
		NSScanner *theScanner;
		theScanner = [NSScanner scannerWithString:[NSString stringWithString:stringReply]];
	
		if ([theScanner scanString:@"SID=" intoString:NULL] &&
			[theScanner scanUpToString:@"\nLSID=" intoString:&storedSID]) {

			return [NSString stringWithFormat:@"%@", storedSID];
	
		} else {
		
			return [NSString stringWithString:@""];

		}
		
		
	} else {
	
		return [NSString stringWithString:@""];
	
	}
	


}


- (NSString *)loginToGoogle
{

/// if ([storedSID isEqualToString:@""]) {
if ([[prefs valueForKey:@"storedSID"] isEqualToString:@""]) {
/// if (true) {

	NSString *stringReply;
	stringReply = [self sendConnectionRequest:@"https://www.google.com/accounts/ClientLogin":YES:@"":@"POST":[NSString stringWithFormat:@"Email=%@&Passwd=%@&service=cl&source=TroelsBay-ReaderNotifier-build%d",CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)[prefs valueForKey:@"Username"], NULL, (CFStringRef)@";/?:@&=+$,", kCFStringEncodingUTF8), CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)[self getUserPasswordFromKeychain], NULL, (CFStringRef)@";/?:@&=+$,", kCFStringEncodingUTF8), versionBuildNumber]];
	
	if ([stringReply isEqualToString:@""]) {
	
		storedSID = @""; // userSID = @"";
		[prefs setObject:@"" forKey:@"storedSID"];
		[self displayMessage:@"no Internet connection"];
		[self errorImageOn];
		
		[statusItem setMenu:GRMenu];
		
		[lastCheckTimer invalidate];
		[self createLastCheckTimer];
		[lastCheckTimer fire];
		
		
	} else {
		
		NSScanner *theScanner;
		theScanner = [NSScanner scannerWithString:[NSString stringWithString:stringReply]];
	
		if ([theScanner scanString:@"SID=" intoString:NULL] &&
			[theScanner scanUpToString:@"\nLSID=" intoString:&storedSID]) {

			storedSID = [NSString stringWithFormat:@"SID=%@;",storedSID]; // userSID = [NSString stringWithFormat:@"SID=%@;",userSID];
	
			[prefs setObject:storedSID forKey:@"storedSID"];
	
		} else {
		
		
			if ([[self getUserPasswordFromKeychain] isEqualToString:@""]) {

				[self displayAlert:NSLocalizedString(@"Error",nil):NSLocalizedString(@"It seems you do not have a password in the Keychain. Please go to the preferences now and supply your password",nil)];
				[self displayMessage:@"please enter login details"];
				
			} else if ([[prefs valueForKey:@"Username"] isEqualToString:@""] || [prefs valueForKey:@"Username"] == NULL) {

				[self displayAlert:NSLocalizedString(@"Error",nil):NSLocalizedString(@"It seems you do not have a username filled in. Please go to the preferences now and supply your username",nil)];
				[self displayMessage:@"please enter login details"];
				
			} else {

				[self displayAlert:NSLocalizedString(@"Authentication error",nil):[NSString stringWithFormat:@"Reader Notifier could not handshake with Google. You probably have entered a wrong user or pass. The error supplied by Google servers was: %@", stringReply]];
				[self displayMessage:@"wrong user or pass"];				
			
			}
		
			storedSID = @""; // userSID = @"";
			[prefs setObject:@"" forKey:@"storedSID"];
			[self errorImageOn];
			

		}
		
		// [theScanner release];
		
	}
	
	[stringReply release];

}

// return storedSID; // return userSID;
return [prefs valueForKey:@"storedSID"];

}


- (void)checkNowWithDelayDetached:(NSNumber *)delay
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSDate *sleepUntil = [NSDate dateWithTimeIntervalSinceNow:[delay floatValue]];
	[NSThread sleepUntilDate:sleepUntil];

	[self checkNow:nil];

	[pool release];
}


- (IBAction)checkNow:(id)sender
{

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	/* first we check if the user has put in a password and username beforehand */
	if ([[self getUserPasswordFromKeychain] isEqualToString:@""]) {

		[self displayAlert:NSLocalizedString(@"Error",nil):NSLocalizedString(@"It seems you do not have a password in the Keychain. Please go to the preferences now and supply your password",nil)];
		[self errorImageOn];
		storedSID = @""; // userSID = @"";

	
	} else if ([[prefs valueForKey:@"Username"] isEqualToString:@""] || [prefs valueForKey:@"Username"] == NULL) {
	
		[self displayAlert:NSLocalizedString(@"Error",nil):NSLocalizedString(@"It seems you do not have a username filled in. Please go to the preferences now and supply your username",nil)];
		[self errorImageOn];
		storedSID = @""; // userSID = @"";
	
	} else {
	
		/* then we make sure it has validated and provided us with a login */
		if (![[self loginToGoogle] isEqualToString:@""]) {

			/* then we make sure that it's not already running */
			if (currentlyFetchingAndUpdating != YES) {

				// threading
				[mainTimer invalidate];	
				[self setTimeDelay:[[prefs valueForKey:@"timeDelay"] intValue]];
				[NSThread detachNewThreadSelector:@selector(retrieveGoogleFeed) toTarget:self withObject:nil];

			}

		}
	
	}


	// [self performSelectorOnMainThread:@selector(updateMenu) withObject:nil waitUntilDone:NO];
	
	
	// threading disabled
	//	[mainTimer invalidate];
	//	[self setTimeDelay:[[prefs valueForKey:@"timeDelay"] intValue]];
	
	[pool release];
}


- (IBAction)launchSite:(id)sender
{
// nologin	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@://www.google.com/reader/", [self getURLPrefix]]]];
// login through plaintext password	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/accounts/ServiceLoginAuth?service=reader&Email=%@&Passwd=%@&continue=http://google.com/reader", [prefs valueForKey:@"Username"], [self getUserPasswordFromKeychain]]]];

[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/accounts/SetSID?ssdc=1&sidt=%@&continue=http%%3A%%2F%%2Fgoogle.com%%2Freader%%2Fview%%2F", [self getGoogleSIDClean]]]];


}

- (NSString *)getTokenFromGoogle
{
	return [self sendConnectionRequest:[NSString stringWithFormat:@"%@://www.google.com/reader/api/0/token", [self getURLPrefix]]:YES:[self loginToGoogle]:@"GET":@""];	
}


- (void)markOneAsStarredDetached:(NSNumber *)aNumber
{

	// threading
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	int index;
	index = [aNumber intValue];


//	NSString *feedstring = [[NSString alloc] initWithString:[feeds objectAtIndex:index]];
	NSString *feedstring;
	feedstring = [self searchAndReplace:@":":@"%3A":[feeds objectAtIndex:index]];
	feedstring = [self searchAndReplace:@"/":@"%2F":feedstring];
	feedstring = [self searchAndReplace:@"=":@"-":feedstring];

//	NSString *idsstring = [[NSString alloc] initWithString:[ids objectAtIndex:index]];
	NSString *idsstring;
	idsstring = [self searchAndReplace:@"/":@"%2F":[ids objectAtIndex:index]];
	idsstring = [self searchAndReplace:@",":@"%2C":idsstring];
	idsstring = [self searchAndReplace:@":":@"%3A":idsstring];

///	NSURL *markOneAsReadUrl = [NSURL URLWithString:[NSString stringWithString:[NSString stringWithFormat:@"%@://www.google.com/reader/api/0/edit-tag?client=scroll", [self getURLPrefix]]]];
///	NSMutableURLRequest *markOneRead = [NSMutableURLRequest requestWithURL:markOneAsReadUrl];
///	[markOneRead setHTTPMethod:@"POST"];
	
	// No label = state/com.google/reading-list // with label - see getLabel
//	NSString *sendString = [NSString stringWithFormat:@"s=%@&i=%@&ac=edit-tags&a=user%%2F%@%%2Fstate%%2Fcom.google%%2Fstarred&T=%@", feedstring, idsstring, [self grabUserNo], [self getTokenFromGoogle]];		
///	[markOneRead setHTTPBody:[[NSString stringWithFormat:@"s=%@&i=%@&ac=edit-tags&a=user%%2F%@%%2Fstate%%2Fcom.google%%2Fstarred&T=%@", feedstring, idsstring, [self grabUserNo], [self getTokenFromGoogle]] dataUsingEncoding:NSUTF8StringEncoding]];
///	[markOneRead setHTTPShouldHandleCookies:NO];
///	[markOneRead setTimeoutInterval:10.0];
///	[markOneRead setValue:[self loginToGoogle] forHTTPHeaderField:@"Cookie"];
///	NSURLConnection *markOneAsRead = [NSURLConnection connectionWithRequest:markOneRead delegate:self];

///	if (markOneAsRead) {
	
///	} else {
		// if (runningDebug == 1) NSLog(@"Oops");
///	}

//	if (runningDebug == 1) NSLog(@"Test");

	[self sendConnectionRequest:[NSString stringWithString:[NSString stringWithFormat:@"%@://www.google.com/reader/api/0/edit-tag?client=scroll", [self getURLPrefix]]]:YES:[self loginToGoogle]:@"POST":[NSString stringWithFormat:@"s=%@&i=%@&ac=edit-tags&a=user%%2F%@%%2Fstate%%2Fcom.google%%2Fstarred&T=%@", feedstring, idsstring, [self grabUserNo], [self getTokenFromGoogle]]];

///	[idsstring release];
///	[feedstring release];

//	if (runningDebug == 1) NSLog(@"Test2");

	[NSThread detachNewThreadSelector:@selector(markOneAsReadDetached:) toTarget:self withObject:[NSNumber numberWithInt:index]];

	// currentlyFetchingAndUpdating = NO;
	
	// threading
	[pool release];

}



- (void)markOneAsReadDetached:(NSNumber *)aNumber
{

	// threading
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	if (runningDebug == 1) NSLog(@"markOneAsReadDetatched begin");
	
	int index;
	index = [aNumber intValue];
	
	if ([feeds count] >= index+1 && [feeds count] >= index+1) {

		// we replace all instances of = to %3D for google
		NSMutableString *feedstring = [[NSMutableString alloc] initWithString:[feeds objectAtIndex:index]];
		[feedstring replaceOccurrencesOfString:@"=" withString:@"-" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [feedstring length])];

		[self sendConnectionRequest:[NSString stringWithFormat:@"%@://www.google.com/reader/api/0/edit-tag?s=%@&i=%@&ac=edit-tags&a=user/-/state/com.google/read&r=user/-/state/com.google/kept-unread&T=%@",[self getURLPrefix],feedstring,[ids objectAtIndex:index],[self getTokenFromGoogle]]:YES:[self loginToGoogle]:@"POST":@""];
	
		[feedstring release];

		// at the end of this we will also remove the tempMenuSec and insert GRMenu
		[self removeOneItemFromMenu:index];
	
	} else {
		if (runningDebug == 1) NSLog(@"markOneAsReadDetatched - there was not enough items in feeds or ids array");
	}
	
	currentlyFetchingAndUpdating = NO;
	
	if (runningDebug == 1) NSLog(@"markOneAsReadDetatched end");

	// threading
	[pool release];

}

- (void)markResultsAsReadDetached
{

	// threading
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	int j;
	for (j=0; j<[results count]; j++) {
	
		NSMutableString *feedstring = [[NSMutableString alloc] initWithString:[feeds objectAtIndex:j]];
		[feedstring replaceOccurrencesOfString:@"=" withString:@"-" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [feedstring length])];

		[self sendConnectionRequest:[NSString stringWithFormat:@"%@://www.google.com/reader/api/0/edit-tag?s=%@&i=%@&ac=edit-tags&a=user/-/state/com.google/read&r=user/-/state/com.google/kept-unread&T=%@",[self getURLPrefix],feedstring,[ids objectAtIndex:j],[self getTokenFromGoogle]]:YES:[self loginToGoogle]:@"POST":@""];
		
		[feedstring release];
		
	}
	
	currentlyFetchingAndUpdating = NO;
	// the statusItem is actually still tempMenuSec, but it doesn't matter because It'll go back to GRMenu after the end of CheckNow
	[NSThread detachNewThreadSelector:@selector(checkNow:) toTarget:self withObject:nil];

	// threading
	[pool release];

}



- (IBAction)openAllItems:(id)sender
{

	currentlyFetchingAndUpdating = YES;
	// tempMenuSec = [GRMenu copy];
	[statusItem setMenu:tempMenuSec];

	int j;
	for (j=0; j<[results count]; j++) {
	
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[links objectAtIndex:[[results objectAtIndex:j] intValue]]]];	
	}
	
	// [self clearMenuAndSetUpdatingState];
			
	[NSThread detachNewThreadSelector:@selector(markResultsAsReadDetached) toTarget:self withObject:nil];
	
}

- (void)markAllAsReadDetached
{

	// threading
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[statusItem setMenu:tempMenuSec];

	if ([self getUnreadCount] == [results count] || [[prefs valueForKey:@"alwaysEnableMarkAllAsRead"] boolValue] == YES) {

		[self sendConnectionRequest:[NSString stringWithFormat:@"%@://www.google.com/reader/api/0/mark-all-as-read?client=scroll", [self getURLPrefix]]:YES:[self loginToGoogle]:@"POST":[NSString stringWithFormat:@"s=user%%2F%@%%2F%@&T=%@", [self grabUserNo], [self searchAndReplace:@"/" :@"%2F" :[self getLabel]], [self getTokenFromGoogle]]];
				
///		if (markAllAsRead) {
		
			[lastIds setArray:ids];
			[results removeAllObjects];
		//	[results removeObjectAtIndex:launchindex];
			[feeds removeAllObjects];
			[ids removeAllObjects];
			[links removeAllObjects];
			[titles removeAllObjects];
			[sources removeAllObjects];

			[[NSNotificationCenter defaultCenter] postNotificationName:@"PleaseUpdateMenu" object:nil];
			// [self updateMenu];
			
///		} else {
			// trouble
///		}
	
	} else {
	
		if (totalUnreadItemsInGRInterface != -1) {
	
		[self displayAlert:NSLocalizedString(@"Warning",nil) :NSLocalizedString(@"There are new unread items available online. Mark all as read has been canceled.",nil)];
		[self retrieveGoogleFeed];
//		[self checkNow:nil];
		if (runningDebug == 1) NSLog(@"Error marking all as read");
		
		}
		
	}

	[pool release];

}

- (IBAction)markAllAsRead:(id)sender
{

	if (runningDebug == 1) NSLog(@"markAllAsRead begin");

	currentlyFetchingAndUpdating = YES;
	// tempMenuSec = [GRMenu copy];
	[statusItem setMenu:tempMenuSec];

	[NSThread detachNewThreadSelector:@selector(markAllAsReadDetached) toTarget:self withObject:nil];

	// if (runningDebug == 1) NSLog(@"%d", [self getUnreadCount]);

	if (runningDebug == 1) NSLog(@"markAllAsRead end");

}


- (IBAction)launchLink:(id)sender
{
//	int index = [[sender title] intValue];

	if (runningDebug == 1) NSLog(@"launchLink begin");
		
		// tempMenuSec = [GRMenu copy];
		

		// Because we cannot be absolutely sure that the user has not clicked the GRMenu before a new update has occored (we make use of the id - and hopefully it will be an absolute). 
		// if (runningDebug == 1) NSLog(@"Ids is %@", [sender title]);

		if ([ids containsObject:[sender title]]) {
		
			currentlyFetchingAndUpdating = YES;
		
			[statusItem setMenu:tempMenuSec];
			
			if ([[prefs valueForKey:@"showCount"] boolValue] == YES) {
				[statusItem setAttributedTitle:[self makeAttributedStatusItemString:[NSString stringWithFormat:@"%d",[results count]-1]]];
			}
			
			
			int index = [ids indexOfObjectIdenticalTo:[sender title]];
			if (runningDebug == 1) NSLog(@"Index is %d", index);
			
		    if (runningDebug == 1) NSLog(@"NUMBER OF ITEMS IS, %d", [GRMenu numberOfItems]);
			if ([GRMenu numberOfItems] == 9) {
				[GRMenu removeItemAtIndex:index+indexOfPreviewFields];
				[GRMenu removeItemAtIndex:index+indexOfPreviewFields]; // the shaddow (optional-click
				[GRMenu removeItemAtIndex:index+indexOfPreviewFields]; // the space-line
			} else {
				[GRMenu removeItemAtIndex:index+indexOfPreviewFields];
			}
		
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[links objectAtIndex:index]]];

	///		[self markOneAsRead:index];
			[NSThread detachNewThreadSelector:@selector(markOneAsReadDetached:) toTarget:self withObject:[NSNumber numberWithInt:index]];

			// [self removeOneItemFromMenu:index];
		
		} else {
			if (runningDebug == 1) NSLog(@"Item has already gone away, so we cannot refetch it");
		}
		
		
	if (runningDebug == 1) NSLog(@"launchLink end");	
	

}

- (IBAction)doOptionalActionFromMenu:(id)sender
{

	currentlyFetchingAndUpdating = YES;

	[statusItem setMenu:tempMenuSec];


	// int index = [[sender title] intValue];
		
	// Because we cannot be absolutely sure that the user has not clicked the GRMenu before a new update has occored (we make use of the id - and hopefully it will be an absolute). 
	// if (runningDebug == 1) NSLog(@"Ids is %@", [sender title]);
	
	if ([ids containsObject:[sender title]]) {

		int index = [ids indexOfObjectIdenticalTo:[sender title]];
		// if (runningDebug == 1) NSLog(@"Index is %d", index);

	
	
		if ([[prefs valueForKey:@"onOptionalActAlsoStarItem"] boolValue] == YES) {

			// [self markOneAsStarred:index];
			[NSThread detachNewThreadSelector:@selector(markOneAsStarredDetached:) toTarget:self withObject:[NSNumber numberWithInt:index]];

		} else {

			[NSThread detachNewThreadSelector:@selector(markOneAsReadDetached:) toTarget:self withObject:[NSNumber numberWithInt:index]];		
		
		}
	
//		[self markOneAsRead:index];

		// [self removeOneItemFromMenu:index];
		
	} else {
	
		currentlyFetchingAndUpdating = NO;
	
		if (runningDebug == 1) NSLog(@"Item has already gone away, so we cannot refetch it");
		
	}
	
	
}

- (void)removeOneItemFromMenu:(int)index
{
	
		if (runningDebug == 1) NSLog(@"removeOneItemFromMenu begin");
		
		if (runningDebug == 1) NSLog(@"feeds count: %d", [feeds count]);
		if (runningDebug == 1) NSLog(@"ids count: %d", [ids count]);
		if (runningDebug == 1) NSLog(@"links count: %d", [links count]);
		if (runningDebug == 1) NSLog(@"titles count: %d", [titles count]);
		if (runningDebug == 1) NSLog(@"sources count: %d", [sources count]);
		if (runningDebug == 1) NSLog(@"summaries count: %d", [summaries count]);
		if (runningDebug == 1) NSLog(@"torrentcastlinks count: %d", [torrentcastlinks count]);

	
		[lastIds setArray:ids];
		[results removeAllObjects];
		
		if (runningDebug == 1) NSLog(@"ids count %d >= index %d", [ids count], index);
		
		if ([ids count] >= index+1 && 
			[feeds count] >= index+1 && 
			[links count] >= index+1 && 
			[titles count] >= index+1 && 
			[sources count] >= index+1 &&
			[summaries count] >= index+1 &&
			[torrentcastlinks count] >= index+1) {

			if (runningDebug == 1) NSLog(@"feeds count: %d", [feeds count]);
			[feeds removeObjectAtIndex:index];
			
			if (runningDebug == 1) NSLog(@"ids count: %d", [ids count]);
			[ids removeObjectAtIndex:index];

			if (runningDebug == 1) NSLog(@"links count: %d", [links count]);
			[links removeObjectAtIndex:index];

			if (runningDebug == 1) NSLog(@"titles count: %d", [titles count]);
			[titles removeObjectAtIndex:index];

			if (runningDebug == 1) NSLog(@"sources count: %d", [sources count]);
			[sources removeObjectAtIndex:index];

			if (runningDebug == 1) NSLog(@"summaries count: %d", [summaries count]);
			[summaries removeObjectAtIndex:index];
		
			if (runningDebug == 1) NSLog(@"torrentcastlinks count: %d", [torrentcastlinks count]);
			[torrentcastlinks removeObjectAtIndex:index];
		
			if (runningDebug == 1) NSLog(@"running updateMenu from removeOneItemFromMenu");
			[self updateMenu];

		} else {
			if (runningDebug == 1) NSLog(@"Err. this and that did not match, we don't remove anything");
		}
		
		if (runningDebug == 1) NSLog(@"removeOneItemFromMenu end");
	
}

- (void)markOneAsStarred:(int)index
{

	NSString *feedstring;
	feedstring = [self searchAndReplace:@":":@"%3A":[feeds objectAtIndex:index]];
	feedstring = [self searchAndReplace:@"/":@"%2F":feedstring];
	feedstring = [self searchAndReplace:@"=":@"-":feedstring];

	NSString *idsstring;
	idsstring = [self searchAndReplace:@"/":@"%2F":[[ids objectAtIndex:index] stringValue]];
	idsstring = [self searchAndReplace:@",":@"%2C":idsstring];
	idsstring = [self searchAndReplace:@":":@"%3A":idsstring];

	NSURL *markOneAsReadUrl = [NSURL URLWithString:[NSString stringWithString:[NSString stringWithFormat:@"%@://www.google.com/reader/api/0/edit-tag?client=scroll", [self getURLPrefix]]]];
	NSMutableURLRequest *markOneRead = [NSMutableURLRequest requestWithURL:markOneAsReadUrl];
	[markOneRead setHTTPMethod:@"POST"];
	
	// No label = state/com.google/reading-list // with label - see getLabel
	NSString *sendString = [NSString stringWithFormat:@"s=%@&i=%@&ac=edit-tags&a=user%%2F%@%%2Fstate%%2Fcom.google%%2Fstarred&T=%@", feedstring, idsstring, [self grabUserNo], [self getTokenFromGoogle]];	

	
	[markOneRead setHTTPBody:[sendString dataUsingEncoding:NSUTF8StringEncoding]];
	if (isLeopard) {
		[markOneRead setHTTPShouldHandleCookies:NO];
	} else {
		[markOneRead setHTTPShouldHandleCookies:YES];
	}
	[markOneRead setTimeoutInterval:5.0];
	[markOneRead setValue:[self loginToGoogle] forHTTPHeaderField:@"Cookie"];
	NSURLConnection *markOneAsRead = [NSURLConnection connectionWithRequest:markOneRead delegate:self];

	if (markOneAsRead) {
	
	} else {
		// if (runningDebug == 1) NSLog(@"Oops");
	}

}


- (void)markOneAsRead:(int)index
{

	// threading
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	
	// we replace all instances of = to %3D for google
	NSMutableString *feedstring = [[feeds objectAtIndex:index] mutableCopy];
	[feedstring replaceOccurrencesOfString:@"=" withString:@"-" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [feedstring length])];

	NSURL *posturl = [NSURL URLWithString:[NSString stringWithFormat:@"%@://www.google.com/reader/api/0/edit-tag?s=%@&i=%@&ac=edit-tags&a=user/-/state/com.google/read&r=user/-/state/com.google/kept-unread&T=%@",[self getURLPrefix],feedstring,[ids objectAtIndex:index],[self getTokenFromGoogle]]];
	NSMutableURLRequest *postread = [NSMutableURLRequest requestWithURL:posturl];
	[postread setTimeoutInterval:5.0];
	if (isLeopard) {
		[postread setHTTPShouldHandleCookies:NO];
	} else {
		[postread setHTTPShouldHandleCookies:YES];
	}
	[postread setValue:[self loginToGoogle] forHTTPHeaderField:@"Cookie"];
	[postread setHTTPMethod:@"POST"];
//	[postread setHTTPMethod:@"PUT"]; //will disable markasread, for debug purpuses
	
	NSURLConnection *markread = [NSURLConnection connectionWithRequest:postread delegate:self];

	if(markread){
	
	} else{

		// if (runningDebug == 1) NSLog(@"Oops");

	}
	
	//[markread autorelease];
	
	// threading
	[pool release];

}

- (void)errorImageOn
{

	if ([[prefs valueForKey:@"showCount"] boolValue] == YES) {
		[statusItem setAttributedTitle:[self makeAttributedStatusItemString:@""]];
	}

	[statusItem setToolTip:NSLocalizedString(@"Failed to connect to Google Reader. Please try again.",nil)];
	[statusItem setAlternateImage:errorImage];
	[statusItem setImage:errorImage];
	
	[statusItem setMenu:GRMenu];
	
	storedSID = @"";
	
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	//if([[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] isEqualToString:@"OK"]){
	
	//}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    //if (runningDebug == 1) NSLog([response description]);
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	//[connection release];
	
    if (runningDebug == 1) NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSErrorFailingURLStringKey]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	//[connection release];
}

- (NSString *)getLabel
{
	if ([[prefs valueForKey:@"Label"] isEqualToString:@""]){
		return @"state/com.google/reading-list";
	} else{
		return [NSString stringWithFormat:@"label/%@",[prefs valueForKey:@"Label"]];
	}
}

- (NSString *)flattenHTML:(NSString *)stringToFlatten
{

//	NSString *result = [NSString alloc];
//	result = [self searchAndReplace:@"&amp;" :@"&" :stringToFlatten];

	stringToFlatten = [self searchAndReplace:@"&quot;" :@"\"" :stringToFlatten];
	stringToFlatten = [self searchAndReplace:@"&amp;" :@"&" :stringToFlatten];
	stringToFlatten = [self searchAndReplace:@"&#39;" :@"'" :stringToFlatten];



// MEMORY ERROR SEEMS TO BE HERE?!

//	NSString *result;

//	if (![stringToFlatten isEqualToString:@""])	// if empty string, don't do this!  You get junk.
//	{
//		int encoding = ([stringToFlatten length] > 3) ? NSUnicodeStringEncoding : NSMacOSRomanStringEncoding;
//		NSAttributedString *attrString;
//		NSData *theData = [stringToFlatten dataUsingEncoding:encoding];
//		if (nil != theData)	// this returned nil once; not sure why; so handle this case.
//		{
//			NSDictionary *encodingDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:encoding] forKey:@"CharacterEncoding"];
//			attrString
//				= [[NSAttributedString alloc]
//					initWithHTML:theData documentAttributes:&encodingDict];
//			result = [[[attrString string] retain] autorelease];	// keep only this
//			[attrString release];	// don't do autorelease since this is so deep down.
//		}
//	}
//	return result;

//	NSData *theData = [stringToFlatten dataUsingEncoding:NSUnicodeStringEncoding allowLossyConversion:YES];
//	NSDictionary *encodingDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:NSUnicodeStringEncoding], @"CharacterEncoding", nil];
//	NSAttributedString *result = [[[NSAttributedString alloc] initWithHTML:theData options:nil documentAttributes:&encodingDict] autorelease];	

//	NSString *endResult = [[NSString alloc] initWithString:[result string]];

//	return endResult;
	return stringToFlatten;
	
}

- (NSMutableArray *)reverseArray:(NSMutableArray *)array
{
	int i;
	for (i=0; i<(floor([array count]/2.0)); i++) {
		[array exchangeObjectAtIndex:i withObjectAtIndex:([array count]-(i+1))];
	}
	
	return array;
}

- (IBAction)launchErrorHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://troelsbay.eu/software/reader"]];
}

- (void)addFeed:(NSString *)url
{

	if ([[prefs valueForKey:@"dontVerifySubscription"] boolValue] != YES) {

		// [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[[NSString stringWithFormat:@"%@://www.google.com/reader/preview/*/feed/", [self getURLPrefix]] stringByAppendingString:url]]];			
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[[NSString stringWithFormat:@"%@://www.google.com/reader/preview/*/feed/", [self getURLPrefix]] stringByAppendingString:[NSString stringWithFormat:@"%@", CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)url, NULL, (CFStringRef)@";/?:@&=+$,", kCFStringEncodingUTF8)]]]];			
			
			
	} else {

		// Here we should implement a check if there actually is no feed there :(
				
		// NSString *stringReply;
		// stringReply = [self sendConnectionRequest:[NSString stringWithFormat:@"%@://www.google.com/reader/api/0/subscription/edit?client=scroll", [self getURLPrefix]]:YES:[self loginToGoogle]:@"POST":[NSString stringWithFormat:@"s=feed%%2F%@&i=null&ac=subscribe&T=%@", [self searchAndReplace:@":":@"%3A":[self searchAndReplace:@"/":@"%2F":url]], [self getTokenFromGoogle]]];
				
		// if ([stringReply isEqualToString:@"OK"]) {
		
		NSURL *posturl = [NSURL URLWithString:[NSString stringWithFormat:@"%@://www.google.com/reader/quickadd", [self getURLPrefix]]];
		NSMutableURLRequest *postread = [NSMutableURLRequest requestWithURL:posturl];
		[postread setTimeoutInterval:5.0];
		
				
		NSString *sendString = [NSString stringWithFormat:@"quickadd=%@&T=%@", CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)url, NULL, (CFStringRef)@";/?:@&=+$,", kCFStringEncodingUTF8), [self getTokenFromGoogle]];	
		// NSString *sendString = [NSString stringWithFormat:@"quickadd=%@&T=%@", [self searchAndReplace:@":":@"%3A": [self searchAndReplace:@"/":@"%2F":url]], [self getTokenFromGoogle]];	
		[postread setHTTPBody:[sendString dataUsingEncoding:NSUTF8StringEncoding]];
	if (isLeopard) {
		[postread setHTTPShouldHandleCookies:NO];
	} else {
		[postread setHTTPShouldHandleCookies:YES];
	}
		[postread setValue:[self loginToGoogle] forHTTPHeaderField:@"Cookie"];
		[postread setHTTPMethod:@"POST"];
		//	[postread setHTTPMethod:@"PUT"]; //will disable markasread, for debug purpuses
	
		NSURLConnection *subscribeReq = [NSURLConnection connectionWithRequest:postread delegate:self];

		if (subscribeReq) {
		
			// we need to sleep a little
			NSDate *sleepUntil = [NSDate dateWithTimeIntervalSinceNow:1.5];
			[NSThread sleepUntilDate:sleepUntil];

			// [GrowlApplicationBridge
			//		notifyWithTitle:@"New Subscription"
			//		description:@"Google Reader Notifier has just made a new subscription."
			//		notificationName:@"New Subscription"
			//		iconData:nil
			//		priority:0
			//		isSticky:NO
			//		clickContext:nil];
						
			// [self retrieveGoogleFeed];	
			
			[self checkNow:nil];
	
		} else {
		
			if (runningDebug == 1) NSLog(@"Oops, the subscription did not make it through");

		}
	
	//[markread autorelease];

							
		// } else {
		
		//	[self displayAlert:@"Error" :[NSString stringWithFormat:@"Google gave us an error:\n%@", stringReply]];
			
		// }
					
	}
				
}

- (IBAction)openPrefs:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[preferences makeKeyAndOrderFront:nil];
}

- (IBAction)openAddFeedWindow:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[addfeedwindow makeKeyAndOrderFront:nil];
	[addNewFeedUrlField setStringValue:@"http://"];
}

- (IBAction)addFeedFromUI:(id)sender
{
	
	[addfeedwindow close];

	// [self displayAlert:@"test":[addNewFeedUrlField stringValue]];
	[self addFeed:[addNewFeedUrlField stringValue]];

}

- (void)dealloc
{
    [statusItem release];
    [mainTimer invalidate];
    [mainTimer release];
	[lastCheckTimer invalidate];
	[lastCheckTimer release];
	[prefs release];
    [super dealloc];
}

- (IBAction)checkGoogleAuth:(id)sender
{

	storedSID = @"";
	//	storedUserNo = @"";
	
	[prefs setObject:[NSString stringWithString:[usernameField stringValue]] forKey:@"Username"];
	
	NSString *password;
	password = [passwordField stringValue];
		
	if ([Keychain checkForExistanceOfKeychain] > 0) {
		[Keychain modifyKeychainItem:password];
	} else {
		[Keychain addKeychainItem:password];
	}
	
	if (![[self loginToGoogle] isEqualToString:@""]) {
		[self displayAlert:NSLocalizedString(@"Success",nil):NSLocalizedString(@"You are now connected to Google",nil)];
		[mainTimer invalidate];
		[self setTimeDelay:[[prefs valueForKey:@"timeDelay"] intValue]];
		[mainTimer fire];
	} else {
		[self displayAlert:NSLocalizedString(@"Error",nil):NSLocalizedString(@"Unable to connect to Google with user details",nil)];	
	}
	
}

- (NSString *)getURLPrefix
{

	NSString *returnString;

	if ([[prefs valueForKey:@"alwaysUseHttps"] boolValue] == YES) {
		returnString = @"https";
	} else {
		returnString = @"http";
	}
	
	return returnString;

}

- (NSString *)getUserPasswordFromKeychain
{

	NSString *password;

	if ([Keychain checkForExistanceOfKeychain] < 1) {
		/* we moved the error somewhere else */
		/* [self displayAlert:@"Error":@"Wow, it seems you do not have a password in the Keychain (any longer?). Please go to the preferences now and supply your password"]; */
		password = @"";
	} else {
		password = [Keychain getPassword];
	}
	
	return password;

}

- (NSAttributedString *)makeAttributedStatusItemString:(NSString *)text
{
	
	// NSArray *normalSKeys = [NSArray arrayWithObjects: NSFontAttributeName, NSBaselineOffsetAttributeName, nil ];
	// NSArray *normalSObjects = [NSArray arrayWithObjects: [NSFont fontWithName:@"Lucida Grande" size:14.0], [NSNumber numberWithFloat:-1.0], nil];

//	NSDictionary *statusAttrsDictionary = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: [NSFont fontWithName:@"Lucida Grande" size:14.0], [NSNumber numberWithFloat:-1.0], nil] forKeys:[NSArray arrayWithObjects: NSFontAttributeName, NSBaselineOffsetAttributeName, nil ]];

// Don't work
//	NSMutableParagraphStyle *centeredStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
//	[centeredStyle setAlignment:NSCenterTextAlignment];

	NSDictionary *statusAttrsDictionary;

	if ([[prefs valueForKey:@"smallStatusItemFont"] boolValue] == YES) {

		statusAttrsDictionary = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSFont fontWithName:@"Lucida Grande" size:12.0], [NSNumber numberWithFloat:-0.0], nil] forKeys:[NSArray arrayWithObjects: NSFontAttributeName, NSBaselineOffsetAttributeName, nil ]];

	} else {
	
		statusAttrsDictionary = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSFont fontWithName:@"Lucida Grande" size:14.0], [NSNumber numberWithFloat:-0.0], nil] forKeys:[NSArray arrayWithObjects: NSFontAttributeName, NSBaselineOffsetAttributeName, nil ]];
	
	}


	NSMutableAttributedString *newString = [[NSMutableAttributedString alloc] initWithString:text attributes:statusAttrsDictionary];
	// NSMutableAttributedString *newString = [newString initWithString:text attributes:normalAttrsDictionary];
	
	[newString autorelease];
	
	return newString;
}

- (NSAttributedString *)makeAttributedMenuString:(NSString *)bigtext:(NSString *)smalltext
{
	
//	bigtext = [self searchAndReplace:@"&amp;" :@"&" :bigtext];
//	bigtext = [self searchAndReplace:@"&quot;" :@"\"" :bigtext];
//	smalltext = [self searchAndReplace:@"&amp;" :@"&" :smalltext];
//	smalltext = [self searchAndReplace:@"&quot;" :@"\"" :smalltext];

	bigtext = [self flattenHTML:bigtext];
//	NSArray *normalKeys = [NSArray arrayWithObjects: NSFontAttributeName, nil ];
//	NSArray *normalObjects = [NSArray arrayWithObjects: [NSFont fontWithName:@"Lucida Grande" size:14.0], nil];
///	NSDictionary *normalAttrsDictionary = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: [NSFont fontWithName:@"Lucida Grande" size:14.0], nil] forKeys:[NSArray arrayWithObjects: NSFontAttributeName, nil ]];

	NSMutableAttributedString *newString = [[NSMutableAttributedString alloc] initWithString:bigtext attributes:normalAttrsDictionary];
		
	if ([smalltext length] > 0) {
		smalltext = [self flattenHTML:smalltext];
		
		// NSArray *smallKeys = [NSArray arrayWithObjects: NSForegroundColorAttributeName, NSFontAttributeName, nil ];
		// NSArray *smallObjects = [NSArray arrayWithObjects: [NSColor grayColor], [NSFont fontWithName:@"Lucida Grande" size:12.0], nil];
///		NSDictionary *smallAttrsDictionary = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects: [NSColor grayColor], [NSFont fontWithName:@"Lucida Grande" size:12.0], nil] forKeys:[NSArray arrayWithObjects: NSForegroundColorAttributeName, NSFontAttributeName, nil ]];

		NSAttributedString *smallString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" - %@", smalltext] attributes:smallAttrsDictionary];
		[newString appendAttributedString:smallString];
		[smallString release];
//		[smallString release];
//		[smallKeys release];
//		[smallObjects release];
//		[smallAttrsDictionary release];

	}
	
	
//	[newString addAttribute:NSForegroundColorAttributeName
//									value:[NSColor blackColor]
//									range:NSMakeRange(0, [newString length])];
									
	
	[newString autorelease];
		
	return newString;
	
	// [newString release];	

}

- (void)announce
{
	if ([newItems count] > [[prefs stringForKey:@"maxNotifications"] intValue]) {
		
	[GrowlApplicationBridge
	   notifyWithTitle:NSLocalizedString(@"New Unread Items",nil)
		   description:NSLocalizedString(@"Google Reader Notifier has found a number of new items.",nil)
	  notificationName:NSLocalizedString(@"New Unread Items",nil)
			  iconData:nil
			  priority:0
			  isSticky:NO
		  clickContext:nil];
		
	} else {
		int i;
		// we don't display the possible extra feed that we grab
		for(i=0; i < [newItems count] && i < [[prefs valueForKey:@"maxItems"] intValue]; i++){
			int notifyindex = [results indexOfObjectIdenticalTo:[newItems objectAtIndex:i]];
			[GrowlApplicationBridge
       notifyWithTitle:[NSString stringWithFormat:@"%@",[self flattenHTML:[[sources objectAtIndex:notifyindex] stringValue]]]
		   description:[NSString stringWithFormat:@"%@",[self flattenHTML:[[titles objectAtIndex:notifyindex] stringValue]]]
	  notificationName:NSLocalizedString(@"New Unread Items",nil)
			  iconData:nil
			  priority:0
			  isSticky:NO
		  clickContext:[NSString stringWithString:[ids objectAtIndex:notifyindex]]];
		}
	}
}

// Growl functions

- (void)growlNotificationWasClicked:(id)clickContext
{
	
	
	// This doesn't seem to work correctly
	while (currentlyFetchingAndUpdating == YES) {
		if (runningDebug == 1) NSLog(@"Growl click: We are currently updating and fetching... waiting");
	}
	
	if (runningDebug == 1) NSLog(@"Growl click: Running...not waiting");
	currentlyFetchingAndUpdating == YES;
		
	if ([ids containsObject:clickContext]) {
		[self launchLink:[GRMenu itemWithTitle:clickContext]];
	} else {
		if (runningDebug == 1) NSLog(@"User clicked on growl, item already went away");
	}


			
}


- (NSDictionary *)registrationDictionaryForGrowl
{
	
	NSArray *notifications = [NSArray arrayWithObjects:
		NSLocalizedString(@"New Unread Items",nil),
		NSLocalizedString(@"New Subscription",nil),
 		// @"Adding New Feed",
		nil];
	
	NSDictionary *regDict = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Google Reader Notifier", GROWL_APP_NAME,
		notifications, GROWL_NOTIFICATIONS_ALL,
		notifications, GROWL_NOTIFICATIONS_DEFAULT,
		nil];
	
	return regDict;
}

- (NSString *)trimDownString:(NSString *)stringToTrim:(int)maxLength
{

	int initialLengthOfString;
	initialLengthOfString = [stringToTrim length];

	stringToTrim = [stringToTrim substringToIndex:MIN(maxLength,[stringToTrim length])];
	
	// if we made a trim down, we add a couple of dots
	if (initialLengthOfString > maxLength) {
		stringToTrim = [stringToTrim stringByAppendingString:@"..."];
	}

	return stringToTrim;
}

// - (IBAction)setLoginItem:(id)sender
// {

//    NSDictionary* errorDict;
//    NSAppleEventDescriptor* returnDescriptor = NULL;
//	NSAppleScript* scriptObject;

//	if ([[prefs valueForKey:@"automaticallyStartAtLogin"] boolValue] == YES) {

//		scriptObject = [[NSAppleScript alloc] initWithSource:
//                @"\
//				set app_path to path to me\n\
//				tell application \"System Events\"\n\
//				if \"Google Reader\" is not in (name of every login item) then\n\
//				make login item at end with properties {hidden:false, path:app_path}\n\
//				end if\n\
//				end tell"];
//
//	} else {
	
//		scriptObject = [[NSAppleScript alloc] initWithSource:
//                @"\
//				set app_path to path to me\n\
//				tell application \"System Events\"\n\
//				if \"Google Reader\" is in (name of every login item) then\n\
//				delete login item \"Google Reader\"\n\
//				end if\n\
//				end tell"];
	
//	}

//    returnDescriptor = [scriptObject executeAndReturnError: &errorDict];
//    [scriptObject release];
	
	// [prefs setObject:YES forKey:@"automaticallyStartAtLogin"];

// }

- (void)setupEventHandlers
{

    // Register to receive the 'GURL''GURL' event
    NSAppleEventManager *manager = [NSAppleEventManager sharedAppleEventManager];
  if (manager) {
    [manager setEventHandler:self andSelector:@selector(handleOpenLocationAppleEvent:withReplyEvent:) forEventClass:'GURL' andEventID:'GURL'];
  }
}

- (void)handleOpenLocationAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)reply
{

    // get the descriptor
    NSAppleEventDescriptor *directObjectDescriptor = [event paramDescriptorForKeyword:keyDirectObject];
    if ( directObjectDescriptor ) {

	// get the complete string
	NSString *urlString = [directObjectDescriptor stringValue];
	if ( urlString ) {

		NSScanner * scanner = [NSScanner scannerWithString:urlString];
		NSString * urlPrefix;
	
		[scanner scanUpToString:@":" intoString:&urlPrefix];
		[scanner scanString:@":" intoString:nil];
		if ([urlPrefix isEqualToString:@"feed"])
		{
			NSString * feedScheme = nil;

			[scanner scanString:@"//" intoString:nil];
			[scanner scanString:@"http:" intoString:&feedScheme];
			[scanner scanString:@"https:" intoString:&feedScheme];
			[scanner scanString:@"//" intoString:nil];

			NSString * linkPath;

			[scanner scanUpToString:@"" intoString:&linkPath];
			if (feedScheme == nil)
				feedScheme = @"http:";
			linkPath = [NSString stringWithFormat:@"%@//%@", feedScheme, linkPath];
			
			if (linkPath) {
			
				[self addFeed:linkPath];

			} else {
	
				[self displayAlert:@"Error" :@"The feed address seems to be malformed"];

			}


}

			
			}
			
        }

}


- (IBAction)selectTorrentCastFolder:(id)sender 
{

	NSOpenPanel *op = [[NSOpenPanel openPanel] retain];
	
	[op setCanChooseDirectories:YES];
	[op setCanChooseFiles:NO];
	[op setAllowsMultipleSelection:NO];
	[op setResolvesAliases:NO];
	[op beginSheetForDirectory:nil file:@"" types:nil modalForWindow:preferences modalDelegate:self didEndSelector:@selector(selectTorrentCastFolderEnded:returnCode:contextInfo:) contextInfo:nil];

}

- (void)selectTorrentCastFolderEnded:(NSOpenPanel*)panel returnCode:(int)returnCode contextInfo:(void*)contextInfo
{

	if (returnCode == NSOKButton) {
		NSArray*		paths = [panel filenames];
		NSEnumerator*	iter = [paths objectEnumerator];
		NSString*		path;
		
		while ((path = [iter nextObject]) != NULL) {
			torrentCastFolderPathString = path;
		}
		
		if (runningDebug == 1) NSLog(@"TorrentCast folder selected: %@", torrentCastFolderPathString);		
		[prefs setValue:[NSString stringWithString:torrentCastFolderPathString] forKey:@"torrentCastFolderPath"];
		[torrentCastFolderPath setStringValue:[prefs valueForKey:@"torrentCastFolderPath"]];

	}

	[panel release];

}


@end
