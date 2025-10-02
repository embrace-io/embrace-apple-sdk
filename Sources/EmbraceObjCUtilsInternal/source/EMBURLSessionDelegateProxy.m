//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBURLSessionDelegateProxy.h"
#import <Foundation/Foundation.h>
#import "EMBURLSessionDelegateProxyFunctions.h"
#import "objc/runtime.h"

#define DID_FINISH_COLLECTING_METRICS @selector(URLSession:task:didFinishCollectingMetrics:)
#define DID_RECEIVE_DATA_SELECTOR @selector(URLSession:dataTask:didReceiveData:)
#define DID_FINISH_DOWNLOADING @selector(URLSession:downloadTask:didFinishDownloadingToURL:)
#define DID_COMPLETE_WITH_ERROR @selector(URLSession:task:didCompleteWithError:)
#define DID_BECOME_INVALID_WITH_ERROR @selector(URLSession:didBecomeInvalidWithError:)
#define DID_RECEIVE_RESPONSE @selector(URLSession:dataTask:didReceiveResponse:completionHandler:)

@interface EMBURLSessionDelegateProxy ()

@end

@implementation EMBURLSessionDelegateProxy

- (instancetype)initWithDelegate:(id<NSURLSessionDelegate>)delegate handler:(id<URLSessionTaskHandler>)handler
{
    _originalDelegate = delegate;
    _handler = handler;
    return self;
}

#pragma mark - Forwarding Methods

- (BOOL)respondsToSelector:(SEL)aSelector
{
    if (sel_isEqual(aSelector, DID_RECEIVE_RESPONSE)) {
        return YES;
    }

    if (sel_isEqual(aSelector, DID_RECEIVE_DATA_SELECTOR)) {
        return [self.originalDelegate respondsToSelector:aSelector];
    }

    if (sel_isEqual(aSelector, DID_FINISH_DOWNLOADING)) {
        return [self.originalDelegate respondsToSelector:aSelector];
    }

    if (sel_isEqual(aSelector, DID_FINISH_COLLECTING_METRICS) || sel_isEqual(aSelector, DID_COMPLETE_WITH_ERROR) ||
        sel_isEqual(aSelector, DID_BECOME_INVALID_WITH_ERROR)) {
        return YES;
    }

    return [self.originalDelegate respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    return self.originalDelegate;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    return [(NSObject *)self.originalDelegate methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    [invocation invokeWithTarget:self.originalDelegate];
}

- (BOOL)isKindOfClass:(Class)aClass
{
    return aClass == [EMBURLSessionDelegateProxy class];
}

- (BOOL)isMemberOfClass:(Class)aClass
{
    return aClass == [EMBURLSessionDelegateProxy class];
}

#pragma mark - NSURLSessionDelegate Methods

- (id)getTargetForSelector:(SEL)selector session:(NSURLSession *)session
{
    // check if the originalDelegate responds to the selector
    if ((self.originalDelegate) && ([self.originalDelegate respondsToSelector:selector])) {
        return self.originalDelegate;
    }

    // check that we are not the `session.delegate` to prevent infinite recursion
    if ([session.delegate isEqual:self]) {
        return nil;
    }

    // avoid forwarding the delegate if it was already swizzled by somebody else
    // during our swizzling to prevent potential infinite recursion.
    if (self.swizzledDelegate) {
        return nil;
    }

    // if session delegate also responds to selector, we must call it
    if ((session.delegate) && ([session.delegate respondsToSelector:selector])) {
        return session.delegate;
    }

    // If no case applies
    return nil;
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    if ([self.originalDelegate respondsToSelector:@selector(URLSession:didBecomeInvalidWithError:)]) {
        [self.originalDelegate URLSession:session didBecomeInvalidWithError:error];
    }
}

#pragma mark - NSURLSessionTaskDelegate Methods

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    [self.handler finishWithTask:task data:nil error:error];
    id target = [self getTargetForSelector:DID_COMPLETE_WITH_ERROR session:session];

    if (target) {
        [(id<NSURLSessionTaskDelegate>)target URLSession:session task:task didCompleteWithError:error];
    }
}

- (void)URLSession:(NSURLSession *)session
                          task:(NSURLSessionTask *)task
    didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
{
    NSInteger totalBytes = 0;
    for (NSURLSessionTaskTransactionMetrics *transaction in metrics.transactionMetrics) {
        totalBytes += transaction.countOfResponseBodyBytesReceived;
    }

    [self.handler finishWithTask:task bodySize:totalBytes error:nil];

    id target = [self getTargetForSelector:DID_FINISH_COLLECTING_METRICS session:session];

    if (target) {
        [(id<NSURLSessionTaskDelegate>)target URLSession:session task:task didFinishCollectingMetrics:metrics];
    }
}

#pragma mark - NSURLSessionDataDelegate Methods

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [self.handler addData:data dataTask:dataTask];
    id target = [self getTargetForSelector:DID_RECEIVE_DATA_SELECTOR session:session];

    if (target) {
        [(id<NSURLSessionDataDelegate>)target URLSession:session dataTask:dataTask didReceiveData:data];
    }
}

- (void)URLSession:(NSURLSession *)session
              dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    id target = [self getTargetForSelector:DID_RECEIVE_RESPONSE session:session];

    if (target) {
        [(id<NSURLSessionDataDelegate>)target URLSession:session
                                                dataTask:dataTask
                                      didReceiveResponse:response
                                       completionHandler:completionHandler];
    } else {
        completionHandler(NSURLSessionResponseAllow);
    }
}

#pragma mark - NSURLSessionDownloadDelegate Methods

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location
{
    id target = [self getTargetForSelector:DID_FINISH_DOWNLOADING session:session];

    if (target) {
        [(id<NSURLSessionDownloadDelegate>)target URLSession:session
                                                downloadTask:downloadTask
                                   didFinishDownloadingToURL:location];
    }
}

#pragma mark - NSURLSessionStreamDelegate (Empty Implementation)

@end
