//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBURLSessionNewDelegateProxy.h"
#import <Foundation/Foundation.h>
#import "objc/runtime.h"

@implementation EMBURLSessionNewDelegateProxy

- (instancetype)initWithDelegate:(id<NSURLSessionDelegate>)delegate handler:(id<URLSessionTaskHandler>)handler
{
    self = [super init];
    if (self) {
        _originalDelegate = delegate;
        _handler = handler;
    }
    return self;
}

#pragma mark - Forwarding plumbing

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    id target = [self forwardingTargetForSelector:aSelector];
    if (target == nil) {
        return [super methodSignatureForSelector:aSelector];
    }
    return [target methodSignatureForSelector:aSelector];
}

- (id)getTargetForSelector:(SEL)sel session:(NSURLSession *)session
{
    return [self forwardingTargetForSelector:sel];
}

- (BOOL)respondsToSelector:(SEL)sel
{
    // If we implement it directly (instance methods below), advertise YES.
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
        sel == @selector(URLSession:dataTask:didReceiveData:)) {
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

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    [self.handler finishWithTask:task data:nil error:error];

    if ([self.originalDelegate respondsToSelector:_cmd]) {
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

    if ([self.originalDelegate respondsToSelector:_cmd]) {
        [(id<NSURLSessionTaskDelegate>)self.originalDelegate URLSession:session
                                                                   task:task
                                             didFinishCollectingMetrics:metrics];
    }
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [self.handler addData:data dataTask:dataTask];

    if ([self.originalDelegate respondsToSelector:_cmd]) {
        [(id<NSURLSessionDataDelegate>)self.originalDelegate URLSession:session dataTask:dataTask didReceiveData:data];
    }
}

@end
