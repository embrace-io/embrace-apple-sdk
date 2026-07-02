//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

extension EmbraceType {
    public static let webView = EmbraceType(ux: "webview")
}

extension SpanEventSemantics {
    public struct WebView {
        public static let name = "emb-web-view"
        public static let keyUrl = "webview.url"
        public static let keyErrorCode = "webview.error_code"
    }
}
