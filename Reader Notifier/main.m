//
//  main.m
//  Google Reader
//
//  Created by Troels Bay on 2006-11-02.
//  Copyright __MyCompanyName__ 2006. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{

	id pool = [NSAutoreleasePool new];

	NSString *logPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/ReaderNotifierDebug.log"];
	freopen([logPath fileSystemRepresentation], "a", stderr);

	[pool release];
	
    return NSApplicationMain(argc,  (const char **) argv);
}
