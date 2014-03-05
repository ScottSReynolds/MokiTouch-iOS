//
//  ContentView.h
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


#import <UIKit/UIKit.h>
#import "AFHTTPRequestOperation.h"
#import <MediaPlayer/MediaPlayer.h>
@class ContentView;

typedef enum {
    ContentTypeWebsite = 0,
    ContentTypeVideo
} ContentType;

@protocol ContentViewDelegate <NSObject>
@optional
-(void) showNextItem;
-(void) contentViewDidFinishLoad:(ContentView*)contentView;
@end

@interface ContentView : UIView <UIWebViewDelegate>
{
    MPMoviePlayerController* _moviePlayer;
    UIWebView* _webView;
    
    BOOL _boolContentLoaded;
}
@property (unsafe_unretained) id delegate;

@property (strong, nonatomic) NSURL* contentURL;
@property (assign) ContentType contentType;
@property (strong, nonatomic) MPMoviePlayerController* moviePlayer;
@property (strong, nonatomic) UIWebView* webView;
@property (assign) BOOL pauseAllowed;


-(void) goForward;
-(void) goBack;
-(void) reload;

@end
