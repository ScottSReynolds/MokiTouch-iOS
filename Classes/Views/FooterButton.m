//
//  FooterButton.m
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


#import "FooterButton.h"


@implementation FooterButton

#define kMMDynamicFontSizeMultiplier 0.8

#define UIColorFromRGB(rgbValue) [UIColor \
colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0xFF00) >> 8))/255.0 \
blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

- (id)initWithFrame:(CGRect)frame title:(NSString*)title
{
    self = [super initWithFrame:frame];
    if (self) {
        
        // Set font and size
        float fontSize = frame.size.height/3;
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
            UIFontDescriptor *userFont = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleBody];
            fontSize = [userFont pointSize]*kMMDynamicFontSizeMultiplier;
        }
        
        UIFont *titleFont = [UIFont fontWithName:@"ProximaNova-Regular" size:fontSize];
        CGSize titleSize = [title sizeWithFont:titleFont constrainedToSize:CGSizeMake(10000, frame.size.height)];
        
        // Set the width of the button based on the size of the text and default padding
        int padding = frame.size.height/2;
        _intMinimumWidth = titleSize.width+(padding*2);
        
        self.frame = CGRectMake(frame.origin.x, frame.origin.y, _intMinimumWidth, frame.size.height);
        
        // Create text label and add it
        _labelTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, _intMinimumWidth, frame.size.height)];
        _labelTitle.backgroundColor = [UIColor clearColor];
        _labelTitle.textAlignment = NSTextAlignmentCenter;
        _labelTitle.font = titleFont;
        _labelTitle.text = title;
        
        _labelTitle.textColor = UIColorFromRGB(0xFFFFFF);
        [self addSubview:_labelTitle];
    }
    return self;
}
-(void) layoutSubviews
{
    _labelTitle.center = CGPointMake(self.frame.size.width/2, _labelTitle.center.y);
}
// Custom drawing the background and separator line
- (void)drawRect:(CGRect)rect;
{
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (self.selected){
        CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:0 alpha:46.0/225.0].CGColor);
    }else{
        CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
    }
    
    CGContextFillRect(context, rect);
    
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithWhite:.8 alpha:1].CGColor);
    
    CGContextBeginPath(context);
    
    CGContextMoveToPoint(context, rect.size.width, 0.0); //start point
    CGContextAddLineToPoint(context, rect.size.width, rect.size.height);
    
    CGContextClosePath(context); // close path
    
    CGContextSetLineWidth(context, 1.0); // this is set from now on until you explicitly change it
    
    CGContextStrokePath(context); // do actual stroking
    
}
@end
