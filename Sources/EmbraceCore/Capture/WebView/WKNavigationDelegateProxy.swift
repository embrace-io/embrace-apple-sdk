//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
import WebKit
import EmbraceOTelInternal

class WKNavigationDelegateProxy: NSObject {
    weak var originalDelegate: WKNavigationDelegate?

    // callback triggered the webview loads an url or errors
    var callback: ((URL?, Int?) -> Void)?
}

extension WKNavigationDelegateProxy: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        // capture
        var statusCode: Int?
        if let httpResponse = navigationResponse.response as? HTTPURLResponse {
            statusCode = httpResponse.statusCode
        }
        callback?(webView.url, statusCode)

        // call original
        originalDelegate?.webView?(webView, decidePolicyFor: navigationResponse, decisionHandler: decisionHandler)
            ?? decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        // capture
        callback?(webView.url, (error as NSError).code)

        // call original
        originalDelegate?.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: any Error
    ) {
        // capture
        callback?(webView.url, (error as NSError).code)

        // call original
        originalDelegate?.webView?(webView, didFail: navigation, withError: error)
    }

    // forwarded methods without capture
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        originalDelegate?.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
            ?? decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        originalDelegate?.webView?(
            webView,
            decidePolicyFor: navigationAction,
            preferences: preferences,
            decisionHandler: decisionHandler
        )
            ?? decisionHandler(.allow, preferences)
    }

    func webView(
        _ webView: WKWebView,
        didStartProvisionalNavigation navigation: WKNavigation!
    ) {
         originalDelegate?.webView?(webView, didStartProvisionalNavigation: navigation)
    }

    func webView(
        _ webView: WKWebView,
        didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!
    ) {
        originalDelegate?.webView?(webView, didReceiveServerRedirectForProvisionalNavigation: navigation)
    }

    func webView(
        _ webView: WKWebView,
        didCommit navigation: WKNavigation!
    ) {
        originalDelegate?.webView?(webView, didCommit: navigation)
    }

    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        originalDelegate?.webView?(webView, didFinish: navigation)
    }

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        originalDelegate?.webView?(webView, didReceive: challenge, completionHandler: completionHandler)
            ?? completionHandler(.performDefaultHandling, nil)
    }

    func webViewWebContentProcessDidTerminate(
        _ webView: WKWebView
    ) {
        originalDelegate?.webViewWebContentProcessDidTerminate?(webView)
    }

    @available(iOS 14, *)
    func webView(
        _ webView: WKWebView,
        authenticationChallenge challenge: URLAuthenticationChallenge,
        shouldAllowDeprecatedTLS decisionHandler: @escaping (Bool) -> Void
    ) {
        originalDelegate?.webView?(
            webView,
            authenticationChallenge: challenge,
            shouldAllowDeprecatedTLS: decisionHandler
        )
            ?? decisionHandler(false)
    }

    @available(iOS 14.5, *)
    func webView(
        _ webView: WKWebView,
        navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        originalDelegate?.webView?(webView, navigationAction: navigationAction, didBecome: download)
    }

    @available(iOS 14.5, *)
    func webView(
        _ webView: WKWebView,
        navigationResponse: WKNavigationResponse,
        didBecome download: WKDownload
    ) {
        originalDelegate?.webView?(webView, navigationResponse: navigationResponse, didBecome: download)
    }
}
#endif
