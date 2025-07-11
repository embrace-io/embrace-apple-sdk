//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMBLoaderClass : NSObject

@property CADisplayLink *displayLink;
+ (EMBLoaderClass *)shared;
#if TARGET_OS_MAC
- (void)onAppDidFinishLaunching:(NSNotification *)notification;
#endif
@end

NS_ASSUME_NONNULL_END
