//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMBDisplayLinkProxy : NSObject

+ (instancetype)shared;
- (void)onFrameUpdate;

@end

NS_ASSUME_NONNULL_END
