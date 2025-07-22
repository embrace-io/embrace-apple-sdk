//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBDisplayLinkProxy.h"
#import <UIKit/Uikit.h>
#import "EMBStartupTracker.h"

@implementation EMBDisplayLinkProxy {
    BOOL hasRun;
}

+ (instancetype)shared
{
    static EMBDisplayLinkProxy *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [EMBDisplayLinkProxy alloc];
    });
    return sharedInstance;
}

- (void)onFrameUpdate
{
    if (!hasRun) {
        hasRun = YES;
        [EMBStartupTracker shared].firstFrameTime = [NSDate date];

        // Invalidates the CADisplayLink
        [CADisplayLink displayLinkWithTarget:self selector:@selector(onFrameUpdate)].paused = YES;
    }
}

@end
