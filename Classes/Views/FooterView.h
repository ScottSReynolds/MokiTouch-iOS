//
//  FooterView.h
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
@protocol FooterViewDelegate
-(void) scrollToItemAtIndex:(int)index;
@end

@interface FooterView : UIView
{
    NSMutableArray* _arrFooterBtns;
    
    UIScrollView* _scrollView;
    
    int _intXPostition;
    int _intCurrentSelectedBtn;
}

@property (retain) id delegate;
@property (nonatomic, assign) int intNumberOfItems;

- (void) layoutFooterBtns;
- (void) resetFooterBtns;
- (void) selectButtonAtIndex:(int)index;
@end
