//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBURLSessionDelegateProtocol.h"
#import <Foundation/Foundation.h>
#import "objc/runtime.h"

#import "LegacyProxy/EMBURLSessionLegacyDelegateProxy.h"
#import "NewProxy/EMBURLSessionNewDelegateProxy.h"

BOOL EmbraceInvoke(id target, SEL aSelector, NSArray *arguments)
{
    NSMethodSignature *sig = [target methodSignatureForSelector:aSelector];
    if (!sig) {
        return NO;
    }
    if (![target respondsToSelector:aSelector]) {
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

static NSString *const EMBUseLegacyURLSessionProxyKey = @"EMBUseLegacyURLSessionProxy";
id<EMBURLSessionDelegateProxy> EmbraceMakeURLSessionDelegateProxy(id<NSURLSessionDelegate> _Nullable delegate,
                                                                  id<URLSessionTaskHandler> handler)
{
    static BOOL sUseLegacyProxy;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sUseLegacyProxy = [[NSUserDefaults standardUserDefaults] boolForKey:EMBUseLegacyURLSessionProxyKey];
    });

    if (sUseLegacyProxy) {
        return [[EMBURLSessionLegacyDelegateProxy alloc] initWithDelegate:delegate handler:handler];
    }
    return [[EMBURLSessionNewDelegateProxy alloc] initWithDelegate:delegate handler:handler];
}
