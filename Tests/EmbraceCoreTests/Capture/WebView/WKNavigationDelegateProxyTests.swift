//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
@testable import EmbraceCore
import WebKit
import XCTest

@available(iOS 14.5, *)
class WKNavigationDelegateProxyTests: XCTestCase {

    // had to retain these because the test crashes when deallocating instances of these classes
    let navigation = WKNavigation()
    let download = WKDownload()

    func test_forwarding() {
        // given a proxy with an original delegate
        let originalDelegate = MockWKNavigationDelegate()
        let proxy = WKNavigationDelegateProxy()
        proxy.originalDelegate = originalDelegate

        // when calls are made to the proxy
        let webView = WKWebView()
        let error = NSError(domain: "com.embrace.test", code: 0)
        let block: (WKNavigationResponsePolicy) -> Void = { _ in }
        let block1: (WKNavigationActionPolicy) -> Void = { _ in }
        let block2: (WKNavigationActionPolicy, WKWebpagePreferences) -> Void = { _, _ in }
        let block3: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void = { _, _ in }
        let block4: (Bool) -> Void = { _ in }

        proxy.webView(webView, decidePolicyFor: WKNavigationResponse(), decisionHandler: block)
        proxy.webView(webView, didFailProvisionalNavigation: navigation, withError: error)
        proxy.webView(webView, didFail: navigation, withError: error)
        proxy.webView(webView, decidePolicyFor: WKNavigationAction(), decisionHandler: block1)
        proxy.webView(
            webView,
            decidePolicyFor: WKNavigationAction(),
            preferences: WKWebpagePreferences(),
            decisionHandler: block2
        )
        proxy.webView(webView, didStartProvisionalNavigation: navigation)
        proxy.webView(webView, didReceiveServerRedirectForProvisionalNavigation: navigation)
        proxy.webView(webView, didCommit: navigation)
        proxy.webView(webView, didFinish: navigation)
        proxy.webView(webView, didReceive: URLAuthenticationChallenge(), completionHandler: block3)
        proxy.webViewWebContentProcessDidTerminate(webView)
        proxy.webView(webView, authenticationChallenge: URLAuthenticationChallenge(), shouldAllowDeprecatedTLS: block4)
        proxy.webView(webView, navigationAction: WKNavigationAction(), didBecome: download)
        proxy.webView(webView, navigationResponse: WKNavigationResponse(), didBecome: download)

        // then the delegate calls are forwarded
        XCTAssertEqual(originalDelegate.callCount, 14)
    }

    func test_callback() {
        // given a proxy with a callback
        let proxy = WKNavigationDelegateProxy()

        var callCount: Int = 0
        proxy.callback = { _, _ in
            callCount += 1
        }

        // when calls are made to the proxy
        let webView = WKWebView()
        let block: (WKNavigationResponsePolicy) -> Void = { _ in }
        let error = NSError(domain: "com.embrace.test", code: 0)

        proxy.webView(webView, decidePolicyFor: WKNavigationResponse(), decisionHandler: block)
        proxy.webView(webView, didFailProvisionalNavigation: navigation, withError: error)
        proxy.webView(webView, didFail: navigation, withError: error)

        // then the callback is called
        XCTAssertEqual(callCount, 3)
    }
}
#endif
