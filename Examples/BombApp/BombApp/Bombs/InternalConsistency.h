//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CRLCrash.h"

NS_ASSUME_NONNULL_BEGIN

@interface InternalConsistency : CRLCrash

- (void)crash __attribute__((noreturn));

@end

NS_ASSUME_NONNULL_END
