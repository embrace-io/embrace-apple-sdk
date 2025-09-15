//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <pthread.h>
#import <sys/time.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

#import "EMBDisplayLinkProxy.h"
#import "EMBLoaderClass.h"
#import "EMBStartupTracker.h"

static pthread_t sMainThread = NULL;
pthread_t EmbraceGetMainThread(void) { return sMainThread; }

@implementation EMBLoaderClass

#pragma mark -  Start up measurement

// First method to be called
+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sMainThread = pthread_self();
    });
    [[EMBStartupTracker shared] setLoadTime:[NSDate now]];
}

// Second to be called
__attribute__((constructor(101))) static void calledAsEarlyAsPossible(void)
{
    [[EMBStartupTracker shared] setConstructorMostFarFromMainTime:[NSDate now]];
}

// Third to be called
// Will be called right before main() is called.
__attribute__((constructor(65535))) static void calledRightBeforeMain(void)
{
    [[EMBStartupTracker shared] setConstructorClosestToMainTime:[NSDate now]];

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

@end

