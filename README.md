MokiTouch
=========
**Important: An active subscription to [Tracker](https://www.mokimanage.com/) to connect Tracker services.**

MokiTouch is a kiosk application developed by Moki to demonstrate the power of our MokiManage SDK. Our Application Settings Management tools are used to provide a variety of kiosk customization to users across multiple accounts. Our support feature set is also included. All settings can be managed remotely from our web interface on a per device or per device group basis. This is a brief overview on how MokiManage is integrated with MokiTouch and to show how to easily add MokiManage into any app.

Info.plist
----------
`Info.plist` has a few important additional entries

* `logging: YES`
if you want debugging info to be printed to the console.
* `appId:<appId>`
You get your appId from the developer account section on MokiManage.
* `certType:{store:NO, enterpise:NO, sandbox:YES}`
In your MokiManage account you must have apns certs uploaded for each tenant app. This value will tell the SDK which     cert should be used on enrollment. MokiTouch already has sandbox certs setup for you. Use sandbox for local development.

Resources
---------
`SettingsSchema.json` is a file you must include that defines the structure and defaults of all ASM options you can use to customize the settings for the application from your account on MokiManage.

Implementation
--------------
###SDK###
`#define API_KEY @"bf517fc9-5993-49ea-9d2c-2f719447e5e6"` should be set in the AppDelegate so you can use it when initializing.
MokiManage API Initialization in the method `application:didFinishLaunchingWithOptions:`

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

This sets content defaults so there is a home page and a screensaver page when app is first started.

    if ([[[MokiManage sharedManager] arrayForKey:@"contentItems"] count] == 0) {
        NSArray *defaultContent = @[
            @{@"title":@"Start Page", @"content":@"http://mokicloud.com/mokitouch"}];
        [[MokiManage sharedManager] setObject:defaultContent forKey:@"contentItems"];
    }
    if ([[[MokiManage sharedManager] arrayForKey:@"contentItems"] count] == 0) {
        NSArray *defaultScreensaverContent = @[
            @{@"content":@"http://vimeo.com/50547474/download?t=1381162078&v=120388389&s=1a5f307aa8dfd9aa5cf07f8ccffec4e9", @"duration":@10}];
        [[MokiManage sharedManager] setObject:defaultScreensaverContent forKey:@"screensaverPlaylistItems"];
    }

###Push Notifications###
Apple Push Notifications methods pass information to the MokiManage SDK

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

###ASM (Application Settings Management)###
Observe settings changes when settings get updated from the server or from the settings views within the app:
 	
 	// Notification when MokiManage settings gets updated
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsUpdated:) name:MMApplicationDidChangeSettingsNotification object:nil];

When settings change this checks to see what was changed and passes it to the appropriate methods to handle it:

    -(void)settingsUpdated:(NSNotification*)notification
	{
    	// Get all the settings that have changed
    	NSSet *results = [[notification userInfo] objectForKey:MMNotificationChangedValueKeysKey];
    
    	// Determine what settings have changed and update accordingly
    	if ([self checkIfSettingsUpdatedWithKeys:[NSArray arrayWithObjects:@"showNavButtons",@"uploadLogo",@"barColor",@"showEndSession",@"showAddressBar",@"showLogo",@"showBottomBar",@"showPrint", nil] inSet:results]) {
        	[self determineUIVisibilityFromSettings];
    	}
    	if ([self checkIfSettingsUpdatedWithKeys:[NSArray arrayWithObjects:@"screensaverPlaylistItems",@"idleTime", nil] inSet:results]) {
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

Display the settings views that allow editing settings locally:

    [[MokiManage sharedManager] displaySettingsView:[[UIApplication sharedApplication] delegate]];

