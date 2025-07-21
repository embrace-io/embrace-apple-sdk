//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKey.h>
#include <sys/time.h>

#import "EMBDisplayLinkProxy.h"
#import "EMBLoaderClass.h"
#import "EMBStartupTracker.h"

@implementation EMBLoaderClass

static CADisplayLink *displayLink = nil;

#pragma mark -  Start up measurement

// First method to be called
+ (void)load
{
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

    displayLink = [CADisplayLink displayLinkWithTarget:[EMBDisplayLinkProxy shared] selector:@selector(onFrameUpdate)];
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

@end

