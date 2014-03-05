//
//  MiscUtilities.m
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


#import "MiscUtilities.h"

@implementation MiscUtilities

+(UIColor*) colorFromHex:(NSString*)stringHex
{
    stringHex = [stringHex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (stringHex) {
        NSScanner* scanner = [NSScanner scannerWithString:stringHex];
        unsigned int hex = 0, r = 0, g = 0, b = 0;
        
        if ([scanner scanHexInt:&hex]) {
            r= (hex >> 16) & 0xFF; // get the first byte
            g = (hex >>  8) & 0xFF; // get the middle byte
            b = (hex      ) & 0xFF; // get the last byte
        } else {
            NSLog(@"Parsing error: no hex value found in string");
        }
        
        return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1];
    }
    return nil;
}

+ (float) distanceBetween : (CGPoint) p1 and: (CGPoint)p2
{
    return sqrt(pow(p2.x-p1.x,2)+pow(p2.y-p1.y,2));
}

+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}
+(NSString*) addHttpToURL:(NSString*)url
{
    if ([url rangeOfString:@"://"].location == NSNotFound){
        url = [NSString stringWithFormat:@"%@%@",@"http://", url];
    }
    return url;
}

+(NSString*) prepareStringForComparing:(NSString*)string
{
    string = [string lowercaseString];
    string = [string stringByReplacingOccurrencesOfString:@"http://" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"https://" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"www." withString:@""];
    return string;
}

// Checks allowed domains from MokiManage settings to see if we can go to a given url
+(BOOL) siteAllowedForURL:(NSURL*)url
{
    NSArray* domainUrlList = [[MokiManage sharedManager] arrayForKey:@"domainUrlList"];
    if (domainUrlList.count > 0) {
        NSMutableArray* allowedDomains = [[NSMutableArray alloc] init];
        
        // Add whitelist urls to allowable domains
        for (NSDictionary* item in domainUrlList){
            [allowedDomains addObject:[item objectForKey:@"domainUrl"]];
        }
        
        // Add content item urls to allowable domains
        NSArray* contentItems = [[MokiManage sharedManager] arrayForKey:@"contentItems"];
        for (NSDictionary* item in contentItems){
            [allowedDomains addObject:[item objectForKey:@"content"]];
        }
        
        // Check if url is allowed and return true if true
        for (__strong NSString* restrictedURL in allowedDomains){
            NSString* urlString = [MiscUtilities prepareStringForComparing:[url absoluteString]];
            restrictedURL = [MiscUtilities prepareStringForComparing:restrictedURL];
            if ([urlString rangeOfString:restrictedURL].location != NSNotFound) {
                return true;
            }
        }
        
        // If site is not allowed then return fals and throw alert if settings wants us to
        if ([[MokiManage sharedManager] boolForKey:@"forbiddenSitesAlert"]) {
            UIAlertView* restrictedSiteAlert = [[UIAlertView alloc] initWithTitle:@"Restricted Site" message:[[MokiManage sharedManager] stringForKey:@"forbiddenAlertMessage"] delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil];
            [restrictedSiteAlert show];
        }
        
        return false;
    }
    return true;
}
@end
