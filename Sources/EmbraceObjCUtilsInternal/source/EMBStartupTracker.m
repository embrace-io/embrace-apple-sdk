//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBStartupTracker.h"

NSNotificationName const EMBDidRenderFirstFrameNotification = @"EMBDidRenderFirstFrameNotification";

@implementation EMBStartupTracker {
    BOOL notificationFired;
}

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

    if (notificationFired || !self.internalNotificationCenter) {
        return;
    }
    
    [self.internalNotificationCenter postNotificationName:EMBDidRenderFirstFrameNotification object:nil];
    notificationFired = YES;
}

- (void)trackDidFinishLaunching {
    self.appDidFinishLaunchingEndTime = nil;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppDidFinishLaunching:)
                                                 name:@"UIApplicationDidFinishLaunchingNotification"
                                               object:nil];
}

- (void)onAppDidFinishLaunching:(NSNotification *)notification {
    self.appDidFinishLaunchingEndTime = [NSDate date];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
