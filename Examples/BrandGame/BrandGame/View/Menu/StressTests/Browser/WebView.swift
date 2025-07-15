//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import WebKit

struct WebView: ViewRepresentable {
    @Binding var urlString: String
    var webView: WKWebView = WKWebView()

    func makeView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateView(_ webView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, webView: webView)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        var webView: WKWebView

        init(_ parent: WebView, webView: WKWebView) {
            self.parent = parent
            self.webView = webView
        }

        func goBack() {
            webView.goBack()
        }

        func goForward() {
            webView.goForward()
        }

        func goHome() {
            guard let initialPage = webView.backForwardList.backList.first else {
                return
            }
            webView.go(to: initialPage)
        }
    }
}
