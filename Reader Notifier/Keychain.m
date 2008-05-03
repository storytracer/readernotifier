//
//  Keychain.m
//  Google Reader
//
//  Created by Troels Bay on 2006-11-14.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "Keychain.h"

#import <Cocoa/Cocoa.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>

@implementation Keychain





+ (BOOL)checkForExistanceOfKeychain
{
	SecKeychainSearchRef search;
	SecKeychainItemRef item;
	// SecKeychainAttributeList list;
	SecKeychainAttribute attributes[3];
    OSErr result;
    int numberOfItemsFound = 0;
	    
	attributes[0].tag = kSecGenericItemAttr;
    attributes[0].data = "application password";
    attributes[0].length = 20;
	
	attributes[1].tag = kSecLabelItemAttr;
	attributes[1].data = "Reader Notifier";
    attributes[1].length = 15;
	
	attributes[2].tag = kSecAccountItemAttr;
    attributes[2].data = "Reader Notifier";
    attributes[2].length = 15;
	
    // list.count = 3;
    // list.attr = &attributes;
	
	SecKeychainAttributeList list = {3, attributes};
	
    result = SecKeychainSearchCreateFromAttributes(NULL, kSecGenericPasswordItemClass, &list, &search);
	
    if (result != noErr) {
        NSLog (@"status %d from SecKeychainSearchCreateFromAttributes\n", result);
    }
    
	while (SecKeychainSearchCopyNext (search, &item) == noErr) {
        CFRelease (item);
        numberOfItemsFound++;
    }
	
	//printf("%d items found\n", numberOfItemsFound);
    CFRelease (search);
	return numberOfItemsFound;
}


// we're not really using this, though
+ (BOOL)deleteKeychainItem
{
	SecKeychainAttribute attributes[3];
    SecKeychainAttributeList list;
    SecKeychainItemRef item;
	SecKeychainSearchRef search;
    OSStatus status;
	OSErr result;
	int numberOfItemsFound = 0;
	   
	attributes[0].tag = kSecGenericItemAttr;
    attributes[0].data = "application password";
    attributes[0].length = 20;
	
	attributes[1].tag = kSecLabelItemAttr;
    attributes[1].data = "Reader Notifier";
    attributes[1].length = 15;
	
	attributes[2].tag = kSecAccountItemAttr;
    attributes[2].data = "Reader Notifier";
    attributes[2].length = 15;
	
    list.count = 3;
    list.attr = attributes;
	
	result = SecKeychainSearchCreateFromAttributes(NULL, kSecGenericPasswordItemClass, &list, &search);
	while (SecKeychainSearchCopyNext (search, &item) == noErr) {
        numberOfItemsFound++;
    }
	if (numberOfItemsFound) {
		status = SecKeychainItemDelete(item);
	}
	
    if (status != 0) {
        NSLog(@"Error deleting item: %d\n", (int)status);
    }
	CFRelease (item);
	CFRelease(search);
	return !status;
}

+ (BOOL)modifyKeychainItem:(NSString *)newPassword
{

	SecKeychainAttribute attributes[3];
    SecKeychainAttributeList list;
    SecKeychainItemRef item;
	SecKeychainSearchRef search;
    OSStatus status;
	OSErr result;
	
	attributes[0].tag = kSecGenericItemAttr;
    attributes[0].data = "application password";
    attributes[0].length = 20;
	
	attributes[1].tag = kSecLabelItemAttr;
    attributes[1].data = "Reader Notifier";
    attributes[1].length = 15;
	
	attributes[2].tag = kSecAccountItemAttr;
    attributes[2].data = "Reader Notifier";
    attributes[2].length = 15;
	
    list.count = 3;
    list.attr = attributes;
	
	result = SecKeychainSearchCreateFromAttributes(NULL, kSecGenericPasswordItemClass, &list, &search);
	SecKeychainSearchCopyNext (search, &item);
    status = SecKeychainItemModifyContent(item, &list, [newPassword length], [newPassword cString]);
	
    if (status != 0) {
        NSLog(@"Error modifying item: %d", (int)status);
    }
	CFRelease (item);
	CFRelease(search);
	return !status;
}



+ (BOOL)addKeychainItem:(NSString *)password
{

	SecKeychainAttribute attributes[3];
    SecKeychainAttributeList list;
    SecKeychainItemRef item;
    OSStatus status;
	
	attributes[0].tag = kSecGenericItemAttr;
    attributes[0].data = "application password";
    attributes[0].length = 20;
	
	attributes[1].tag = kSecLabelItemAttr;
    attributes[1].data = "Reader Notifier";
    attributes[1].length = 15;
	
	attributes[2].tag = kSecAccountItemAttr;
    attributes[2].data = "Reader Notifier";
    attributes[2].length = 15;
	
    list.count = 3;
    list.attr = attributes;
		
    status = SecKeychainItemCreateFromContent(kSecGenericPasswordItemClass, &list, [password length], [password cString], NULL,NULL,&item);
    if (status != 0) {
        NSLog(@"Error creating new item: %d\n", (int)status);
    }
	return !status;
}

+ (NSString *)getPassword
{
    SecKeychainSearchRef search;
    SecKeychainItemRef item;
//    SecKeychainAttributeList list;
    SecKeychainAttribute attributes[3];
    OSErr result;
	    
	attributes[0].tag = kSecGenericItemAttr;
    attributes[0].data = "application password";
    attributes[0].length = 20;
	
	attributes[1].tag = kSecLabelItemAttr;
    attributes[1].data = "Reader Notifier";
    attributes[1].length = 15;
	
	attributes[2].tag = kSecAccountItemAttr;
    attributes[2].data = "Reader Notifier";
    attributes[2].length = 15;
	
//    list.count = 3;
//    list.attr = &attributes;

	SecKeychainAttributeList list = {3, attributes};
	
    result = SecKeychainSearchCreateFromAttributes(NULL, kSecGenericPasswordItemClass, &list, &search);
	
    if (result != noErr) {
        NSLog (@"status %d from SecKeychainSearchCreateFromAttributes\n", result);
    }
	
	NSString *password = @"";
    if (SecKeychainSearchCopyNext (search, &item) == noErr) {
		password = [self getPasswordFromSecKeychainItemRef:item];
		CFRelease(item);
		CFRelease (search);
	}
	
	return password;
}


+ (NSString *)getUsernameFromSecKeychainItemRef:(SecKeychainItemRef)item
{
    UInt32 length;
	
	SecKeychainAttribute attributes[8];
	SecKeychainAttribute attr;
	
	SecKeychainAttributeList list;
	OSStatus status;
	
	attributes[0].tag = kSecAccountItemAttr;
	//    attributes[1].tag = kSecDescriptionItemAttr;
	//    attributes[2].tag = kSecLabelItemAttr;
	//    attributes[3].tag = kSecModDateItemAttr;
	
	list.count = 1;
	list.attr = attributes;
	
	attr = list.attr[0];
	
	//status = SecKeychainItemCopyContent (item, NULL, &list, &length, 
	//                                     (void **)&password);
	
	// use this version if you don't really want the password,
	// but just want to peek at the attributes
	status = SecKeychainItemCopyContent (item, NULL, &list, NULL, NULL);
	
	// make it clear that this is the beginning of a new
	// keychain item
	if (status == noErr) {
		
		// copy the password into a buffer so we can attach a
		// trailing zero byte in order to be able to print
		// it out with printf
		char buffer[1024];
		
		if (length > 1023) {
			length = 1023; // save room for trailing \0
		}

		
		strncpy (buffer, attributes[0].data, attributes[0].length);
		
		
		buffer[attributes[0].length] = '\0';
		return [NSString stringWithCString:buffer];
		
		SecKeychainItemFreeContent (&list, buffer);

		
	} else {
		
		printf("Error = %d\n", (int)status);
		return @"";
	}
}



+ (NSString *)getPasswordFromSecKeychainItemRef:(SecKeychainItemRef)item
{
    UInt32 length;
    char *password;
    SecKeychainAttribute attributes[8];
    SecKeychainAttributeList list;
    OSStatus status;
	
	NSString *returnedPass;
	
    attributes[0].tag = kSecAccountItemAttr;
	// attributes[1].tag = kSecDescriptionItemAttr;
	attributes[1].tag = kSecGenericItemAttr;
    attributes[2].tag = kSecLabelItemAttr;
    attributes[3].tag = kSecModDateItemAttr;
	
    list.count = 4;
    list.attr = attributes;
	
    status = SecKeychainItemCopyContent (item, NULL, &list, &length, 
                                         (void **)&password);
	
    // use this version if you don't really want the password,
    // but just want to peek at the attributes
    //status = SecKeychainItemCopyContent (item, NULL, &list, NULL, NULL);
    
    // make it clear that this is the beginning of a new
    // keychain item
    if (status == noErr) {
        if (password != NULL) {
			
            // copy the password into a buffer so we can attach a
            // trailing zero byte in order to be able to print
            // it out with printf
            char passwordBuffer[1024];
			
            if (length > 1023) {
                length = 1023; // save room for trailing \0
            }
            strncpy (passwordBuffer, password, length);
			
            passwordBuffer[length] = '\0';
			//printf ("passwordBuffer = %s\n", passwordBuffer);
			
			// return [NSString stringWithCString:passwordBuffer];
			returnedPass = [NSString stringWithCString:passwordBuffer];
        }
		
        SecKeychainItemFreeContent (&list, password);
		
    } else {
        printf("Error = %d\n", (int)status);
		
		// return @"";
		returnedPass = @"";
    }
	
	return returnedPass;
	
}


@end
