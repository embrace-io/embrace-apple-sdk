//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(macos(14.0))
@interface EMBDisplayLinkProxy : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)shared;

// Call to get called on the next tick of the display link.
- (void)trackNextTick:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
