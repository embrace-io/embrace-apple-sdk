//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EMBURLSessionDelegateProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface EMBURLSessionNewDelegateProxy : NSObject <EMBURLSessionDelegateProxy>

@property(nonatomic, strong, nullable) id originalDelegate;
@property(nonatomic, weak, nullable) id<NSURLSessionDelegate> swizzledDelegate;
@property(nonatomic, strong, nullable) id<URLSessionTaskHandler> handler;

@end

NS_ASSUME_NONNULL_END
