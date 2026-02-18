//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMBLoaderClass : NSObject
@end

FOUNDATION_EXPORT pthread_t EmbraceGetMainThread(void);

@class NSManagedObjectContext;
FOUNDATION_EXPORT NSError *_Nullable EmbraceSaveManagedContext(NSManagedObjectContext *context);

NS_ASSUME_NONNULL_END
