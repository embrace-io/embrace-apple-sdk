//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMBRURLSessionTaskHeaderInjector : NSObject

+ (BOOL)injectHeaderWithKey:(NSString *)key value:(NSString *)value intoTask:(NSURLSessionTask *)task;

@end

NS_ASSUME_NONNULL_END
