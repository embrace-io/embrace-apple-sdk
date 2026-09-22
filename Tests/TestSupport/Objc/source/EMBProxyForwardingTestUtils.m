//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#import "EMBProxyForwardingTestUtils.h"
#import "EMBURLSessionDelegateProtocol.h"

@implementation WebSocketImplementingURLSessionDelegate

- (void)URLSession:(NSURLSession *)session
       webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask
    didCloseWithCode:(NSURLSessionWebSocketCloseCode)closeCode
              reason:(nullable NSData *)reason
{
    self.didInvokeDidCloseWithCode = YES;
}

@end

void EMBClearOriginalDelegate(id proxy) { [(id<EMBURLSessionDelegateProxyType>)proxy setOriginalDelegate:nil]; }

void EMBRawInvoke(id target, SEL selector, Class signatureSource, NSArray *arguments)
{
    NSMethodSignature *sig = [signatureSource instanceMethodSignatureForSelector:selector];
    NSCAssert(sig != nil, @"signatureSource must implement %@", NSStringFromSelector(selector));

    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.selector = selector;
    inv.target = target;

    // Arguments start at index 2 (self, _cmd occupy 0 and 1). Scalar parameters are copied
    // by value from the boxed object's pointer bits; the reproduced callbacks never read them.
    for (NSUInteger index = 0, argIndex = 2; index < arguments.count; index++, argIndex++) {
        id arg = arguments[index];
        [inv setArgument:&arg atIndex:argIndex];
    }

    [inv invoke];  // raw send to `target` — exercises the proxy's forwarding path
}
