//
//  CacheUtilities.m
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


#import "CacheUtilities.h"
#import "UIAlertView+Blocks.h"
#import "MiscUtilities.h"
#import "AppDelegate.h"

NSString *const MTAuthenticationCredentialsKey = @"MTAuthenticationCredentials";
NSString *const MTAuthenticationLoginKey = @"MTAuthenticationLoginKey";
NSString *const MTAuthenticationPasswordKey = @"MTAuthenticationPasswordKey";
NSString *const MTAuthenticationHostKey = @"MTAuthenticationHostKey";

NSString *const MTShouldStopLoadingWebView = @"MTShouldStopLoadingWebView";
NSString *const MTShouldReloadWebView = @"MTShouldReloadWebView";

@implementation CacheUtilities


// Get the header and if the request is for an image or video then save it to cache
-(void) getHeaderForRequest:(NSMutableURLRequest*)request
{
    NSMutableURLRequest *headRequest = [request copy];
    [headRequest setHTTPMethod:@"HEAD"];
    
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:headRequest];
    
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        
       
        NSString* contentType = [[(NSHTTPURLResponse *)operation.response allHeaderFields] objectForKey:@"Content-Type"];
        if ([contentType rangeOfString:@"image"].location != NSNotFound || [contentType rangeOfString:@"video"].location != NSNotFound) {
            [self saveDataToCachForRequest:request];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        NSDictionary* headerFields = [(NSHTTPURLResponse *)operation.response allHeaderFields];
        if ([headerFields  objectForKey:@"Www-Authenticate"])
        {
            // We need to authenticate before the site will let us in
            [self retrieveAuthenticationForRequest:request];
        }
        else{
            NSLog(@"error: %@ ", error.description);
        }
    }];
    [operation start];
}

// Shows a login and password alert view if no authentication credentials are saved for the site
- (void) retrieveAuthenticationForRequest:(NSURLRequest*)request
{
    // Check if login and password are saved
    BOOL credSaved = false;
    NSMutableArray* allCreds = [[[NSUserDefaults standardUserDefaults] arrayForKey:MTAuthenticationCredentialsKey] mutableCopy];
    for (NSDictionary* savedCred in allCreds) {
        if ([[savedCred objectForKey:MTAuthenticationHostKey] isEqualToString:request.URL.host]) {
            credSaved = true;
        }
    }
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    // If no credentials are saved and there isn't already an alertview being shown, show the alert to get the login and password
    if (!credSaved && !appDelegate.alertBasicAuth.isVisible) {
        
        // The UIWebView does its own caching of credentials so it will log in even when we have cleared the cache
        // This loads in a blank screen for the webview to prevent it auto logging in when it isn't supposed to
        [[NSNotificationCenter defaultCenter] postNotificationName:MTShouldStopLoadingWebView object:self];
        
        
        
        appDelegate.alertBasicAuth = [[UIAlertView alloc] initWithTitle:@"Login" message:@"Please enter your login and password" delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:@"Enter", nil];
        appDelegate.alertBasicAuth.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
        [appDelegate.alertBasicAuth showWithCompletion:^(UIAlertView *alertView, NSInteger buttonIndex) {
            if (buttonIndex == 1) {
                
                // Save the login and password the user just entered into NSUserDefaults. Also add the host of the request so we know what login and password to use
                NSDictionary* credential = @{MTAuthenticationLoginKey: [alertView textFieldAtIndex:0].text,MTAuthenticationPasswordKey: [alertView textFieldAtIndex:1].text,MTAuthenticationHostKey: request.URL.host};
                NSMutableArray* allCreds = [[[NSUserDefaults standardUserDefaults] arrayForKey:MTAuthenticationCredentialsKey] mutableCopy];
                if (!allCreds) {
                    allCreds = [NSMutableArray new];
                }
                [allCreds addObject:credential];
                [[NSUserDefaults standardUserDefaults] setObject:allCreds forKey:MTAuthenticationCredentialsKey];
                
                // Now that we have the login and password, reload the webview so we can pass in the credentials
                [[NSNotificationCenter defaultCenter] postNotificationName:MTShouldReloadWebView object:self userInfo:@{@"requestURL":request.URL}];
            }
        }];
        
        
    }
}

-(void) saveDataToCachForRequest:(NSURLRequest*)request
{
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSString *cachePath = [self cachePathForRequest:operation.request];
        MTCachedData *cache = [MTCachedData new];
        [cache setResponse:operation.response];
        [cache setData:responseObject];
        [NSKeyedArchiver archiveRootObject:cache toFile:cachePath];
    }failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    }];
    [operation start];
}

- (NSString *)cachePathForRequest:(NSURLRequest *)aRequest
{
    // This stores in the Caches directory, which can be deleted when space is low, but we only use it for offline access
    NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    return [cachesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%x", [[[aRequest URL] absoluteString] hash]]];
}
-(MTCachedData*)cachedDataForRequest:(NSURLRequest *)aRequest
{
    return [NSKeyedUnarchiver unarchiveObjectWithFile:[self cachePathForRequest:aRequest]];
}

- (void) cacheDataForRequest:(NSURLRequest*)aRequest requestContentType:(void(^)(NSDictionary* headerFields))completion
{
    
    NSMutableURLRequest *headRequest = [aRequest mutableCopy];
    
    [headRequest setHTTPMethod:@"HEAD"];
    
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:headRequest];
    
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSString* contentType = [[(NSHTTPURLResponse *)operation.response allHeaderFields] objectForKey:@"Content-Type"];
        if (completion) {
            completion([(NSHTTPURLResponse *)operation.response allHeaderFields]);
        }
        
        if ([contentType rangeOfString:@"video"].location != NSNotFound) {
            [self saveDataToCachForRequest:aRequest];
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if ([[[error userInfo] objectForKey:AFNetworkingOperationFailingURLResponseErrorKey] statusCode] == 401) {
            completion([(NSHTTPURLResponse *)operation.response allHeaderFields]);
        }
        else{
            NSLog(@"Request error: %@ ", error.description);
        }
    }];
    [operation start];
}

@end
