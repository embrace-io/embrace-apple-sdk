//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EMBURLSessionDelegateProtocol.h"

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

@protocol EMBURLSessionDelegateProxy <NSObject,
                                      NSURLSessionDelegate,
                                      NSURLSessionTaskDelegate,
                                      NSURLSessionDataDelegate,
                                      NSURLSessionStreamDelegate>

@property(nonatomic, strong, nullable) id originalDelegate;

@property(nonatomic, weak, nullable) id<NSURLSessionDelegate> swizzledDelegate;

@property(nonatomic, strong, nullable) id<URLSessionTaskHandler> handler;

- (instancetype)initWithDelegate:(id<NSURLSessionDelegate> _Nullable)delegate
                         handler:(id<URLSessionTaskHandler>)handler;

- (id)getTargetForSelector:(SEL)sel session:(NSURLSession *)session;

@end

// Uses NSInvocation from swift to call into target.
// Returns YES on success.
FOUNDATION_EXPORT BOOL EmbraceInvoke(id target, SEL aSelector, NSArray<id> *arguments);

FOUNDATION_EXPORT id<EMBURLSessionDelegateProxy> EmbraceMakeURLSessionDelegateProxy(
    id<NSURLSessionDelegate> _Nullable delegate, id<URLSessionTaskHandler> handler);

NS_ASSUME_NONNULL_END
