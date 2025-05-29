//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBStartupTracker.h"

@implementation EMBStartupTracker

+ (instancetype)shared {
    static EMBStartupTracker *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[EMBStartupTracker alloc] init];
    });
    return sharedInstance;
}

- (void)setFirstFrameTime:(NSDate *)firstFrameTime {
    _firstFrameTime = firstFrameTime;

    if (self.onFirstFrameTimeSet) {
        self.onFirstFrameTimeSet(firstFrameTime);
    }
}

- (void)trackDidFinishLaunching {
    self.appDidFinishLaunchingEndTime = nil;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppDidFinishLaunching:)
                                                 name:@"UIApplicationDidFinishLaunchingNotification"
                                               object:nil];
}

- (void)onAppDidFinishLaunching:(NSNotification *)notification {
    NSDate *now = NSDate.date;
    self.appDidFinishLaunchingEndTime = now;

    if (self.onAppDidFinishLaunchingEndTimeSet) {
        self.onAppDidFinishLaunchingEndTimeSet(now);
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
