//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#import "InternalConsistency.h"

@implementation InternalConsistency

- (NSString *)category { return @"Exceptions"; }
- (NSString *)title { return @"Throw Objective-C NSInternalConsistency Exception"; }
- (NSString *)desc { return @"Throw an uncaught Objective-C NSInternalConsistency exception."; }

- (void)crash __attribute__((noreturn))
{
    @throw NSInternalInconsistencyException;
}

@end
