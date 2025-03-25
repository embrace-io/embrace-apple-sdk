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
    if ([self.originalDelegate respondsToSelector:aSelector]) {
        return self.originalDelegate;
    }

    return nil;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    if ([self.originalDelegate respondsToSelector:selector]) {
        return [(NSObject *)self.originalDelegate methodSignatureForSelector:selector];
    }

    return nil;
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

#pragma mark - Noop implementations for safety

- (void)webView:(WKWebView *)webView
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {

    if ([self.originalDelegate respondsToSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)]) {
        [self.originalDelegate webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView 
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
    preferences:(WKWebpagePreferences *)preferences
decisionHandler:(void (^)(WKNavigationActionPolicy, WKWebpagePreferences *))decisionHandler {

    if ([self.originalDelegate respondsToSelector:@selector(webView:decidePolicyForNavigationAction:preferences:decisionHandler:)]) {
        [self.originalDelegate webView:webView
       decidePolicyForNavigationAction:navigationAction
                           preferences:preferences
                       decisionHandler:decisionHandler];

    // since implementing this method means `webView:decidePolicyForNavigationAction:decisionHandler:`
    // will never be called
    // we need to manually check if the original delegate had this implementation and manually forward it
    } else if ([self.originalDelegate respondsToSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)]) {
        [self.originalDelegate webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:^(WKNavigationActionPolicy policy) {
            decisionHandler(policy, preferences);
        }];
    } else {
        decisionHandler(WKNavigationActionPolicyAllow, preferences);
    }
}

- (void)webView:(WKWebView *)webView 
didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {

    if ([self.originalDelegate respondsToSelector:@selector(webView:didStartProvisionalNavigation:)]) {
        [self.originalDelegate webView:webView didStartProvisionalNavigation:navigation];
    }
}

- (void)webView:(WKWebView *)webView 
didReceiveServerRedirectForProvisionalNavigation:(null_unspecified WKNavigation *)navigation {

    if ([self.originalDelegate respondsToSelector:@selector(webView:didReceiveServerRedirectForProvisionalNavigation:)]) {
        [self.originalDelegate webView:webView didReceiveServerRedirectForProvisionalNavigation:navigation];
    }
}

- (void)webView:(WKWebView *)webView 
didCommitNavigation:(null_unspecified WKNavigation *)navigation {

    if ([self.originalDelegate respondsToSelector:@selector(webView:didCommitNavigation:)]) {
        [self.originalDelegate webView:webView didCommitNavigation:navigation];
    }
}

- (void)webView:(WKWebView *)webView 
didFinishNavigation:(null_unspecified WKNavigation *)navigation {

    if ([self.originalDelegate respondsToSelector:@selector((webView:didFinishNavigation:))]) {
        [self.originalDelegate webView:webView didFinishNavigation:navigation];
    }
}

- (void)webView:(WKWebView *)webView
didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {

    if ([self.originalDelegate respondsToSelector:@selector(webView:didReceiveAuthenticationChallenge:completionHandler:)]) {
        [self.originalDelegate webView:webView didReceiveAuthenticationChallenge:challenge completionHandler:completionHandler];
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {

    if ([self.originalDelegate respondsToSelector:@selector(webViewWebContentProcessDidTerminate:)]) {
        [self.originalDelegate webViewWebContentProcessDidTerminate:webView];
    }
}

- (void)webView:(WKWebView *)webView
authenticationChallenge:(NSURLAuthenticationChallenge *)challenge
shouldAllowDeprecatedTLS:(void (^)(BOOL))decisionHandler API_AVAILABLE(macos(11.0), ios(14.0)) {

    if ([self.originalDelegate respondsToSelector:@selector((webView:authenticationChallenge:shouldAllowDeprecatedTLS:))]) {
        [self.originalDelegate webView:webView authenticationChallenge:challenge shouldAllowDeprecatedTLS:decisionHandler];
    } else {
        decisionHandler(NO);
    }
}

- (void)webView:(WKWebView *)webView 
navigationAction:(WKNavigationAction *)navigationAction
didBecomeDownload:(WKDownload *)download API_AVAILABLE(macos(11.3), ios(14.5)) {

    if ([self.originalDelegate respondsToSelector:@selector(webView:navigationAction:didBecomeDownload:)]) {
        [self.originalDelegate webView:webView navigationAction:navigationAction didBecomeDownload:download];
    }
}

- (void)webView:(WKWebView *)webView 
navigationResponse:(WKNavigationResponse *)navigationResponse
didBecomeDownload:(WKDownload *)download API_AVAILABLE(macos(11.3), ios(14.5)) {

    if ([self.originalDelegate respondsToSelector:@selector(webView:navigationResponse:didBecomeDownload:)]) {
        [self.originalDelegate webView:webView navigationResponse:navigationResponse didBecomeDownload:download];
    }
}

@end
#endif
