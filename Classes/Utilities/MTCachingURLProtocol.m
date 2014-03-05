//
//  RNCachingURLProtocol.m
//
//  Created by Robert Napier on 1/10/12.
//  Copyright (c) 2012 Rob Napier.
//
//  This code is licensed under the MIT License:
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//

#import "MTCachingURLProtocol.h"
#import "Reachability.h"
#import "CacheUtilities.h"

extern NSString *const MTAuthenticationCredentialsKey;
extern NSString *const MTAuthenticationLoginKey;
extern NSString *const MTAuthenticationPasswordKey;
extern NSString *const MTAuthenticationHostKey;

extern NSString *const MTShouldReloadWebView;

#define WORKAROUND_MUTABLE_COPY_LEAK 1

#if WORKAROUND_MUTABLE_COPY_LEAK
// required to workaround http://openradar.appspot.com/11596316
@interface NSURLRequest(MutableCopyWorkaround)

- (id) mutableCopyWorkaround;

@end
#endif

static NSString *RNCachingURLHeader = @"X-RNCache";

@interface MTCachingURLProtocol () // <NSURLConnectionDelegate, NSURLConnectionDataDelegate> iOS5-only
@property (nonatomic, readwrite, strong) NSURLConnection *connection;
@property (nonatomic, readwrite, strong) NSMutableData *data;
@property (nonatomic, readwrite, strong) NSURLResponse *response;
- (void)appendData:(NSData *)newData;
@end

@implementation MTCachingURLProtocol
@synthesize connection = connection_;
@synthesize data = data_;
@synthesize response = response_;


+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
  // only handle http requests we haven't marked with our header.
   // NSLog(@"Method: %@  request URL: %@",  request.HTTPMethod, [[request URL] absoluteString]);
  if (([[[request URL] scheme] isEqualToString:@"http"] || [[[request URL] scheme] isEqualToString:@"https"])
      && [request.HTTPMethod isEqualToString:@"GET"]
      && ([request valueForHTTPHeaderField:RNCachingURLHeader] == nil)) {
    return YES;
  }
  return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
  return request;
}

- (NSString *)cachePathForRequest:(NSURLRequest *)aRequest
{
  // This stores in the Caches directory, which can be deleted when space is low, but we only use it for offline access
  NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
  return [cachesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%x", [[[aRequest URL] absoluteString] hash]]];
}

- (void)startLoading
{
    NSMutableURLRequest *connectionRequest = 
#if WORKAROUND_MUTABLE_COPY_LEAK
      [[self request] mutableCopyWorkaround];
#else
      [[self request] mutableCopy];
#endif
    // we need to mark this request with our header so we know not to handle it in +[NSURLProtocol canInitWithRequest:].
    [connectionRequest setValue:@"" forHTTPHeaderField:RNCachingURLHeader];
    NSURLConnection *connection = [NSURLConnection connectionWithRequest:connectionRequest
                                                                delegate:self];
    [self setConnection:connection];
}

- (void)stopLoading
{
  [[self connection] cancel];
}

#pragma mark NSRURLConnection Delegate Methods
// NSURLConnection delegates (generally we pass these on to our client)
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    
    MTCachedData *cache = [NSKeyedUnarchiver unarchiveObjectWithFile:[self cachePathForRequest:request]];
    if (cache) {
        NSData *data = [cache data];
        NSURLResponse *cachedResponse = [cache response];
        NSURLRequest *redirectRequest = [cache redirectRequest];
        
        //NSLog(@"Using Cache: %@ ", request.URL);
        
        if (redirectRequest) {
            [[self client] URLProtocol:self wasRedirectedToRequest:redirectRequest redirectResponse:response];
            return redirectRequest;
            
        } else {
            [[self client] URLProtocol:self didReceiveResponse:cachedResponse cacheStoragePolicy:NSURLCacheStorageNotAllowed]; // we handle caching ourselves.
            [[self client] URLProtocol:self didLoadData:data];
            [[self client] URLProtocolDidFinishLoading:self];
        }
        return nil;
    }
    else{
        CacheUtilities* cachUtility = [CacheUtilities new];
        [cachUtility getHeaderForRequest:[request mutableCopyWorkaround]];
        if (response){
            [[self client] URLProtocol:self wasRedirectedToRequest:request redirectResponse:response];
        }
        return request;
    }
}

// Called when NSURLConnection detects authentication is required
- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
 
    if ([challenge previousFailureCount] == 0) {

        // Get the saved credential for the host site that is requestion authentication
        NSDictionary* savedCredential = nil;
        NSMutableArray* allSavedCredentials = [[[NSUserDefaults standardUserDefaults] arrayForKey:MTAuthenticationCredentialsKey] mutableCopy];
        for (NSDictionary* savedCred in allSavedCredentials) {
            if ([savedCred[MTAuthenticationHostKey] isEqualToString:connection.currentRequest.URL.host]) {
                savedCredential = savedCred;
            }
        }
        // If there is a saved crential then use it to authenticate
        if (savedCredential) {
            NSURLCredential *newCredential = [NSURLCredential credentialWithUser:savedCredential[MTAuthenticationLoginKey]
                                                                        password:savedCredential[MTAuthenticationPasswordKey]
                                                                     persistence:NSURLCredentialPersistenceNone];
            [[challenge sender] useCredential:newCredential forAuthenticationChallenge:challenge];
        }
        else{
            [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
        }
    } else {
        // Login or password is incorrect
        [[challenge sender] cancelAuthenticationChallenge:challenge];
        
        // Remove incorrect stored credential
        NSMutableArray* allCreds = [[[NSUserDefaults standardUserDefaults] arrayForKey:MTAuthenticationCredentialsKey] mutableCopy];
        for (NSDictionary* savedCred in allCreds) {
            if ([savedCred[MTAuthenticationHostKey] isEqualToString:connection.currentRequest.URL.host]) {
                [allCreds removeObject:savedCred];
            }
        }
        [[NSUserDefaults standardUserDefaults] setObject:allCreds forKey:MTAuthenticationCredentialsKey];
        
        // Reload the url so that it retriggers the login and password prompt
        [[NSNotificationCenter defaultCenter] postNotificationName:MTShouldReloadWebView object:self userInfo:@{@"requestURL":connection.currentRequest.URL}];

    }
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection;
{
    return YES;
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [[self client] URLProtocol:self didLoadData:data];
    [self appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
  [[self client] URLProtocol:self didFailWithError:error];
  [self setConnection:nil];
  [self setData:nil];
  [self setResponse:nil];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
  [self setResponse:response];
  [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];  // We cache ourselves.
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [[self client] URLProtocolDidFinishLoading:self];

    [self setConnection:nil];
    [self setData:nil];
    [self setResponse:nil];
}
#pragma mark -
- (BOOL) useCache 
{
    BOOL reachable = (BOOL) [[Reachability reachabilityWithHostname:[[[self request] URL] host]] currentReachabilityStatus] != NotReachable;
    return !reachable;
}

- (void)appendData:(NSData *)newData
{
  if ([self data] == nil) {
    [self setData:[newData mutableCopy]];
  }
  else {
    [[self data] appendData:newData];
  }
}

@end


#if WORKAROUND_MUTABLE_COPY_LEAK
@implementation NSURLRequest(MutableCopyWorkaround)

- (id) mutableCopyWorkaround {
    NSMutableURLRequest *mutableURLRequest = [[NSMutableURLRequest alloc] initWithURL:[self URL]
                                                                          cachePolicy:[self cachePolicy]
                                                                      timeoutInterval:[self timeoutInterval]];
    [mutableURLRequest setAllHTTPHeaderFields:[self allHTTPHeaderFields]];
    return mutableURLRequest;
}

@end
#endif
