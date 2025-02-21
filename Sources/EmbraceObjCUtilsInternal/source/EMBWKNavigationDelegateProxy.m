//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if __has_include(<WebKit/WebKit.h>)
#import "EMBWKNavigationDelegateProxy.h"
#import "objc/runtime.h"

#define DID_FAIL_NAVIGATION @selector(webView:didFailNavigation:withError:)
#define DID_FAIL_PROVISIONAL_NAVIGATION @selector(webView:didFailProvisionalNavigation:withError:)
#define DECIDE_POLICY_FOR_NAVIGATION @selector(webView:decidePolicyForNavigationResponse:decisionHandler:)

@interface EMBWKNavigationDelegateProxy ()

@end

@implementation EMBWKNavigationDelegateProxy

- (instancetype)initWithOriginalDelegate:(id<WKNavigationDelegate>)originalDelegate
                                callback:(void (^ _Nullable)(NSURL * _Nullable, NSInteger))callback {
    _originalDelegate = originalDelegate;
    _callback = [callback copy];
    return self;
}

#pragma mark - Forwarding Methods

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (sel_isEqual(aSelector, DID_FAIL_NAVIGATION) ||
        sel_isEqual(aSelector, DID_FAIL_PROVISIONAL_NAVIGATION) ||
        sel_isEqual(aSelector, DECIDE_POLICY_FOR_NAVIGATION)) {
        return YES;
    }
    return [self.originalDelegate respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return self.originalDelegate;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [(NSObject *)self.originalDelegate methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:self.originalDelegate];
}

- (BOOL)isKindOfClass:(Class)aClass
{
    return aClass == [EMBWKNavigationDelegateProxy class];
}

- (BOOL)isMemberOfClass:(Class)aClass
{
    return aClass == [EMBWKNavigationDelegateProxy class];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView
decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse
decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    NSInteger statusCode = 0;
    if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {
        statusCode = [(NSHTTPURLResponse *)navigationResponse.response statusCode];
    }
    if (self.callback) {
        self.callback(webView.URL, statusCode);
    }

    if ([self.originalDelegate respondsToSelector:DECIDE_POLICY_FOR_NAVIGATION]) {
        [self.originalDelegate webView:webView decidePolicyForNavigationResponse:navigationResponse decisionHandler:decisionHandler];
    } else {
        decisionHandler(WKNavigationResponsePolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView
didFailProvisionalNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    if (self.callback) {
        self.callback(webView.URL, error.code);
    }

    if ([self.originalDelegate respondsToSelector:DID_FAIL_PROVISIONAL_NAVIGATION]) {
        [self.originalDelegate webView:webView didFailProvisionalNavigation:navigation withError:error];
    }
}

- (void)webView:(WKWebView *)webView
didFailNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    if (self.callback) {
        self.callback(webView.URL, error.code);
    }

    if ([self.originalDelegate respondsToSelector:DID_FAIL_NAVIGATION]) {
        [self.originalDelegate webView:webView didFailNavigation:navigation withError:error];
    }
}

@end
#endif
