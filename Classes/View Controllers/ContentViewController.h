//
//  ContentViewController.h
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
#import "SwipeView.h"
#import "FooterView.h"

@interface ContentViewController : UIViewController <SwipeViewDataSource, SwipeViewDelegate, FooterViewDelegate, UITextFieldDelegate, UIWebViewDelegate, MokiManageDelegate, UIScrollViewDelegate, UIGestureRecognizerDelegate>
{
    int _intNumberOfItems;
    int _intCurrentItem;
    
    NSTimer* _timerIdle;
    NSMutableArray* _arrSettingsPanCheck;
    NSMutableDictionary* _dictOldContraintValues;
}
@property (weak, nonatomic) IBOutlet UIView *headerView;
@property (weak, nonatomic) IBOutlet FooterView *footerView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet SwipeView *carouselView;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewLogo;
@property (weak, nonatomic) IBOutlet UIButton *btnPrev;
@property (weak, nonatomic) IBOutlet UIButton *btnNext;
@property (weak, nonatomic) IBOutlet UIButton *btnHome;
@property (weak, nonatomic) IBOutlet UIButton *btnRefresh;
@property (weak, nonatomic) IBOutlet UIButton *btnEnd;
@property (weak, nonatomic) IBOutlet UIButton *btnPrint;
@property (weak, nonatomic) IBOutlet UITextField *textFieldURL;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *headerHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *footerHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textFieldHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *printBtnWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *endBtnWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *refreshBtnWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *homeBtnWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *nextBtnWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *prevBtnWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *logoImageWidthConstraint;

@end
