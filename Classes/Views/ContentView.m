//
//  ContentView.m
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


#import "ContentView.h"
#import "MTCachedData.h"
#import "CacheUtilities.h"
#import "MBProgressHUD.h"
#import "MiscUtilities.h"
#import "UIAlertView+Blocks.h"

extern NSString *const MTShouldStopLoadingWebView;
extern NSString *const MTShouldReloadWebView;
extern NSString *const MTBlankContentURLForWebView;

@implementation ContentView
{
    NSMutableArray* _arrUrlList;
    int _intCurrentUrlDisplayed;
}
@synthesize contentURL = _contentURL;
@synthesize delegate;

// Figures out what the content is. If content is a video we handle it special, everything else goes into a UIWebView
-(void) loadContent
{

    
    [self setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    self.autoresizesSubviews = true;
    
    // If contentURL is empty then don't try to load
    if (!_contentURL || [[_contentURL absoluteString] isEqualToString:@"http://"]) {
        [self performSelector:@selector(finishedLoading) withObject:nil afterDelay:.1];
        return;
    }

    
    // Make sure we start fresh
    [self removeCurrentContent];
    
    // Start the loading indicator if settings say we should
    if ([[MokiManage sharedManager] boolForKey:@"showProgress"]) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self animated:YES];
        hud.labelText = @"Loading";
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_contentURL];
    
    // Retrieve the cache for this content if there is one
    CacheUtilities* cachUtility = [CacheUtilities new];
    MTCachedData *cache = [cachUtility cachedDataForRequest:request];
    
    // Check cache, pull the content if its there
    if (cache) {
        NSString* contentType = [[(NSHTTPURLResponse *)cache.response allHeaderFields] objectForKey:@"Content-Type"];
        if ([contentType rangeOfString:@"video"].location != NSNotFound) {
            _contentType = ContentTypeVideo;
            [self setupMoviePlayerWithData:cache.data];
        }
        else{
            [self setupWebView];
        }
    }
    // If not in cache, figure out what is is, save it in cache and load
    else{
        // If the url ends with common video extention, we know its a video
        NSString* extention = [[[_contentURL absoluteString] componentsSeparatedByString:@"."] lastObject];
        if ([extention isEqualToString:@"mp4"] || [extention isEqualToString:@"mov"] || [extention isEqualToString:@"m4v"]) {
            _contentType = ContentTypeVideo;
            [cachUtility saveDataToCachForRequest:request];
             
            [self setupMoviePlayerWithData:nil];
        }
        else{
            // If we still don't know what it is create a head request to check what type it is
            [cachUtility cacheDataForRequest:request requestContentType:^(NSDictionary* headerFields) {
                
                if ([[headerFields  objectForKey:@"Content-Type"] rangeOfString:@"video"].location != NSNotFound) {
                    _contentType = ContentTypeVideo;
                    [self setupMoviePlayerWithData:nil];
                }
                else{
                    [self setupWebView];
                }
            }];
        }
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadWebViewWithNewURL:) name:MTShouldReloadWebView object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopLoadingAndRemoveContent) name:MTShouldStopLoadingWebView object:nil];
}

// Content finished loading
-(void) finishedLoading
{
    // Remove loading indicator
    NSArray* arrAllHuds =[MBProgressHUD allHUDsForView:self];
    for (MBProgressHUD *hud  in arrAllHuds){
        [MBProgressHUD hideHUDForView:self animated:YES];
    }
    
    // Let the delegate know we finished loading
    [self.delegate contentViewDidFinishLoad:self];
}
// Get path where we store the videos
- (NSString *)cachePathForVideoWebURL:(NSURL *)videoPath
{
    // This stores in the Caches directory, which can be deleted when space is low
    NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    return [cachesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%xVideo.mp4", [[videoPath absoluteString] hash]]];
}


#pragma mark - Movie Player
-(void) setupMoviePlayerWithData:(NSData*)data
{
    if (data) {
        NSString* videoPath =[self cachePathForVideoWebURL:_contentURL];
        NSURL* videoURL = [NSURL fileURLWithPath:videoPath];
        
        if(![[NSFileManager defaultManager] fileExistsAtPath:videoPath])
        {
            NSError * error = nil;
            BOOL success = [data writeToURL:videoURL options:NSDataWritingAtomic error:&error];
            if (!success){
                NSLog(@"%@", error.description);
            }
        }
       
        _moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:videoURL];
    }
    else{
        _moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:_contentURL];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayBackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayerLoadStateDidChange:) name:MPMoviePlayerLoadStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlaybackStateDidChange:) name:MPMoviePlayerPlaybackStateDidChangeNotification object:nil];
    
    [_moviePlayer.view setFrame:self.bounds];
    [_moviePlayer.view setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [self addSubview:_moviePlayer.view];
    [_moviePlayer prepareToPlay];
    _moviePlayer.shouldAutoplay = true;
    [self finishedLoading];
}

- (void) moviePlayBackDidFinish:(NSNotification*)notification  {
    if ([self.delegate respondsToSelector:@selector(showNextItem)]) {
        // Remove observer
        [[NSNotificationCenter  defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:nil];
        [self.delegate showNextItem];
    }
    else
    {
        [_moviePlayer play];
    }
}

- (void) moviePlayerLoadStateDidChange:(NSNotification*)notification  {
    MPMoviePlayerController *moviePlayer = notification.object;
    MPMovieLoadState loadState = moviePlayer.loadState;
    if(loadState == MPMovieLoadStatePlayable || loadState == MPMovieLoadStatePlaythroughOK) {
        // Remove observer
        [[NSNotificationCenter  defaultCenter] removeObserver:self name:MPMoviePlayerLoadStateDidChangeNotification object:nil];
        
        // Remove loading indicator
        NSArray* arrAllHuds =[MBProgressHUD allHUDsForView:self];
        for (MBProgressHUD *hud  in arrAllHuds){
            [MBProgressHUD hideHUDForView:self animated:YES];
        }
    }
}
- (void) moviePlaybackStateDidChange:(NSNotification*)notification  {
    MPMoviePlayerController *moviePlayer = notification.object;
    MPMovieLoadState playbackState = moviePlayer.playbackState;
    
    if(playbackState == MPMoviePlaybackStatePaused && !self.pauseAllowed) {
        [_moviePlayer play];
    }
}



#pragma mark - UIWebView
-(void) setupWebView
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_contentURL
                                      cachePolicy:NSURLRequestReloadIgnoringCacheData
                                  timeoutInterval:60];
    
    // Check for authentication
    (void)[NSURLConnection connectionWithRequest:request delegate:self];
    
    _webView = [[UIWebView alloc] initWithFrame:self.bounds];
    [_webView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [_webView loadRequest:request];
    _webView.dataDetectorTypes = UIDataDetectorTypeNone;
    _webView.scalesPageToFit = true;
    _webView.delegate = self;
    [self addSubview:_webView];
    
}
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self finishedLoading];
}
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (navigationType == UIWebViewNavigationTypeOther) {
        return true;
    }
    else{
        // Check if website is part of the whitelist from settings
        return [MiscUtilities siteAllowedForURL:request.URL];
    }
}
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    
    if([error code] == NSURLErrorCancelled)
    {
        return;
    }
}

#pragma mark - Navigation
// Load next content in our list
-(void) goForward
{
    BOOL webViewCanGoForward = _webView.canGoForward;
    
    if (webViewCanGoForward) {
        [_webView goForward];
    }
    else
    {
        // If we aren't already on the last url then increment and load the new content
        if (_intCurrentUrlDisplayed < _arrUrlList.count - 1) {
            _contentURL = [NSURL URLWithString:_arrUrlList[++_intCurrentUrlDisplayed]];
            [self loadContent];
        }
    }
}

// Load previous content in our list
-(void) goBack
{
    BOOL webViewCanGoBack = _webView.canGoBack;
    
    if (webViewCanGoBack) {
        [_webView goBack];
    }
    else
    {
        // if we aren't already on the first url then decrement and load the new content
        if (_intCurrentUrlDisplayed > 0) {
            _contentURL = [NSURL URLWithString:_arrUrlList[--_intCurrentUrlDisplayed]];
            [self loadContent];
        }
    }
    
}

// Reload current content
-(void) reload
{
    if (self.contentType == ContentTypeWebsite) {
        if ([_webView.request.URL.absoluteString isEqualToString:MTBlankContentURLForWebView]) {
            [self loadContent];
        }
        else{
            [_webView reload];
        }
    }
    else {
        [self loadContent];
    }
}

// Load empty page into the webview to clear out the content
-(void) stopLoadingAndRemoveContent
{
    if (self.contentType == ContentTypeWebsite) {
        [_webView stopLoading];
        [_webView loadHTMLString: @"" baseURL: nil];
    }
}

// Load a new url into the webview that is stored in the userInfo of a notificiation
- (void)loadWebViewWithNewURL:(NSNotification *)notification {
    [self setContentURL:[notification.userInfo objectForKey:@"requestURL"]];
}

// Add a new url to our list and load it
-(void) setContentURL:(NSURL *)contentURL
{
    if (contentURL) {
        // Create a new url list if one doesn't exist
        if (!_arrUrlList) {
            _arrUrlList = [NSMutableArray new];
        }
        
        // Remove URLs that are after the currently displayed URL
        int listCount = _arrUrlList.count - 1;
        if (_intCurrentUrlDisplayed < listCount) {
            [_arrUrlList removeObjectsInRange:NSMakeRange(_intCurrentUrlDisplayed+1, _arrUrlList.count - _intCurrentUrlDisplayed-1)];
        }
        
        // Add contentURL to our url list
        NSString* lastUrl = [_arrUrlList lastObject];
        if (!lastUrl || ![lastUrl isEqualToString:contentURL.absoluteString]) {
            [_arrUrlList addObject:contentURL.absoluteString];
        }
        
        // Update what URL is being displayed
        _intCurrentUrlDisplayed = _arrUrlList.count - 1;
        
        _contentURL = contentURL;
    }
    
    
    // Load the new content
    [self loadContent];
}

// Remove current content so we can load in new
-(void) removeCurrentContent
{
    // Remove any observer we might have had
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Clear out whatever view we had
    if (_webView) {
        [_webView loadHTMLString: @"" baseURL: nil];
        [_webView removeFromSuperview];
        _webView = nil;
    }
    if (_moviePlayer) {
        [_moviePlayer stop];
        [_moviePlayer.view removeFromSuperview];
        _moviePlayer = nil;
    }
    
}
#pragma mark - Cleanup
- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
