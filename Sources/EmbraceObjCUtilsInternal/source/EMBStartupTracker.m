//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBStartupTracker.h"
#import "EMBDisplayLinkProxy.h"

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
        [sharedInstance trackLifecycleNotifications];
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

- (void)trackLifecycleNotifications
{
    self.appDidFinishLaunchingEndTime = nil;

#if TARGET_OS_IOS
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppDidFinishLaunching:)
                                                 name:UIApplicationDidFinishLaunchingNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
#elif TARGET_OS_OSX
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppDidFinishLaunching:)
                                                 name:NSApplicationDidFinishLaunchingNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppDidBecomeActive:)
                                                 name:NSApplicationDidBecomeActiveNotification
                                               object:nil];
#endif
}

- (void)onAppDidBecomeActive:(NSNotification *)notification
{
#if TARGET_OS_IOS
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
#elif TARGET_OS_OSX
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationDidBecomeActiveNotification object:nil];
#endif

    // Now that we know the app has started and is active,
    // we can track the first frame, otherwise we might get
    // a first frame when the app isn't visible.
    if (@available(macOS 14.0, tvOS 9.0, iOS 3.0, *)) {
        [[EMBDisplayLinkProxy shared] trackNextTick:^{
            [EMBStartupTracker shared].firstFrameTime = [NSDate date];
        }];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [EMBStartupTracker shared].firstFrameTime = [NSDate date];
        });
    }
}

- (void)onAppDidFinishLaunching:(NSNotification *)notification
{
    NSDate *now = NSDate.date;
    self.appDidFinishLaunchingEndTime = now;

    if (self.onAppDidFinishLaunchingEndTimeSet) {
        self.onAppDidFinishLaunchingEndTimeSet(now);
    }
#if TARGET_OS_IOS
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidFinishLaunchingNotification
                                                  object:nil];
#elif TARGET_OS_OSX
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSApplicationDidFinishLaunchingNotification
                                                  object:nil];
#endif
}

@end
