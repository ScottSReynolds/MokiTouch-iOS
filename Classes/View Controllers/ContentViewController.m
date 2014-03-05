//
//  ContentViewController.m
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

#import <MediaPlayer/MediaPlayer.h>
#import "ContentViewController.h"
#import "ScreenSaverViewController.h"
#import "UIAlertView+Blocks.h"
#import "MBProgressHUD.h"
#import "MiscUtilities.h"
#import "AppDelegate.h"

#define kMMMoviePlayerStartPlaying 0.8
#define kMMDeviceVolumeMax 15.0
#define kMMDistanceToPointForSettings 200
#define kMMCarouselAnimationTime 0.0
#define kMMDynamicFontSizeMultiplier 0.8
#define kMMMinutesToSecondsMultiplier 60

extern NSString *const MTAuthenticationCredentialsKey;

NSString *const MTBlankContentURLForWebView = @"about:blank";
NSString *const MTScreenSaverWillCloseNotification = @"ScreenSaverWillClose";
NSString *const MTUserInteractedNotification = @"UserInteracted";

@interface ContentViewController ()
{
    UIAlertView* _alertIdleWarning;
}
@end

@implementation ContentViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:MTAuthenticationCredentialsKey];
    // Notification when the screensaver closes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenSaverWillClose) name:MTScreenSaverWillCloseNotification object:nil];
    // Notification whenever user interacts with the screen
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetIdleTimer) name:MTUserInteractedNotification object:nil];
    // Notification when MokiManage settings gets updated
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsUpdated:) name:MMApplicationDidChangeSettingsNotification object:nil];
    // Notification when the preferred font size for the device is changed. Only available on iOS 7.0 and higher
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];  //dynamic font only supported in ios 7 and above
    }
    
    
    // _caraselView allows the user to keep swiping through content in a loop https://github.com/nicklockwood/SwipeView
    _carouselView.scrollEnabled = true;
    _carouselView.pagingEnabled = true;
    _carouselView.wrapEnabled = true;
    _carouselView.defersItemViewLoading = false;  //preloads side views if true
    _carouselView.autoresizesSubviews = true;
    [_carouselView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    _footerView.delegate = self;
    
    
    // This is for indenting the text as uitextfield doesn't have a great way to set indentations
    UIView *spacerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    [_textFieldURL setLeftViewMode:UITextFieldViewModeAlways];
    [_textFieldURL setLeftView:spacerView];
    
    // Pan gesture for opening settings
    _arrSettingsPanCheck = [[NSMutableArray alloc] initWithObjects:[NSNumber numberWithBool:false], [NSNumber numberWithBool:false], nil];
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(openSettings:)];
    panRecognizer.delegate = self;
    [panRecognizer setMinimumNumberOfTouches:1];
    [panRecognizer setMaximumNumberOfTouches:1];
    [self.view addGestureRecognizer:panRecognizer];
    
    // Everytime the screen is touched we need to reset the idle timer
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(resetIdleTimer)];
    tapRecognizer.delegate = self;
    [self.view addGestureRecognizer:tapRecognizer];
    
    // General initial setup
    [self determineUIVisibilityFromSettings];
    [self setTextFieldURLFontSize];
    
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // Update footer
    _footerView.intNumberOfItems = _intNumberOfItems;
    [_footerView resetFooterBtns];
    [_footerView selectButtonAtIndex:_carouselView.currentItemIndex];
    
    // Make sure the carouselView is in the correct spot
    [_carouselView scrollToItemAtIndex:_carouselView.currentItemIndex duration:kMMCarouselAnimationTime];
    _intCurrentItem = _carouselView.currentItemIndex;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MTUserInteractedNotification object:nil];
}
-(void) screenSaverWillClose
{
    [self endSelected:nil];
}
// Sets url bar text size and button text size if user has their preferred text size set on their device
- (void)preferredContentSizeChanged:(NSNotification *)note
{
    [self setTextFieldURLFontSize];
    [_footerView resetFooterBtns];
}
// Figure out if preferred font size is set on the device settings and apply if it is
-(void) setTextFieldURLFontSize
{
    float fontSize = _textFieldURL.frame.size.height/2.5;
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        //use dynamic font for iOS 7
        UIFontDescriptor *userFont = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleBody];
        fontSize = [userFont pointSize]*kMMDynamicFontSizeMultiplier;
    }
    _textFieldURL.font = [UIFont fontWithName:@"ProximaNova-Regular" size:fontSize];
}

// Makes sure everything gets layed out correctly after rotating
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [_footerView layoutFooterBtns];
    [_carouselView scrollToItemAtIndex:_intCurrentItem duration:kMMCarouselAnimationTime];
}

// There are two possible actions after idle time has been met.  Start the screen saver or return to the home screen
- (void) idleTimerFired:(NSTimer*)idleTimer
{
    
    // Don't reset if user is watching a video
    ContentView* contentView = (ContentView*)[_carouselView itemViewAtIndex:_intCurrentItem];
    if (contentView.contentType == ContentTypeVideo) {
        [self resetIdleTimer];
        return;
    }
    
    
    // Show alert that the session will be ending
    _alertIdleWarning = [[UIAlertView alloc] initWithTitle:@"Session Ending" message:@"Are you still here?" delegate:nil cancelButtonTitle:@"Yes" otherButtonTitles:nil];
    [_alertIdleWarning showWithCompletion:^(UIAlertView *alertView, NSInteger buttonIndex) {
        // If they select the Yes button then that means someone is there so don't reset their session
        [self resetIdleTimer];
        
    }];
    
    // If the user hasn't dismissed the Session Ending alert then reset the session and perform the desired session ending action
    double delayInSeconds = 10.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (_alertIdleWarning.isVisible) {
            [_alertIdleWarning dismissWithClickedButtonIndex:0 animated:true];
            [self resetSession];
        }
    });
    
}

- (void) resetIdleTimer
{
    [_timerIdle invalidate];
    _timerIdle = nil;
    [self setIdleTimer];
}

-(void) setIdleTimer
{
    // Get how long app is to idle from settings
    int timeInMinutes = [[MokiManage sharedManager] integerForKey:@"idleTime"];
    if (timeInMinutes > 0) {
        // Idle time is in minutes so convert to seconds and start timer
        _timerIdle = [NSTimer scheduledTimerWithTimeInterval:timeInMinutes*kMMMinutesToSecondsMultiplier target:self selector:@selector(idleTimerFired:) userInfo:nil repeats:NO];
    }
    else{
        // If Idle time is 0 then just remove it
        [_timerIdle invalidate];
        _timerIdle = nil;
    }
}
-(void) resetSession
{
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (appDelegate.alertBasicAuth) {
        [appDelegate.alertBasicAuth dismissWithClickedButtonIndex:0 animated:false];
    }
    
    // Get the correct action from settings
    NSString* idleAction = [[MokiManage sharedManager] stringForKey:@"idleTimeAction"];
    if ([idleAction isEqualToString:@"screensaver"]) {
        
        // Start screensaver
        NSArray* screenSaverItems = [[MokiManage sharedManager] arrayForKey:@"screensaverPlaylistItems"];
        if (screenSaverItems && screenSaverItems.count > 0){
            [self performSegueWithIdentifier:@"ScreenSaverViewControllerSegue" sender:self];
        }
        else{
            [self resetIdleTimer];
        }
    }
    else if ([idleAction isEqualToString:@"home"]) {
        // Remove cookies and return to home screen
        [self endSelected:nil];
    }
    
    [[UIPrintInteractionController sharedPrintController] dismissAnimated:YES];
    
}
// Scrolls the carouselView to a given index
-(void) scrollToItemAtIndex:(int)index
{
    [[NSNotificationCenter defaultCenter] postNotificationName:MTUserInteractedNotification object:nil];
    
    [_carouselView scrollToItemAtIndex:index duration:kMMCarouselAnimationTime];
    
    _intCurrentItem = index;
}



#pragma mark - Settings
// Notification fires when any setting is changed from online or from the settings views in MokiManage SDK
-(void)settingsUpdated:(NSNotification*)notification
{
    
    // Get all the settings that have changed
    NSSet *results = [[notification userInfo] objectForKey:MMNotificationChangedValueKeysKey];
    
    // Determine what settings have changed and update accordingly
    if ([self checkIfSettingsUpdatedWithKeys:[NSArray arrayWithObjects:@"showNavButtons",@"uploadLogo",@"barColor",@"showEndSession",@"showAddressBar",@"showLogo",@"showBottomBar",@"showPrint", nil] inSet:results]) {
        [self determineUIVisibilityFromSettings];
    }
    if ([self checkIfSettingsUpdatedWithKeys:[NSArray arrayWithObjects:@"idleTime", nil] inSet:results]) {
        [self resetIdleTimer];
    }
    if ([self checkIfSettingsUpdatedWithKeys:[NSArray arrayWithObjects:@"deviceVolume", nil] inSet:results]) {
        [self changeDeviceVolume];
    }
    if ([self checkIfSettingsUpdatedWithKeys:[NSArray arrayWithObjects:@"refreshCache", nil] inSet:results]) {
        [self checkToDeleteCache];
    }
    if ([self checkIfSettingsUpdatedWithKeys:[NSArray arrayWithObjects:@"contentItems",@"showAddressBar",@"showBottomBar",@"domainUrlList", nil] inSet:results]) {
        [_carouselView performSelector:@selector(reloadData) withObject:nil afterDelay:1];
        [_footerView resetFooterBtns];
    }
    if ([self checkIfSettingsUpdatedWithKeys:[NSArray arrayWithObjects:@"userAgent", nil] inSet:results]) {
        NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:[[MokiManage sharedManager] stringForKey:@"userAgent"], @"UserAgent", nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
    }
}

// Checks if any of the keys are in the set of changed settings
-(BOOL) checkIfSettingsUpdatedWithKeys:(NSArray*)keys inSet:(NSSet*)set
{
    for (NSString* key in keys)
    {
        if ([set containsObject:key]) {
            return true;
        }
    }
    return false;
}

// UIPanGestureRecognizer call back to see if we should open settings
// To open settings the user must pan from top left corner to top right corner to bottom right corner
-(void)openSettings:(UIPanGestureRecognizer*)gesture {
    // Get current location of pan gesture
    CGPoint pointCurrentLocation = [gesture locationInView:self.view];
    
    // If gesture just began then check if its in the top left corner
    if ([gesture state] == UIGestureRecognizerStateBegan) {
        if ([MiscUtilities distanceBetween:pointCurrentLocation and:CGPointZero] < kMMDistanceToPointForSettings){
            _arrSettingsPanCheck[0] = [NSNumber numberWithBool:true];
        }
    }
    // During the middle of the gesture check to see if it passes by the top right corner
    else if ([gesture state] == UIGestureRecognizerStateChanged) {
        if ([MiscUtilities distanceBetween:pointCurrentLocation and:CGPointMake(self.view.bounds.size.width, 0)] < kMMDistanceToPointForSettings){
            _arrSettingsPanCheck[1] = [NSNumber numberWithBool:true];
        }
    }
    // Check to see if the ending gesture is in the bottom right corner
    else if ([gesture state] == UIGestureRecognizerStateEnded) {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:MTUserInteractedNotification object:nil];
        
        if ([MiscUtilities distanceBetween:pointCurrentLocation and:CGPointMake(self.view.bounds.size.width, self.view.bounds.size.height)] < kMMDistanceToPointForSettings){
            // Check to make sure first to pan check points have been hit and open settings if true
            if ([_arrSettingsPanCheck[0] boolValue] && [_arrSettingsPanCheck[1] boolValue]){
                [self showPasswordAlert];
            }
        }
        
        // Reset pan check points
        _arrSettingsPanCheck[0] = [NSNumber numberWithBool:false];
        _arrSettingsPanCheck[1] = [NSNumber numberWithBool:false];
        
    }
}

// If a password is set in MokiManage settings then we need to display an alert for the user to enter in the password
-(void) showPasswordAlert
{
    
    NSString* passwordFromSettings = [[MokiManage sharedManager] stringForKey:@"adminPassword"];
    
    // If there is a password set from ASM settings then show a popoup where the user can put it in
    if (passwordFromSettings &&  passwordFromSettings.length > 0) {
        
        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Password" message:@"Please enter your password" delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:@"Enter", nil];
        alertView.alertViewStyle = UIAlertViewStyleSecureTextInput;
        
        [alertView showWithCompletion:^(UIAlertView *alertView, NSInteger buttonIndex) {
            if (buttonIndex == 1) {
                
                // Retrieve user password and check it agains settings
                NSString* passwordFromUser = [alertView textFieldAtIndex:0].text;
                if ([passwordFromSettings isEqualToString:passwordFromUser]){
                    
                    // Remove idle timer while setting views are showing
                    [_timerIdle invalidate];
                    _timerIdle = nil;
                    
                    // Open setting views if password was entered correctly
                    [[MokiManage sharedManager] displaySettingsView:[[UIApplication sharedApplication] delegate]];
                    
                }
                else{
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Invalid Password" message:nil delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil];
                    [alertView show];
                }
            }
        }];
    }
    else{
        
        // Remove idle timer while setting views are showing
        [_timerIdle invalidate];
        _timerIdle = nil;
        
        // Open settings views
        [[MokiManage sharedManager] displaySettingsView:[[UIApplication sharedApplication] delegate]];
    }
}

// If MokiManage settings refreshCache is set to true then we reset our manual caching and remove cookies the UIWebView might have saved
-(void) checkToDeleteCache
{
    if ([[MokiManage sharedManager] boolForKey:@"refreshCache"]){
        // Remove all items in the cache directory
        NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        NSFileManager *fileMgr = [NSFileManager defaultManager];
        NSArray *fileArray = [fileMgr contentsOfDirectoryAtPath:cachesPath error:nil];
        for (NSString *filename in fileArray)  {
            [fileMgr removeItemAtPath:[cachesPath stringByAppendingPathComponent:filename] error:NULL];
        }
        // Remove all cookies UIWebView might have saved
        NSArray* allCookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
        for (NSHTTPCookie* cookie in allCookies){
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
        }
    };
}

// MokiManage settings determines what is hidden or shown for the UI. This can be changed dynamically.
-(void) determineUIVisibilityFromSettings
{
    // Check the settings and change the constraint to the appropriate view
    [self shouldShow:[[MokiManage sharedManager] boolForKey:@"showBottomBar"] forView:_footerView withConstraint:_footerHeightConstraint];
    [self shouldShow:[[MokiManage sharedManager] boolForKey:@"showLogo"] forView:_imageViewLogo withConstraint:_logoImageWidthConstraint];
    [self shouldShow:[[MokiManage sharedManager] boolForKey:@"showNavButtons"] forView:_btnPrev withConstraint:_prevBtnWidthConstraint];
    [self shouldShow:[[MokiManage sharedManager] boolForKey:@"showNavButtons"] forView:_btnNext withConstraint:_nextBtnWidthConstraint];
    [self shouldShow:[[MokiManage sharedManager] boolForKey:@"showNavButtons"] forView:_btnHome withConstraint:_homeBtnWidthConstraint];
    [self shouldShow:[[MokiManage sharedManager] boolForKey:@"showNavButtons"] forView:_btnRefresh withConstraint:_refreshBtnWidthConstraint];
    [self shouldShow:[[MokiManage sharedManager] boolForKey:@"showPrint"] forView:_btnPrint withConstraint:_printBtnWidthConstraint];
    [self shouldShow:[[MokiManage sharedManager] boolForKey:@"showEndSession"] forView:_btnEnd withConstraint:_endBtnWidthConstraint];
    [self shouldShow:([[MokiManage sharedManager] boolForKey:@"showAddressBar"] ||
                      [[MokiManage sharedManager] boolForKey:@"showLogo"] ||
                      [[MokiManage sharedManager] boolForKey:@"showNavButtons"] ||
                      [[MokiManage sharedManager] boolForKey:@"showPrint"] ||
                      [[MokiManage sharedManager] boolForKey:@"showEndSession"])
                      forView:_headerView withConstraint:_headerHeightConstraint];
    
    
    // The textfield uses the hidden property on the view because no other constraint depends on it and setting constraint from 0 to anything not 0 makes the white background disappear
    _textFieldURL.hidden = ![[MokiManage sharedManager] boolForKey:@"showAddressBar"];
    if(_headerHeightConstraint == 0)
        _textFieldURL.hidden = true;
    
    // Set background color on header and footer
    NSString* hexString = [[MokiManage sharedManager] stringForKey:@"barColor"];
    _headerView.backgroundColor = [MiscUtilities colorFromHex:hexString];
    _footerView.backgroundColor = [MiscUtilities colorFromHex:hexString];
    
    // Check for new logo
    [self updateLogo];
}

// Set the constraint of the view to 0 if it needs to be hidden, otherwise set it to its original constraint
-(void) shouldShow:(BOOL)shouldShow forView:(UIView*)view withConstraint:(NSLayoutConstraint*)constraintToChange
{
    
    // Record constraint on the view in case we hide it and then need to show it again
    if (constraintToChange.constant != 0 && view.tag == 0){
        view.tag = constraintToChange.constant;
    }
    
    // If the view should show according to ASM settings set its constraint to the view tag. If it needs to hide set the constraint to 0
    if (!shouldShow){
        view.hidden = true;
        constraintToChange.constant = 0;
    } else{
        view.hidden = false;
        if (constraintToChange.constant == 0){
            constraintToChange.constant = view.tag;
        }
    }
}

// From MokiManage settings you can choose to have a custom URL or use the MokiTouch default image
-(void) updateLogo
{
    // Check to see if there is a custom logo url from settings
    NSString* logoURL = [[MokiManage sharedManager] stringForKey:@"uploadLogo"];
    if (logoURL && logoURL.length > 0 && !_imageViewLogo.hidden) {
        // Load the custom logo
        UIImage *newLogo = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:logoURL]]];
        
        // Resize custom logo to fit in the space allotted
        float ratioDifference = _logoImageWidthConstraint.constant/newLogo.size.width;
        
        if (newLogo.size.width > _logoImageWidthConstraint.constant || newLogo.size.height > _imageViewLogo.frame.size.height) {
            if (ratioDifference * newLogo.size.height > _imageViewLogo.frame.size.height) {
                ratioDifference = _imageViewLogo.frame.size.height/newLogo.size.height;
            }
            newLogo = [MiscUtilities imageWithImage:newLogo scaledToSize:CGSizeMake(ratioDifference * newLogo.size.width, ratioDifference * newLogo.size.height)];
            
        }
        
        [_imageViewLogo setImage:newLogo];
    }
    else{
        // If no custom logo is set then use MokiTouch's default logo
        [_imageViewLogo setImage:[UIImage imageNamed:@"UI-MT_logo"]];
    }
}

// Change device volume is MokiManage settings says we should
-(void)changeDeviceVolume
{
    // Check ASM settings for what the device volume should be and set
    int volumeFromSettings = [[MokiManage sharedManager] integerForKey:@"deviceVolume"];
    MPMusicPlayerController *musicPlayer = [MPMusicPlayerController applicationMusicPlayer];
    musicPlayer.volume = volumeFromSettings/kMMDeviceVolumeMax;
}




#pragma mark - Header Button Actions
- (IBAction)previousSelected:(id)sender {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MTUserInteractedNotification object:nil];
    ContentView* contentView = (ContentView*)_carouselView.currentItemView;
    [contentView goBack];
    _textFieldURL.text = contentView.contentURL.absoluteString;
}
- (IBAction)nextSelected:(id)sender {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MTUserInteractedNotification object:nil];
    ContentView* contentView = (ContentView*)_carouselView.currentItemView;
    [contentView goForward];
    _textFieldURL.text = contentView.contentURL.absoluteString;
}
- (IBAction)homeSelected:(id)sender {
    
    // If we are already on the first item then reload it
    if (_intCurrentItem == 0) {
        [_carouselView reloadData];
    }
    // Else scroll to the first content item
    else{
        [self scrollToItemAtIndex:0];
    }
    [_footerView selectButtonAtIndex:0];
    
}
- (IBAction)refreshSelected:(id)sender {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MTUserInteractedNotification object:nil];
    ContentView* contentView = (ContentView*)_carouselView.currentItemView;
    [contentView reload];
}
- (IBAction)printSelected:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:MTUserInteractedNotification object:nil];
    if ([UIPrintInteractionController isPrintingAvailable])
    {
        ContentView* contentView = (ContentView*)_carouselView.currentItemView;
        
        UIPrintInteractionController *pic = [UIPrintInteractionController sharedPrintController];
        
        UIPrintInfo *printInfo = [UIPrintInfo printInfo];
        printInfo.outputType = UIPrintInfoOutputGeneral;
        printInfo.jobName = _textFieldURL.text;
        pic.printInfo = printInfo;
        
        UIViewPrintFormatter *formatter = [contentView viewPrintFormatter];
        pic.printFormatter = formatter;
        
        void (^completionHandler)(UIPrintInteractionController *, BOOL, NSError *) =
        ^(UIPrintInteractionController *printController, BOOL completed, NSError *error) {
            if (!completed && error){
                NSLog(@"Print failed - domain: %@ error code %u", error.domain, error.code);
            }
        };
        
        UIButton* printBtn = (UIButton*)sender;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [pic presentFromRect:printBtn.frame inView:self.view animated:true completionHandler:completionHandler];
        } else {
            [pic presentAnimated:YES completionHandler:completionHandler];
        }

    } else {
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Print Unavailable" message:@"Printing is not set up for this device" delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil];
        [alert show];
    }
}
- (IBAction)endSelected:(id)sender {
    
    // remove all authentication credentials
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:MTAuthenticationCredentialsKey];
    
    // Remove webview cache
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    // Remove stored cookies
    [[NSNotificationCenter defaultCenter] postNotificationName:MTUserInteractedNotification object:nil];
    NSHTTPCookie *cookie;
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (cookie in [storage cookies]) {
        [storage deleteCookie:cookie];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    
    // reset the credentials cache...
    NSDictionary *credentialsDict = [[NSURLCredentialStorage sharedCredentialStorage] allCredentials];
    
    if ([credentialsDict count] > 0) {
        // the credentialsDict has NSURLProtectionSpace objs as keys and dicts of userName => NSURLCredential
        NSEnumerator *protectionSpaceEnumerator = [credentialsDict keyEnumerator];
        NSURLProtectionSpace* urlProtectionSpace;
        
        // iterate over all NSURLProtectionSpaces
        while (urlProtectionSpace = [protectionSpaceEnumerator nextObject]) {
            NSEnumerator *userNameEnumerator = [[credentialsDict objectForKey:urlProtectionSpace] keyEnumerator];
            id userName;
            
            // iterate over all usernames for this protectionspace, which are the keys for the actual NSURLCredentials
            while (userName = [userNameEnumerator nextObject]) {
                NSURLCredential *cred = [[credentialsDict objectForKey:urlProtectionSpace] objectForKey:userName];
                NSLog(@"cred to be removed: %@", cred);
                //[MiscUtilities saveCredentialsToKeychainWithUsername:userName password:@"" host:urlProtectionSpace.host port:urlProtectionSpace.port protocol:urlProtectionSpace.protocol realm:urlProtectionSpace.realm];
                [[NSURLCredentialStorage sharedCredentialStorage] removeCredential:cred forProtectionSpace:urlProtectionSpace];
            }
        }
    }
    
    [self homeSelected:nil];
}



#pragma mark - UIScrollView Delegate Methods
-(void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    [[NSNotificationCenter defaultCenter] postNotificationName:MTUserInteractedNotification object:nil];
}




#pragma mark - UITextField Delegate Methods
-(BOOL) textFieldShouldReturn:(UITextField *)textField
{
    
    NSString* webAddress = [MiscUtilities addHttpToURL:textField.text];
    
    if ([MiscUtilities siteAllowedForURL:[NSURL URLWithString:webAddress]]) {
        ContentView* contentView = (ContentView*)_carouselView.currentItemView;
        
        [contentView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
        contentView.contentURL = [NSURL URLWithString:webAddress];
        
        [textField resignFirstResponder];
    }
    
    return true;
}
-(void) textFieldDidBeginEditing:(UITextField *)textField
{
    [[NSNotificationCenter defaultCenter] postNotificationName:MTUserInteractedNotification object:nil];
}





#pragma mark - SwipeView View DataSource Methods

- (NSInteger)numberOfItemsInSwipeView:(SwipeView *)swipeView
{
    // Return number of content items from settings
    _intNumberOfItems = [[[MokiManage sharedManager] arrayForKey:@"contentItems"] count];
    return _intNumberOfItems;
}
- (UIView *)swipeView:(SwipeView *)swipeView viewForItemAtIndex:(NSInteger)index reusingView:(UIView *)view
{
    // Create the content view for the content item specified in settings
    NSArray* arrOfContentItems = [[MokiManage sharedManager] arrayForKey:@"contentItems"];
    NSString* webAddress = [MiscUtilities addHttpToURL:[[arrOfContentItems objectAtIndex:index] objectForKey:@"content"]];
    
    // we can reuse the view if it is pointing to the correct web address
    ContentView* contentView = (ContentView*)view;
    if ([contentView.contentURL.absoluteString isEqualToString:webAddress]) {
        if (contentView.contentType == ContentTypeVideo) {
            [contentView.moviePlayer play];
        }
        view.frame = swipeView.frame;
        return view;
    }
    
    // Create a ContentView from web address
    ContentView* newContentView = [[ContentView alloc] initWithFrame:swipeView.frame];
    newContentView.delegate = self;
    newContentView.pauseAllowed = true;
    newContentView.contentURL = [NSURL URLWithString:webAddress];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MTUserInteractedNotification object:nil];
    
    // Set url
    _textFieldURL.text = webAddress;
    
    // Add the progress HUD
    if ([[MokiManage sharedManager] boolForKey:@"showProgress"]) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:newContentView animated:YES];
        hud.labelText = @"Loading";
    }
    
    return newContentView;
}

#pragma mark - Content View Delegate Methods
-(void) contentViewDidFinishLoad:(ContentView*)contentView
{
    if (contentView.contentType == ContentTypeVideo) {
        [contentView.moviePlayer setRepeatMode:MPMovieRepeatModeOne];
    }
    
    if (contentView == [_carouselView itemViewAtIndex:_intCurrentItem]){
        if (contentView.contentType == ContentTypeWebsite) {
            if (![contentView.webView.request.URL.absoluteString isEqualToString:MTBlankContentURLForWebView]) {
                _textFieldURL.text = contentView.webView.request.URL.absoluteString;
            }
        }
        else{
            _textFieldURL.text = contentView.contentURL.absoluteString;
        }
    }

}


#pragma mark - SwipeView View Delegate Methods

- (CGSize)swipeViewItemSize:(SwipeView *)swipeView
{
    return self.view.bounds.size;
}

- (void)swipeViewDidEndDecelerating:(SwipeView *)swipeView;
{
    _intCurrentItem = swipeView.currentItemIndex;
    
    [_footerView selectButtonAtIndex:_intCurrentItem];
    
    _textFieldURL.text = ((ContentView*)_carouselView.currentItemView).contentURL.absoluteString;
}


#pragma mark - UIGestureRecognizer Delegate Methods
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return true;
}


@end
