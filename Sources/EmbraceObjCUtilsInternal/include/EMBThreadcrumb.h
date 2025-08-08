//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(EmbraceThreadcrumb)
@interface EMBThreadcrumb : NSObject

// Log a message and return the addresses created in the stack.
- (NSArray<NSNumber *> *)log:(NSString *)message;

@end

NS_ASSUME_NONNULL_END

