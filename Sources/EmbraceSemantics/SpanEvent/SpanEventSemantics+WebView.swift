//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension SpanEventType {
    public static let webView = SpanEventType(ux: "webview")
}

extension SpanEventSemantics {
    public struct WebView {
        public static let name = "emb-web-view"
        public static let keyUrl = "webview.url"
        public static let keyErrorCode = "webview.error_code"
    }
}

extension SpanType {
    @available(*, deprecated, renamed: "SpanEventType.webView", message: "Has been moved to `SpanEventType.webView`")
    public static let webView = SpanType(ux: "webview")
}
