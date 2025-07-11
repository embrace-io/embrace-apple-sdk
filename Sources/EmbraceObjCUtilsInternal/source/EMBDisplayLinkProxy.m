//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <TargetConditionals.h>

#if TARGET_OS_IPHONE
  // iOS, tvOS, watchOS
#import <UIKit/UIKit.h>
#else
  // macOS
#import <Cocoa/Cocoa.h>
#endif
#import "EMBDisplayLinkProxy.h"
#import "EMBStartupTracker.h"
#import "EMBLoaderClass.h"

@implementation EMBDisplayLinkProxy {
    BOOL hasRun;
}

+ (instancetype)shared {
    static EMBDisplayLinkProxy *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [EMBDisplayLinkProxy alloc];
    });
    return sharedInstance;
}

- (void)onFrameUpdate {
    if (!hasRun) {
        hasRun = YES;
        [EMBStartupTracker shared].firstFrameTime = [NSDate date];
        
        [[EMBLoaderClass shared].displayLink invalidate];
        [EMBLoaderClass shared].displayLink = nil;
    }
}

@end
