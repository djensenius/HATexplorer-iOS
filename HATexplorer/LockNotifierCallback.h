//
//  LockNotifierCallback.h
//  HATFinder
//
//  Created by David Jensenius on 2015-05-02.
//  Copyright (c) 2015 David Jensenius. All rights reserved.
//

#ifndef HATFinder_LockNotifierCallback_h
#define HATFinder_LockNotifierCallback_h

@interface LockNotifierCallback : NSObject


+ (void(*)(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo))notifierProc;


@end

#endif
