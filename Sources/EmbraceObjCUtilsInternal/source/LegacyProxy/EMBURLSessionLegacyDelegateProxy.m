//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBURLSessionLegacyDelegateProxy.h"
#import <Foundation/Foundation.h>
#import "EMBURLSessionLegacyDelegateProxyFunctions.h"
#import "objc/runtime.h"

#define DID_FINISH_COLLECTING_METRICS @selector(URLSession:task:didFinishCollectingMetrics:)
#define DID_RECEIVE_DATA_SELECTOR @selector(URLSession:dataTask:didReceiveData:)
#define DID_FINISH_DOWNLOADING @selector(URLSession:downloadTask:didFinishDownloadingToURL:)
#define DID_COMPLETE_WITH_ERROR @selector(URLSession:task:didCompleteWithError:)
#define DID_BECOME_INVALID_WITH_ERROR @selector(URLSession:didBecomeInvalidWithError:)
#define DID_RECEIVE_RESPONSE @selector(URLSession:dataTask:didReceiveResponse:completionHandler:)
#define WILL_PERFORM_REDIRECTION @selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)
#define DID_RECEIVE_CHALLENGE @selector(URLSession:didReceiveChallenge:completionHandler:)
#define DID_RECEIVE_TASK_CHALLENGE @selector(URLSession:task:didReceiveChallenge:completionHandler:)

@interface EMBURLSessionLegacyDelegateProxy ()

@end

@implementation EMBURLSessionLegacyDelegateProxy {
    // Backups of the original delegate that survive `originalDelegate` being cleared.
    //
    // `originalDelegate` is a strong reference we intentionally release on session
    // invalidation (see `-URLSession:didBecomeInvalidWithError:`) to break the
    // `session -> proxy -> delegate` retain chain: URLSession strongly retains its delegate
    // (this proxy) until invalidation, so without this the delegate would be pinned for the
    // session's entire lifetime. But URLSession/CFNetwork snapshots
    // the delegate's responds-to-selector set when the session is created and later
    // delivers callbacks *raw* (without re-checking `-respondsToSelector:`). A callback
    // that arrives after invalidation — e.g. a WebSocket close still in flight — would
    // otherwise reach the forwarding path with `originalDelegate == nil` and crash with
    // an unrecognized selector. These let us still forward to the delegate if it is alive
    // (`_weakOriginalDelegate`), and always produce a valid method signature so the message
    // can be dropped gracefully in `-forwardInvocation:` (`_originalDelegateClass`).
    __weak id _weakOriginalDelegate;
    Class _originalDelegateClass;
}

- (instancetype)initWithDelegate:(id<NSURLSessionDelegate>)delegate handler:(id<URLSessionTaskHandler>)handler
{
    _originalDelegate = delegate;
    _weakOriginalDelegate = delegate;
    _originalDelegateClass = [delegate class];
    _handler = handler;
    return self;
}

#pragma mark - Forwarding Methods

- (BOOL)respondsToSelector:(SEL)aSelector
{
    if (sel_isEqual(aSelector, DID_FINISH_COLLECTING_METRICS) || sel_isEqual(aSelector, DID_RECEIVE_DATA_SELECTOR) ||
        sel_isEqual(aSelector, DID_FINISH_DOWNLOADING) || sel_isEqual(aSelector, DID_COMPLETE_WITH_ERROR) ||
        sel_isEqual(aSelector, DID_BECOME_INVALID_WITH_ERROR) || sel_isEqual(aSelector, WILL_PERFORM_REDIRECTION)) {
        return YES;
    }
    return [self.originalDelegate respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if (self.originalDelegate && [self.originalDelegate respondsToSelector:aSelector]) {
        return self.originalDelegate;
    }
    return nil;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    // Prefer the live delegate's own signature (strong first, then the weak backup in case
    // `originalDelegate` was released after invalidation while a callback was still in flight).
    id target = self.originalDelegate ?: _weakOriginalDelegate;
    if (target) {
        NSMethodSignature *sig = [(NSObject *)target methodSignatureForSelector:selector];
        if (sig) {
            return sig;
        }
    }

    // The delegate instance is gone. Fall back to its remembered class so we can still return a
    // valid signature and drop the message in `-forwardInvocation:` rather than falling through
    // to `-doesNotRecognizeSelector:` and crashing. (This is an `NSProxy` subclass, so there is
    // no `[super methodSignatureForSelector:]` to safely fall back to — a nil result here yields
    // the same unrecognized-selector semantics as before for genuinely unknown selectors.)
    if (_originalDelegateClass) {
        return [_originalDelegateClass instanceMethodSignatureForSelector:selector];
    }

    return nil;
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    // If the original delegate is still alive and handles the selector, deliver it; otherwise
    // drop it. This is the safety net for callbacks (such as a WebSocket close) delivered after
    // the session was invalidated and `originalDelegate` was released.
    id target = self.originalDelegate ?: _weakOriginalDelegate;
    if (target && [target respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:target];
    }
}

- (BOOL)isKindOfClass:(Class)aClass
{
    return aClass == [EMBURLSessionLegacyDelegateProxy class];
}

- (BOOL)isMemberOfClass:(Class)aClass
{
    return aClass == [EMBURLSessionLegacyDelegateProxy class];
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

    self.originalDelegate = nil;
    self.handler = nil;
}

- (void)URLSession:(NSURLSession *)session
    didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
      completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    id delegate = self.originalDelegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        [(id<NSURLSessionDelegate>)delegate URLSession:session
                                   didReceiveChallenge:challenge
                                     completionHandler:completionHandler];
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)URLSession:(NSURLSession *)session
                   task:(NSURLSessionTask *)task
    didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
      completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    id delegate = self.originalDelegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        [(id<NSURLSessionTaskDelegate>)delegate URLSession:session
                                                      task:task
                                       didReceiveChallenge:challenge
                                         completionHandler:completionHandler];
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
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

- (void)URLSession:(NSURLSession *)session
                          task:(nonnull NSURLSessionTask *)task
    willPerformHTTPRedirection:(nonnull NSHTTPURLResponse *)response
                    newRequest:(nonnull NSURLRequest *)request
             completionHandler:(nonnull void (^)(NSURLRequest *_Nullable))completionHandler
{
    id target = [self getTargetForSelector:WILL_PERFORM_REDIRECTION session:session];

    if (target) {
        [(id<NSURLSessionTaskDelegate>)target URLSession:session
                                                    task:task
                              willPerformHTTPRedirection:response
                                              newRequest:request
                                       completionHandler:completionHandler];
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
