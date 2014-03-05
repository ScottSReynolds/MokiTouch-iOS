//
//  AppDelegate.m
//  MokiTouch
//
//  Copyright (C) 2014 Moki Mobility, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License")
//
//  You may only use this file in compliance with the license
//
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "AppDelegate.h"
#import "MTCachingURLProtocol.h"

#define API_KEY @"bf517fc9-5993-49ea-9d2c-2f719447e5e6"

@implementation AppDelegate



- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Our own modified caching. Modified version of Robert Napier's RNCachingURLProtocol class
    [NSURLProtocol registerClass:[MTCachingURLProtocol class]];
    
    // Initialize MokiManage API
    NSError *error;
    [[MokiManage sharedManager] initializeWithApiKey:API_KEY
                                    launchingOptions:launchOptions
                                           enableASM:YES
                                           enableAEM:YES
                            enableComplianceChecking:NO
                                 asmSettingsFileName:nil
                                               error:&error];
    
    if (error) {
        NSLog(@"%@", error.description);
    }
    
    
    // Keeps the app awake
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    // ASM settings list defaults for start page and screen saver
    if ([[[MokiManage sharedManager] arrayForKey:@"contentItems"] count] == 0) {
        NSArray *defaultContent = @[@{@"title":@"Start Page", @"content":@"http://mokicloud.com/mokitouch"}];
        [[MokiManage sharedManager] setObject:defaultContent forKey:@"contentItems"];
    }
    if ([[[MokiManage sharedManager] arrayForKey:@"contentItems"] count] == 0) {
        NSArray *defaultScreensaverContent = @[@{@"content":@"http://vimeo.com/50547474/download?t=1381162078&v=120388389&s=1a5f307aa8dfd9aa5cf07f8ccffec4e9", @"duration":@10}];
        [[MokiManage sharedManager] setObject:defaultScreensaverContent forKey:@"screensaverPlaylistItems"];
    }
    
    return YES;
}


- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken {
    // Send device token to MokiManage after the device registers for push notifications
    [[MokiManage sharedManager] setApnsToken:deviceToken];
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error {
    if(error) {
        // Add error processing here.
        NSLog(@"error registering for push notifications %@",error);
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    // When the app recieves a push notification send it to MokiManage
    [[MokiManage sharedManager] didReceiveRemoteNotification:userInfo];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
