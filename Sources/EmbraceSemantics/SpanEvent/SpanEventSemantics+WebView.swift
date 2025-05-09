//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif

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

public extension SpanType {
    @available(*, deprecated, renamed: "SpanEventType.webView", message: "Has been moved to `SpanEventType.webView`")
    static let webView = SpanType(ux: "webview")
}
