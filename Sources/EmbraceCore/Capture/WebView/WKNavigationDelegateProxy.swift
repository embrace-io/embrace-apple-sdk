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

    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) {
            return true
        } else if let originalDelegate = originalDelegate, originalDelegate.responds(to: aSelector) {
            return true
        }
        return false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if super.responds(to: aSelector) {
            return self
        } else if let originalDelegate = originalDelegate, originalDelegate.responds(to: aSelector) {
            return originalDelegate
        }
        return nil
    }
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
}
#endif
