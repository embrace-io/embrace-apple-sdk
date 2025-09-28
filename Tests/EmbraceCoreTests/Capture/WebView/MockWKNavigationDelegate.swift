//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
    import WebKit

    class MockWKNavigationDelegate: NSObject, WKNavigationDelegate {

        var callCount: Int = 0

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @MainActor @escaping @Sendable (WKNavigationResponsePolicy) -> Void
        ) {
            callCount += 1
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: any Error
        ) {
            callCount += 1
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: any Error
        ) {
            callCount += 1
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @MainActor @escaping @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            callCount += 1
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            preferences: WKWebpagePreferences,
            decisionHandler: @MainActor @escaping @Sendable (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
        ) {
            callCount += 1
        }

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation!
        ) {
            callCount += 1
        }

        func webView(
            _ webView: WKWebView,
            didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!
        ) {
            callCount += 1
        }

        func webView(
            _ webView: WKWebView,
            didCommit navigation: WKNavigation!
        ) {
            callCount += 1
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            callCount += 1
        }

        func webView(
            _ webView: WKWebView,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @MainActor @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            callCount += 1
        }

        func webViewWebContentProcessDidTerminate(
            _ webView: WKWebView
        ) {
            callCount += 1
        }

        @available(iOS 14, *)
        func webView(
            _ webView: WKWebView,
            authenticationChallenge challenge: URLAuthenticationChallenge,
            shouldAllowDeprecatedTLS decisionHandler: @MainActor @escaping @Sendable (Bool) -> Void
        ) {
            callCount += 1
        }

        @available(iOS 14.5, *)
        func webView(
            _ webView: WKWebView,
            navigationAction: WKNavigationAction,
            didBecome download: WKDownload
        ) {
            callCount += 1
        }

        @available(iOS 14.5, *)
        func webView(
            _ webView: WKWebView,
            navigationResponse: WKNavigationResponse,
            didBecome download: WKDownload
        ) {
            callCount += 1
        }
    }
#endif
