//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBURLSessionDelegateProxy.h"
#import <Foundation/Foundation.h>
#import "objc/runtime.h"

@implementation EMBURLSessionDelegateProxy

- (instancetype)initWithDelegate:(id<NSURLSessionDelegate>)delegate handler:(id<URLSessionTaskHandler>)handler
{
    self = [super init];
    if (self) {
        _originalDelegate = delegate;
        _handler = handler;
    }
    return self;
}

#pragma mark - Firebase SWizzling Fixer

/*
 Keep this here as it helps debug issues when they occur.
+ (BOOL)instancesRespondToSelector:(SEL)aSelector
{
    static EMBURLSessionDelegateProxy *sFakeProxy;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sFakeProxy = [[EMBURLSessionDelegateProxy alloc] initWithDelegate:nil handler:nil];
    });
    return [sFakeProxy respondsToSelector:aSelector];
}
 */

// Firebase checks for the presence of this function in order to 'isa' swizzle.
// If it's here, it simply returns and does not do any swizzling.
// We want this because Firebase 'isa' swizzling isn't being a good citizen.
// ref: https://tinyurl.com/293k3hw9
- (Class)gul_class
{
    return nil;
}

#pragma mark - Forwarding plumbing

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [[self forwardingTargetForSelector:aSelector] methodSignatureForSelector:aSelector];
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
    // Any selector we don't implement, pass through transparently.
    if ([self.originalDelegate respondsToSelector:sel]) {
        return self.originalDelegate;
    }
    return [super forwardingTargetForSelector:sel];
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

BOOL EmbraceInvoke(id target, SEL aSelector, NSArray *arguments)
{
    NSMethodSignature *sig = [target methodSignatureForSelector:aSelector];
    if (!sig) {
        return NO;
    }

    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.selector = aSelector;
    inv.target = target;

    for (NSUInteger index = 0, argIndex = 2; index < arguments.count; index++, argIndex++) {
        id arg = arguments[index];
        [inv setArgument:&arg atIndex:argIndex];
    }

    [inv invoke];

    return YES;
}
