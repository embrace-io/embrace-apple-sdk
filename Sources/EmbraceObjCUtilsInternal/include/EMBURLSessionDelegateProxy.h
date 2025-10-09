//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol URLSessionTaskHandler <NSObject>

- (BOOL)createWithTask:(NSURLSessionTask *)task NS_SWIFT_NAME(create(task:));
- (void)finishWithTask:(NSURLSessionTask *)task
                  data:(nullable NSData *)data
                 error:(nullable NSError *)error NS_SWIFT_NAME(finish(task:data:error:));
- (void)finishWithTask:(NSURLSessionTask *)task
              bodySize:(NSInteger)bodySize
                 error:(nullable NSError *)error NS_SWIFT_NAME(finish(task:bodySize:error:));
- (void)addData:(NSData *)data dataTask:(NSURLSessionDataTask *)dataTask NS_SWIFT_NAME(addData(_:dataTask:));

@end

@interface EMBURLSessionDelegateProxy
    : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionStreamDelegate>

@property(nonatomic, strong, nullable) id originalDelegate;

/// This helps to determine if, during the creation of the `URLSessionDelegateProxy`,
/// another player or SDK has already swizzled or proxied NSURLSession/URLSession.
@property(nonatomic, weak, nullable) id<NSURLSessionDelegate> swizzledDelegate;

@property(nonatomic, strong, nullable) id<URLSessionTaskHandler> handler;

- (instancetype)initWithDelegate:(id<NSURLSessionDelegate> _Nullable)delegate
                         handler:(id<URLSessionTaskHandler>)handler;

- (id)getTargetForSelector:(SEL)sel session:(NSURLSession *)session;

@end

// Uses NSInvocation from swift to call into target.
// Returns YES on success.
FOUNDATION_EXPORT BOOL EmbraceInvoke(id target, SEL aSelector, NSArray<id> *arguments);

NS_ASSUME_NONNULL_END
