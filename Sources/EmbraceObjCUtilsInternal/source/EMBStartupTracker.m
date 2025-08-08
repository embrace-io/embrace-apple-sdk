//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBStartupTracker.h"

#import <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <AppKit/AppKit.h>
#endif

@implementation EMBStartupTracker

+ (instancetype)shared
{
    static EMBStartupTracker *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[EMBStartupTracker alloc] init];
    });
    return sharedInstance;
}

- (void)setFirstFrameTime:(NSDate *)firstFrameTime
{
    _firstFrameTime = firstFrameTime;

    if (self.onFirstFrameTimeSet) {
        self.onFirstFrameTimeSet(firstFrameTime);
    }
}

- (void)trackDidFinishLaunching
{
    self.appDidFinishLaunchingEndTime = nil;

#if TARGET_OS_IOS
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppDidFinishLaunching:)
                                                 name:UIApplicationDidFinishLaunchingNotification
                                               object:nil];
#elif TARGET_OS_OSX
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppDidFinishLaunching:)
                                                 name:NSApplicationDidFinishLaunchingNotification
                                               object:nil];
#endif
}

- (void)onAppDidFinishLaunching:(NSNotification *)notification
{
    NSDate *now = NSDate.date;
    self.appDidFinishLaunchingEndTime = now;

    if (self.onAppDidFinishLaunchingEndTimeSet) {
        self.onAppDidFinishLaunchingEndTimeSet(now);
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
