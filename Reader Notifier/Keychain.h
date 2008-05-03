//
//  Keychain.h
//  Google Reader
//
//  Created by Troels Bay on 2006-11-14.
//

#import <Cocoa/Cocoa.h>


@interface Keychain : NSObject {

}

+ (BOOL)checkForExistanceOfKeychain;
+ (BOOL)deleteKeychainItem;
+ (BOOL)modifyKeychainItem:(NSString *)newPassword;
+ (BOOL)addKeychainItem:(NSString *)password;
+ (NSString *)getPassword;
+ (NSString *)getUsernameFromSecKeychainItemRef:(SecKeychainItemRef)item;
+ (NSString *)getPasswordFromSecKeychainItemRef:(SecKeychainItemRef)item;


@end
