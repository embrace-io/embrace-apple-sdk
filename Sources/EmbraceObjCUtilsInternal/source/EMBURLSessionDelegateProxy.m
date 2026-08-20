//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBURLSessionDelegateProxy.h"
#import <Foundation/Foundation.h>
#import "objc/runtime.h"

@implementation EMBURLSessionDelegateProxy {
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
    self = [super init];
    if (self) {
        _originalDelegate = delegate;
        _weakOriginalDelegate = delegate;
        _originalDelegateClass = [delegate class];
        _handler = handler;
    }
    return self;
}

#pragma mark - Forwarding plumbing

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    // Prefer the live delegate's own signature (strong first, then the weak backup in case
    // `originalDelegate` was released after invalidation while a callback was still in flight).
    id target = self.originalDelegate ?: _weakOriginalDelegate;
    if (target) {
        NSMethodSignature *sig = [target methodSignatureForSelector:aSelector];
        if (sig) {
            return sig;
        }
    }

    // The delegate instance is gone. Fall back to its remembered class so we can still
    // return a valid signature and drop the message in `-forwardInvocation:` rather than
    // falling through to `-doesNotRecognizeSelector:` and crashing.
    if (_originalDelegateClass) {
        NSMethodSignature *sig = [_originalDelegateClass instanceMethodSignatureForSelector:aSelector];
        if (sig) {
            return sig;
        }
    }

    return [super methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    // Reached only when `-forwardingTargetForSelector:` returns nil for the selector. If the
    // original delegate is still alive and handles the selector, deliver it; otherwise drop it.
    // This is the safety net for callbacks (such as a WebSocket close) delivered after the
    // session was invalidated and `originalDelegate` was released.
    //
    // Known limitation: if the dropped selector carries a `completionHandler` (e.g.
    // `URLSession:dataTask:willCacheResponse:completionHandler:`) the handler is never invoked,
    // which leaves that one task parked until it times out. This is only reachable if the app
    // both implemented such a method and fully deallocated its delegate before the callback
    // raced in post-invalidation — extremely narrow given URLSession delivers
    // `didBecomeInvalidWithError:` last and cancels/finishes tasks around invalidation. We
    // accept the drop rather than synthesizing per-selector default responses here.
    id target = self.originalDelegate ?: _weakOriginalDelegate;
    if (target && [target respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:target];
    }
}

- (id)getTargetForSelector:(SEL)sel session:(NSURLSession *)session
{
    return [self forwardingTargetForSelector:sel];
}

- (BOOL)respondsToSelector:(SEL)sel
{
    // Challenge selectors: only advertise YES if the original delegate handles them.
    // Unconditionally claiming YES changes the OS’s internal challenge handling path for
    // sessions created without a delegate (where originalDelegate is EmbraceDummyURLSessionDelegate),
    // which breaks tokenization and SSL-pinning SDKs that depend on the OS-native path.
    if (sel == @selector(URLSession:didReceiveChallenge:completionHandler:) ||
        sel == @selector(URLSession:task:didReceiveChallenge:completionHandler:)) {
        return [self.originalDelegate respondsToSelector:sel];
    }
    // For all other directly-implemented methods, advertise YES unconditionally.
    if ([super respondsToSelector:sel]) {
        return YES;
    }
    // Otherwise mirror the original delegate’s capabilities.
    return [self.originalDelegate respondsToSelector:sel];
}

- (id)forwardingTargetForSelector:(SEL)sel
{
    // We can't call `-respondsToSelector:` from here.
    if (sel == @selector(URLSession:task:didCompleteWithError:) ||
        sel == @selector(URLSession:task:didFinishCollectingMetrics:) ||
        sel == @selector(URLSession:dataTask:didReceiveData:) ||
        sel == @selector(URLSession:didBecomeInvalidWithError:) ||
        sel == @selector(URLSession:didReceiveChallenge:completionHandler:) ||
        sel == @selector(URLSession:task:didReceiveChallenge:completionHandler:) ||
        sel == @selector(URLSession:dataTask:didReceiveResponse:completionHandler:) ||
        sel == @selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:) ||
        sel == @selector(URLSession:downloadTask:didFinishDownloadingToURL:)) {
        return nil;
    }

    id forwardingTarget = nil;

    forwardingTarget = [super forwardingTargetForSelector:sel];
    if (forwardingTarget) {
        return forwardingTarget == self ? nil : forwardingTarget;
    }

    // is the original doing any forwarding?
    forwardingTarget = [self.originalDelegate forwardingTargetForSelector:sel];
    if (forwardingTarget) {
        return forwardingTarget;
    }

    if ([self.originalDelegate respondsToSelector:sel]) {
        return self.originalDelegate;
    }

    return nil;
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
    return [super conformsToProtocol:aProtocol] || [self.originalDelegate conformsToProtocol:aProtocol];
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    if ([self.originalDelegate respondsToSelector:@selector(URLSession:didBecomeInvalidWithError:)]) {
        [(id<NSURLSessionDelegate>)self.originalDelegate URLSession:session didBecomeInvalidWithError:error];
    }
    self.originalDelegate = nil;
    self.handler = nil;
}

- (void)URLSession:(NSURLSession *)session
    didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
      completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    id delegate = self.originalDelegate;
    if (delegate && [delegate respondsToSelector:@selector(URLSession:didReceiveChallenge:completionHandler:)]) {
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
    if (delegate && [delegate respondsToSelector:@selector(URLSession:task:didReceiveChallenge:completionHandler:)]) {
        [(id<NSURLSessionTaskDelegate>)delegate URLSession:session
                                                      task:task
                                       didReceiveChallenge:challenge
                                         completionHandler:completionHandler];
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    [self.handler finishWithTask:task data:nil error:error];

    if ([self.originalDelegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [(id<NSURLSessionTaskDelegate>)self.originalDelegate URLSession:session task:task didCompleteWithError:error];
    }
}

- (void)URLSession:(NSURLSession *)session
                          task:(NSURLSessionTask *)task
    didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
{
    int64_t totalBytes = 0;
    for (NSURLSessionTaskTransactionMetrics *t in metrics.transactionMetrics) {
        totalBytes += t.countOfResponseBodyBytesReceived;
    }
    [self.handler finishWithTask:task bodySize:totalBytes error:nil];

    if ([self.originalDelegate respondsToSelector:@selector(URLSession:task:didFinishCollectingMetrics:)]) {
        [(id<NSURLSessionTaskDelegate>)self.originalDelegate URLSession:session
                                                                   task:task
                                             didFinishCollectingMetrics:metrics];
    }
}

#pragma mark - NSURLSessionTaskDelegate (redirection)

- (void)URLSession:(NSURLSession *)session
                          task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                    newRequest:(NSURLRequest *)request
             completionHandler:(void (^)(NSURLRequest *))completionHandler
{
    id delegate = self.originalDelegate;
    if (delegate && [delegate respondsToSelector:@selector
                              (URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)]) {
        [(id<NSURLSessionTaskDelegate>)delegate URLSession:session
                                                      task:task
                                willPerformHTTPRedirection:response
                                                newRequest:request
                                         completionHandler:completionHandler];
    } else {
        completionHandler(request);  // follow the redirect — URLSession's built-in default
    }
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [self.handler addData:data dataTask:dataTask];

    if ([self.originalDelegate respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [(id<NSURLSessionDataDelegate>)self.originalDelegate URLSession:session dataTask:dataTask didReceiveData:data];
    }
}

- (void)URLSession:(NSURLSession *)session
              dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    id delegate = self.originalDelegate;
    if (delegate && [delegate respondsToSelector:@selector(URLSession:
                                                             dataTask:didReceiveResponse:completionHandler:)]) {
        [(id<NSURLSessionDataDelegate>)delegate URLSession:session
                                                  dataTask:dataTask
                                        didReceiveResponse:response
                                         completionHandler:completionHandler];
    } else {
        completionHandler(NSURLSessionResponseAllow);
    }
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location
{
    id delegate = self.originalDelegate;
    if (delegate && [delegate respondsToSelector:@selector(URLSession:downloadTask:didFinishDownloadingToURL:)]) {
        [(id<NSURLSessionDownloadDelegate>)delegate URLSession:session
                                                  downloadTask:downloadTask
                                     didFinishDownloadingToURL:location];
    }
}

@end
