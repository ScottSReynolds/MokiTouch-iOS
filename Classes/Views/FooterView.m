//
//  FooterView.m
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


#import "FooterView.h"
#import "FooterButton.h"

@implementation FooterView

// Recalculate number of footer buttons and their sizes
-(void) resetFooterBtns
{
    // Calculate the width of each button
    [self calculateFooterBtnSizes];
    // Figure out the position of each button
    [self layoutFooterBtns];
    // Highlight the correct button
    if (_intCurrentSelectedBtn < _arrFooterBtns.count)
        [_arrFooterBtns[_intCurrentSelectedBtn] setSelected:true];
}
// Figure out the position of each button
- (void) layoutFooterBtns
{
    // Figure out the padding for the buttons so that they stretch across the screen. The padding from the edge of the button to the words needs to be the same for each button
    float amountToAddToEachBtn = 0.0;
    if(_intXPostition < self.bounds.size.width){
        amountToAddToEachBtn = (self.bounds.size.width - _intXPostition)/_intNumberOfItems;
    }
    
    // Add the padding to each button
    float x = 0;
    for (int i = 0; i < _arrFooterBtns.count; i++) {
        FooterButton* footerBtn = [_arrFooterBtns objectAtIndex:i];
        footerBtn.frame = CGRectMake(x, footerBtn.frame.origin.y, footerBtn.intMinimumWidth + amountToAddToEachBtn, footerBtn.frame.size.height);
        
        x += footerBtn.frame.size.width;
    }
    
    // Set the scrollview width to screen width and content size to the width of all the buttons
    _scrollView.frame = CGRectMake(_scrollView.frame.origin.x, _scrollView.frame.origin.y, self.bounds.size.width, _scrollView.frame.size.height);
    _scrollView.contentSize = CGSizeMake(x, _scrollView.frame.size.height);
    
}
// Highlight selected button and scroll to it if necessary
- (void) footerBtnSelected:(UIButton*)btn
{    
    _intCurrentSelectedBtn = btn.tag;
    [self selectButtonAtIndex:btn.tag];
    [_delegate scrollToItemAtIndex:btn.tag];
}
// Calculate the width of each button
-(void) calculateFooterBtnSizes
{
    // Create or reset the footer buttons so we can recalculate the sizes
    if (_arrFooterBtns) {
        for (FooterButton* footerBtn in _arrFooterBtns)
            [footerBtn removeFromSuperview];
        [_arrFooterBtns removeAllObjects];
    }
    else
        _arrFooterBtns = [[NSMutableArray alloc] init];
    
    // Create the scroll view to house the buttons
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.tag)];
    [self addSubview:_scrollView];
    
    // Get number of content items from MokiManage settings
    NSDictionary* settings = [[MokiManage sharedManager] settings];
    NSArray* arrOfContentItems = [[settings objectForKey:@"Values"] objectForKey:@"contentItems"];
    _intNumberOfItems = arrOfContentItems.count;
    
    // Create the fotter buttons and set initial position
    _intXPostition = 0;
    for (int i = 0; i < _intNumberOfItems; i++) {
        FooterButton* footerBtn = [[FooterButton alloc] initWithFrame:CGRectMake(_intXPostition, 0, 0, self.tag) title:[[arrOfContentItems objectAtIndex:i] objectForKey:@"title"]];
        [footerBtn addTarget:self action:@selector(footerBtnSelected:) forControlEvents:UIControlEventTouchUpInside];
        footerBtn.tag = i;
        [_scrollView addSubview:footerBtn];
        [_arrFooterBtns addObject:footerBtn];
        
        _intXPostition += footerBtn.frame.size.width;
    }
    
    // Set content size of scroll view to encapsulate all the buttons
    _scrollView.contentSize = CGSizeMake(_intXPostition, _scrollView.frame.size.height);
}

// highlight footer button at given index
- (void) selectButtonAtIndex:(int)index
{
    if (_arrFooterBtns.count > index) {
        // Unselect all buttons
        for (FooterButton* footerBtn in _arrFooterBtns){
            footerBtn.selected = false;
        }
        // Select correct button
        FooterButton* selectedBtn = [_arrFooterBtns objectAtIndex:index];
        selectedBtn.selected = true;
        
        // Make sure button is visible on screen
        [_scrollView scrollRectToVisible:CGRectMake(selectedBtn.center.x - roundf(_scrollView.frame.size.width/2.0),
                                                    selectedBtn.center.y - roundf(_scrollView.frame.size.height/2.0),
                                                    _scrollView.frame.size.width,
                                                    _scrollView.frame.size.height)
                                animated:YES];
        
        _intCurrentSelectedBtn = index;
    }
    
    
}
@end
