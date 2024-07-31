//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
    

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMBBinaryImageProvider : NSObject

- (void)binaryImageForAddress:(uintptr_t)ptr completion:(void (^)(NSString *path, NSString *uuid, NSNumber *baseAddress))completion;

@end

NS_ASSUME_NONNULL_END
