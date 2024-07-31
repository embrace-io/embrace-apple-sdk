//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
    

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLSessionTask (Embrace)

- (BOOL)injectHeaderWithKey:(NSString *)key value:(NSString *)value;

@end

NS_ASSUME_NONNULL_END
