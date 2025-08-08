//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBDisplayLinkProxy.h"
#import "EMBStartupTracker.h"

#if !TARGET_OS_WATCH
#import <QuartzCore/QuartzCore.h>
#endif

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

API_AVAILABLE(ios(3.1), tvos(9.0), macos(14.0))
API_UNAVAILABLE(watchos)
@implementation EMBDisplayLinkProxy {
#if !TARGET_OS_WATCH
    CADisplayLink *_link;
    dispatch_block_t _nextRenderBlock;
#endif
}

+ (instancetype)shared
{
    static EMBDisplayLinkProxy *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[EMBDisplayLinkProxy alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
#if !TARGET_OS_WATCH
        _nextRenderBlock = NULL;
#if TARGET_OS_OSX
        _link = [NSScreen.mainScreen displayLinkWithTarget:self selector:@selector(_tick)];
#else
        _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(_tick)];
#endif
        [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        _link.paused = YES;
#endif
    }
    return self;
}

- (void)dealloc
{
#if !TARGET_OS_WATCH
    [_link invalidate];
#endif
}

- (void)trackNextTick:(dispatch_block_t)block
{
#if !TARGET_OS_WATCH
    assert(NSThread.isMainThread);
    _nextRenderBlock = [block copy];
    _link.paused = NO;
#endif
}

- (void)_tick
{
#if !TARGET_OS_WATCH
    assert(NSThread.isMainThread);
    dispatch_block_t block = [_nextRenderBlock copy];
    _nextRenderBlock = NULL;
    if (block) {
        _link.paused = YES;
        block();
    }
#endif
}

@end
