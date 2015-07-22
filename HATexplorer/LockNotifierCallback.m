//
//  LockNotifierCallback.m
//  HATFinder
//
//  Created by David Jensenius on 2015-05-02.
//  Copyright (c) 2015 David Jensenius. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LockNotifierCallback.h"

static void displayStatusChanged(CFNotificationCenterRef center,
                                 void *observer,
                                 CFStringRef name,
                                 const void *object,
                                 CFDictionaryRef userInfo) {
    if ([(__bridge NSString *)name  isEqual: @"com.apple.springboard.lockcomplete"]) {
        NSLog(@"Screen Locked");
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"kDisplayStatusLocked"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

@implementation LockNotifierCallback

+ (void(*)(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo))notifierProc {
    return displayStatusChanged;
}

@end