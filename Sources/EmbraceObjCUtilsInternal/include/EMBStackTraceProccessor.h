//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
    

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMBStackTraceProccessor : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (NSArray<NSDictionary<NSString *, id> *> *)processStackTrace:(NSArray<NSString *> *)rawStackTrace;

@end

NS_ASSUME_NONNULL_END
