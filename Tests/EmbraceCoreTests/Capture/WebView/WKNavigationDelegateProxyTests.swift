//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
    @testable import EmbraceCore
    @testable @_implementationOnly import EmbraceObjCUtilsInternal
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
            let proxy = EMBWKNavigationDelegateProxy(originalDelegate: originalDelegate)

            // when calls are made to the proxy
            let webView = WKWebView()
            let error = NSError(domain: "com.embrace.test", code: 0)
            let block: (WKNavigationResponsePolicy) -> Void = { _ in }
            let block1: (WKNavigationActionPolicy) -> Void = { _ in }
            let block2: (WKNavigationActionPolicy, WKWebpagePreferences) -> Void = { _, _ in }
            let block3: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void = { _, _ in }
            let block4: (Bool) -> Void = { _ in }

            let expectedCallbackCount: Int

            #if !os(macOS)
                expectedCallbackCount = 14
                proxy.webView(webView, decidePolicyFor: WKNavigationResponse(), decisionHandler: block)
            #else
                expectedCallbackCount = 12
            #endif
            proxy.webView(webView, didFailProvisionalNavigation: navigation, withError: error)
            proxy.webView(webView, didFail: navigation, withError: error)

            let delegate = proxy as WKNavigationDelegate
            delegate.webView?(webView, decidePolicyFor: WKNavigationAction(), decisionHandler: block1)

            delegate.webView?(
                webView,
                decidePolicyFor: WKNavigationAction(),
                preferences: WKWebpagePreferences(),
                decisionHandler: block2
            )
            delegate.webView?(webView, didStartProvisionalNavigation: navigation)
            delegate.webView?(webView, didReceiveServerRedirectForProvisionalNavigation: navigation)
            delegate.webView?(webView, didCommit: navigation)
            delegate.webView?(webView, didFinish: navigation)
            delegate.webView?(webView, didReceive: URLAuthenticationChallenge(), completionHandler: block3)
            delegate.webViewWebContentProcessDidTerminate?(webView)
            delegate.webView?(
                webView, authenticationChallenge: URLAuthenticationChallenge(), shouldAllowDeprecatedTLS: block4)
            delegate.webView?(webView, navigationAction: WKNavigationAction(), didBecome: download)
            #if !os(macOS)
                delegate.webView?(webView, navigationResponse: WKNavigationResponse(), didBecome: download)
            #endif

            // then the delegate calls are forwarded
            XCTAssertEqual(originalDelegate.callCount, expectedCallbackCount)
        }

        func test_callback() {
            // given a proxy with a callback
            let proxy = EMBWKNavigationDelegateProxy(originalDelegate: nil)

            var callCount: Int = 0
            proxy.callback = { _, _ in
                callCount += 1
            }

            // when calls are made to the proxy
            let webView = WKWebView()
            let block: (WKNavigationResponsePolicy) -> Void = { _ in }
            let error = NSError(domain: "com.embrace.test", code: 0)

            let expectedCount: Int
            #if !os(macOS)
                // WKNavigationResponse dealloc crashes in a weird way on macOS.
                proxy.webView(webView, decidePolicyFor: WKNavigationResponse(), decisionHandler: block)
                expectedCount = 3
            #else
                expectedCount = 2
            #endif

            proxy.webView(webView, didFailProvisionalNavigation: navigation, withError: error)
            proxy.webView(webView, didFail: navigation, withError: error)

            // then the callback is called
            XCTAssertEqual(callCount, expectedCount)
        }
    }

#endif
