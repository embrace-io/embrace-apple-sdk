//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#if TARGET_OS_IPHONE
//#import <UIKit/UIKey.h>
#else
#import <Cocoa/Cocoa.h>
#import <CoreVideo/CVDisplayLink.h>
#endif

#include <sys/time.h>

#import "EMBLoaderClass.h"
#import "EMBDisplayLinkProxy.h"
#import "EMBStartupTracker.h"

@implementation EMBLoaderClass

static EMBLoaderClass *sharedInstance = nil;

+ (EMBLoaderClass *)shared {
    if (sharedInstance == nil) {
        sharedInstance = [[super alloc] init];
    }
    
    return sharedInstance;
}

#pragma mark -  Start up measurement

// First method to be called
+ (void)load {
    [[EMBStartupTracker shared] setLoadTime:[NSDate now]];
}

// Second to be called
__attribute__((constructor(101)))
static void calledAsEarlyAsPossible(void) {
    [[EMBStartupTracker shared] setConstructorMostFarFromMainTime:[NSDate now]];
}

#if TARGET_OS_OSX
- (void)onAppDidFinishLaunching:(NSNotification *)notification {
    NSWindow* window = [[[NSApplication sharedApplication] windows] firstObject];
    if (window) {
        [EMBStartupTracker shared].firstFrameTime = [NSDate date];
        
        [[EMBLoaderClass shared].displayLink invalidate];
        [EMBLoaderClass shared].displayLink = nil;
    }
}
#endif

// Third to be called
// Will be called right before main() is called.
__attribute__((constructor(65535)))
static void calledRightBeforeMain(void) {
    [[EMBStartupTracker shared] setConstructorClosestToMainTime:[NSDate now]];

#if TARGET_OS_IPHONE
    [EMBLoaderClass shared].displayLink = [CADisplayLink displayLinkWithTarget:[EMBDisplayLinkProxy shared] selector:@selector(onFrameUpdate)];
    [[EMBLoaderClass shared].displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
#endif
}

@end


