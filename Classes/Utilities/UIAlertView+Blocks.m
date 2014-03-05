//
//  UIAlertView+Blocks.m
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

#import <objc/runtime.h>
#import "UIAlertView+Blocks.h"


@interface MMAlertWrapper : NSObject

@property (copy) void(^completionBlock)(UIAlertView *alertView, NSInteger buttonIndex);

@end

@implementation MMAlertWrapper

#pragma mark - UIAlertViewDelegate

// Called when a button is clicked. The view will be automatically dismissed after this call returns
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (self.completionBlock){
        self.completionBlock(alertView, buttonIndex);
    }
}

// Called when we cancel a view (eg. the user clicks the Home button). This is not called when the user clicks the cancel button.
// If not defined in the delegate, we simulate a click in the cancel button
- (void)alertViewCancel:(UIAlertView *)alertView
{
    // Just simulate a cancel button click
    if (self.completionBlock){
        self.completionBlock(alertView, alertView.cancelButtonIndex);
    }
}

@end

static const char kMMAlertWrapper;

@implementation UIAlertView (Blocks)

#pragma mark - Class Public

- (void)showWithCompletion:(void(^)(UIAlertView *alertView, NSInteger buttonIndex))completion
{
    MMAlertWrapper *alertWrapper = [[MMAlertWrapper alloc] init];
    alertWrapper.completionBlock = completion;
    self.delegate = alertWrapper;
    
    // Set the wrapper as an associated object
    objc_setAssociatedObject(self, &kMMAlertWrapper, alertWrapper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Show the alert as normal
    [self show];
}
@end
