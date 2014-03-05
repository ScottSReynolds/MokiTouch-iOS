//
//  ScreenSaverViewController.m
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


#import "ScreenSaverViewController.h"
#import "MiscUtilities.h"

extern NSString *const MTScreenSaverWillCloseNotification;

@interface ScreenSaverViewController ()

@end

@implementation ScreenSaverViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    
    // Observe when MokiManage settings changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsUpdated:) name:MMApplicationDidChangeSettingsNotification object:nil];
    
    
    _intCurrentPlaylistItem = 0;
    _arrPlaylist = [[MokiManage sharedManager] arrayForKey:@"screensaverPlaylistItems"];
    
    // Create the first contentView and display
    _contentViewCurrent = [self createNewContentView];
    [self.view addSubview:_contentViewCurrent];
    
    // Add clear button over the top of everything so that when the user touches screensaver it will automatically close
    _btnEndScreenSaver = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnEndScreenSaver.frame = _contentViewCurrent.frame;
    [_btnEndScreenSaver setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [_btnEndScreenSaver addTarget:self action:@selector(endScreenSaver) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnEndScreenSaver];
    
    // Set playlist timer if there are more than one items in the screensaver playlist
    if (_arrPlaylist.count > 1){
        [self resetPlaylistTimer];
    }
}

-(void)settingsUpdated:(NSNotification*)notification
{
    NSSet *results = [[notification userInfo] objectForKey:MMNotificationChangedValueKeysKey];
    if ([results containsObject:@"screensaverPlaylistItems"]) {
        
        _arrPlaylist = [[MokiManage sharedManager] arrayForKey:@"screensaverPlaylistItems"];
        
        if (_arrPlaylist.count == 0) {
            [self endScreenSaver];
        }
        else{
            
            if (_contentViewCurrent.contentType == ContentTypeVideo) {
                _contentViewCurrent.moviePlayer.repeatMode = MPMovieRepeatModeNone;
            }
            else if (!_timerForCurrentItem) {
                _intCurrentPlaylistItem = (_intCurrentPlaylistItem >= _arrPlaylist.count) ? 0 : _intCurrentPlaylistItem;
                [self resetPlaylistTimer];
            }
            
        }
    }
}
-(ContentView*) createNewContentView
{
    // Get web address for content from settings
    NSString* webAddress = [MiscUtilities addHttpToURL:[[_arrPlaylist objectAtIndex:_intCurrentPlaylistItem] objectForKey:@"content"]];
    
    // Create a ContentView from web address
    ContentView* newContentView = [[ContentView alloc] initWithFrame:self.view.bounds];
    newContentView.delegate = self;
    newContentView.contentURL = [NSURL URLWithString:webAddress];
    
    return newContentView;
}

-(void) showNextItem
{
    // Figure out what index the next content item will be (loops)
    _intCurrentPlaylistItem = (_intCurrentPlaylistItem+1 >= _arrPlaylist.count) ? 0 : _intCurrentPlaylistItem+1;
    
    // Create a new ContentView and add it off screen so we can animate it over when it is finished loading
    _contentViewNext = [self createNewContentView];
    _contentViewNext.frame = CGRectMake(_contentViewNext.frame.size.width, 0, _contentViewNext.frame.size.width, _contentViewNext.frame.size.height);
    [self.view addSubview:_contentViewNext];
    
    // Once the new content has loaded we need to animate it on and the old one off
    [UIView animateWithDuration:.3 animations:^{
        _contentViewCurrent.frame = CGRectMake(-_contentViewCurrent.frame.size.width, 0, _contentViewCurrent.frame.size.width, _contentViewCurrent.frame.size.height);
        _contentViewNext.frame = CGRectMake(0, 0, _contentViewNext.frame.size.width, _contentViewNext.frame.size.height);
    } completion:^(BOOL finished){
        [_contentViewCurrent removeFromSuperview];
        _contentViewCurrent = nil;
        _contentViewCurrent = _contentViewNext;
        
        if (_arrPlaylist.count > 1) {
            [self resetPlaylistTimer];
        }
        else{
            [self removePlaylistTimer];
        }
    }];
    
    [self.view bringSubviewToFront:_btnEndScreenSaver];
}
-(void) endScreenSaver
{
    
    // Remove and clean up screen saver
    [_timerForCurrentItem invalidate];

    
    [[NSNotificationCenter defaultCenter] postNotificationName:MTScreenSaverWillCloseNotification object:nil];
    [super dismissViewControllerAnimated:true completion:nil];
}
-(void)removePlaylistTimer
{
    [_timerForCurrentItem invalidate];
    _timerForCurrentItem = nil;
}
- (void) resetPlaylistTimer
{
    [self removePlaylistTimer];
    [self setPlaylistTimer];
}
-(void) setPlaylistTimer
{
    // Set a timer according to the duration specified in settings. Each content item has a duration associated with it.
    int timeInMinutes = [[[_arrPlaylist objectAtIndex:_intCurrentPlaylistItem] objectForKey:@"duration"] intValue];
    if (timeInMinutes > 0) {
        _timerForCurrentItem = [NSTimer scheduledTimerWithTimeInterval:timeInMinutes target:self selector:@selector(currentPlaylistTimerFired) userInfo:nil repeats:NO];
    }
    else{
        [self removePlaylistTimer];
    }
}
-(void) currentPlaylistTimerFired
{
    // If there is more than one screen for the screen saver then load the next one
    if (_contentViewCurrent.contentType != ContentTypeVideo) {
        [self showNextItem];
    }
}



#pragma mark - Content View Delegate Methods
-(void) contentViewDidFinishLoad:(ContentView*)contentView
{
    if (contentView.contentType == ContentTypeVideo) {
        contentView.moviePlayer.controlStyle = MPMovieControlStyleNone;
        
        NSArray* screenSaverPlaylist = [[MokiManage sharedManager] arrayForKey:@"screensaverPlaylistItems"];
        if (screenSaverPlaylist && screenSaverPlaylist.count == 1) {
            [contentView.moviePlayer setRepeatMode:MPMovieRepeatModeOne];
        }
    }
}





@end
