//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
import WebKit
import EmbraceOTel

class WKNavigationDelegateProxy: NSObject {
    weak var originalDelegate: WKNavigationDelegate?
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
        if let delegate = originalDelegate {
            delegate.webView?(webView, decidePolicyFor: navigationResponse, decisionHandler: decisionHandler)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        // capture
        callback?(webView.url, (error as NSError).code)

        // call original
        if let delegate = originalDelegate {
            delegate.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
        }
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: any Error
    ) {
        // capture
        callback?(webView.url, (error as NSError).code)

        // call original
        if let delegate = originalDelegate {
            delegate.webView?(webView, didFail: navigation, withError: error)
        }
    }

    // forwarded methods without capture
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let delegate = originalDelegate {
            delegate.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        if let delegate = originalDelegate {
            delegate.webView?(
                webView,
                decidePolicyFor: navigationAction,
                preferences: preferences,
                decisionHandler: decisionHandler
            )
        } else {
            decisionHandler(.allow, preferences)
        }
    }

    func webView(
        _ webView: WKWebView,
        didStartProvisionalNavigation navigation: WKNavigation!
    ) {
        if let delegate = originalDelegate {
            delegate.webView?(webView, didStartProvisionalNavigation: navigation)
        }
    }

    func webView(
        _ webView: WKWebView,
        didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!
    ) {
        if let delegate = originalDelegate {
            delegate.webView?(webView, didReceiveServerRedirectForProvisionalNavigation: navigation)
        }
    }

    func webView(
        _ webView: WKWebView,
        didCommit navigation: WKNavigation!
    ) {
        if let delegate = originalDelegate {
            delegate.webView?(webView, didCommit: navigation)
        }
    }

    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        if let delegate = originalDelegate {
            delegate.webView?(webView, didFinish: navigation)
        }
    }

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if let delegate = originalDelegate {
            delegate.webView?(webView, didReceive: challenge, completionHandler: completionHandler)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    func webViewWebContentProcessDidTerminate(
        _ webView: WKWebView
    ) {
        if let delegate = originalDelegate {
            delegate.webViewWebContentProcessDidTerminate?(webView)
        }
    }

    @available(iOS 14, *)
    func webView(
        _ webView: WKWebView,
        authenticationChallenge challenge: URLAuthenticationChallenge,
        shouldAllowDeprecatedTLS decisionHandler: @escaping (Bool) -> Void
    ) {
        if let delegate = originalDelegate {
            delegate.webView?(webView, authenticationChallenge: challenge, shouldAllowDeprecatedTLS: decisionHandler)
        } else {
            decisionHandler(false)
        }
    }

    @available(iOS 14.5, *)
    func webView(
        _ webView: WKWebView,
        navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        if let delegate = originalDelegate {
            delegate.webView?(webView, navigationAction: navigationAction, didBecome: download)
        }
    }

    @available(iOS 14.5, *)
    func webView(
        _ webView: WKWebView,
        navigationResponse: WKNavigationResponse,
        didBecome download: WKDownload
    ) {
        if let delegate = originalDelegate {
            delegate.webView?(webView, navigationResponse: navigationResponse, didBecome: download)
        }
    }
}
#endif
