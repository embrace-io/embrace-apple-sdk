//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal

public extension SpanEventType {
    static let webView = SpanEventType(ux: "webview")
}

public extension SpanEventSemantics {
    struct WebView {
        public static let name = "emb-web-view"
        public static let keyUrl = "webview.url"
        public static let keyErrorCode = "webview.error_code"
    }
}
