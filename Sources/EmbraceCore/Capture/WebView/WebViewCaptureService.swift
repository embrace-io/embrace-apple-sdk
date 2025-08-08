//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
    import Foundation
    import WebKit
    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
        import EmbraceOTelInternal
        import EmbraceCaptureService
        import EmbraceSemantics
        @_implementationOnly import EmbraceObjCUtilsInternal
    #endif
    import OpenTelemetryApi

    /// Service that generates OpenTelemetry span events when a `WKWebView` loads an URL or throws an error.
    @objc(EMBWebViewCaptureService)
    public final class WebViewCaptureService: CaptureService {

        @objc public let options: WebViewCaptureService.Options
        private static let knownBadProxies = [
            "SafeDKWKNavigationDelegateInterceptor"
        ]
        private let lock: NSLocking
        private var swizzlers: [any Swizzlable] = []

        @objc public convenience init(options: WebViewCaptureService.Options) {
            self.init(options: options, lock: NSLock())
        }

        public convenience override init() {
            self.init(lock: NSLock())
        }

        init(
            options: WebViewCaptureService.Options = WebViewCaptureService.Options(),
            lock: NSLocking
        ) {
            self.options = options
            self.lock = lock

            super.init()
        }

        public override func onInstall() {
            lock.lock()
            defer {
                lock.unlock()
            }

            guard state == .uninstalled else {
                return
            }

            initializeSwizzlers()

            swizzlers.forEach {
                do {
                    try $0.install()
                } catch let exception {
                    Embrace.logger.error("Capture service couldn't be installed: \(exception.localizedDescription)")
                }
            }
        }

        private func initializeSwizzlers() {
            if shouldPreventFromKnownSwizzlingErrors() {
                swizzlers.append(WKWebViewSetNavigationDelegateSwizzler(delegate: self))
                swizzlers.append(WKWebViewLoadRequestSwizzler())
                swizzlers.append(WKWebViewLoadHTMLStringSwizzler())
                swizzlers.append(WKWebViewLoadFileURLSwizzler())
                swizzlers.append(WKWebViewLoadDataSwizzler())
            }
        }

        // Embrace wants to track internal navigation events in `WKWebViews` to assist our customers with debugging.
        // To do so, we forcefully set a nil `WKNavigationDelegate` to be injected into the `WKWebView` when the delegate is already nil.
        // This is safe because any other player is free to overwrite our delegate with their own (and we'd swizzle and track their delegate).
        // Occasionally, players doing something similar (proxying) implement their logic poorly and fail to recognize that they must overwrite
        // our delegate, or they could have weird validations that prevent from calling the original delegate.
        // In this case it is not safe for us to inject as we are likely to break application functionality.
        // To err on the side of caution we will not inject if we detect these problematic classes in memory.
        // Currently the only known bad-actor is SafeDK/AppLovin.
        private func shouldPreventFromKnownSwizzlingErrors() -> Bool {
            for proxy in WebViewCaptureService.knownBadProxies {
                if NSClassFromString(proxy) != nil {
                    return false
                }
            }
            return true
        }
    }

    extension WebViewCaptureService: WebViewSwizzlerDelegate {

        func didLoad(url: URL?, statusCode: Int?) {
            guard let url = url else {
                return
            }

            let urlString = getUrlString(url: url)

            var attributes: [String: AttributeValue] = [
                SpanEventSemantics.keyEmbraceType: .string(EmbraceType.webView.rawValue),
                SpanEventSemantics.WebView.keyUrl: .string(urlString)
            ]

            if let errorCode = statusCode, errorCode != 200 {
                attributes[SpanEventSemantics.WebView.keyErrorCode] = .int(errorCode)
            }

            let event = RecordingSpanEvent(
                name: SpanEventSemantics.WebView.name,
                timestamp: Date(),
                attributes: attributes
            )
            otel?.add(event: event)
        }

        private func getUrlString(url: URL) -> String {
            guard options.stripQueryParams else {
                return url.absoluteString
            }

            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return url.absoluteString
            }

            components.query = nil

            return components.string ?? url.absoluteString
        }
    }

    struct WKWebViewSetNavigationDelegateSwizzler: Swizzlable {
        typealias ImplementationType = @convention(c) (WKWebView, Selector, WKNavigationDelegate) -> Void
        typealias BlockImplementationType = @convention(block) (WKWebView, WKNavigationDelegate) -> Void
        static var selector: Selector = #selector(setter: WKWebView.navigationDelegate)
        var baseClass: AnyClass
        weak var delegate: WebViewSwizzlerDelegate?

        init(delegate: WebViewSwizzlerDelegate?, baseClass: AnyClass = WKWebView.self) {
            self.baseClass = baseClass
            self.delegate = delegate
        }

        func install() throws {
            try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
                return { webView, delegate in
                    if !(webView.navigationDelegate is EMBWKNavigationDelegateProxy) {
                        let proxy = EMBWKNavigationDelegateProxy(
                            originalDelegate: delegate
                        ) { url, statusCode in
                            self.delegate?.didLoad(url: url, statusCode: statusCode)
                        }
                        webView.emb_proxy = proxy

                        originalImplementation(webView, Self.selector, proxy)
                    } else {
                        originalImplementation(webView, Self.selector, delegate)
                    }
                }
            }
        }
    }

    struct WKWebViewLoadRequestSwizzler: Swizzlable {
        typealias ImplementationType = @convention(c) (WKWebView, Selector, URLRequest) -> WKNavigation?
        typealias BlockImplementationType = @convention(block) (WKWebView, URLRequest) -> WKNavigation?
        static var selector: Selector = #selector(WKWebView.load(_:))
        var baseClass: AnyClass

        init(baseClass: AnyClass = WKWebView.self) {
            self.baseClass = baseClass
        }

        func install() throws {
            try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
                return { webView, request in
                    if webView.navigationDelegate == nil {
                        webView.navigationDelegate = nil  // forceful trigger setNavigationDelegate swizzler
                    }

                    return originalImplementation(webView, Self.selector, request)
                }
            }
        }
    }

    struct WKWebViewLoadHTMLStringSwizzler: Swizzlable {
        typealias ImplementationType = @convention(c) (WKWebView, Selector, String, URL?) -> WKNavigation?
        typealias BlockImplementationType = @convention(block) (WKWebView, String, URL?) -> WKNavigation?
        static var selector: Selector = #selector(WKWebView.loadHTMLString(_:baseURL:))
        var baseClass: AnyClass

        init(baseClass: AnyClass = WKWebView.self) {
            self.baseClass = baseClass
        }

        func install() throws {
            try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
                return { webView, htmlString, url in
                    if webView.navigationDelegate == nil {
                        webView.navigationDelegate = nil  // forcefully trigger setNavigationDelegate swizzler
                    }

                    return originalImplementation(webView, Self.selector, htmlString, url)
                }
            }
        }
    }

    struct WKWebViewLoadFileURLSwizzler: Swizzlable {
        typealias ImplementationType = @convention(c) (WKWebView, Selector, URL, URL) -> WKNavigation?
        typealias BlockImplementationType = @convention(block) (WKWebView, URL, URL) -> WKNavigation?
        static var selector: Selector = #selector(WKWebView.loadFileURL(_:allowingReadAccessTo:))
        var baseClass: AnyClass

        init(baseClass: AnyClass = WKWebView.self) {
            self.baseClass = baseClass
        }

        func install() throws {
            try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
                return { webView, fileURL, readAccessURL in
                    if webView.navigationDelegate == nil {
                        webView.navigationDelegate = nil  // forcefully trigger setNavigationDelegate swizzler
                    }

                    return originalImplementation(webView, Self.selector, fileURL, readAccessURL)
                }
            }
        }
    }

    struct WKWebViewLoadDataSwizzler: Swizzlable {
        typealias ImplementationType = @convention(c) (WKWebView, Selector, Data, String, String, URL?) -> WKNavigation?
        typealias BlockImplementationType = @convention(block) (WKWebView, Data, String, String, URL?) -> WKNavigation?
        static var selector: Selector = #selector(
            WKWebView.load(_:mimeType:characterEncodingName:baseURL:)
        )
        var baseClass: AnyClass

        init(baseClass: AnyClass = WKWebView.self) {
            self.baseClass = baseClass
        }

        func install() throws {
            try swizzleInstanceMethod { originalImplementation -> BlockImplementationType in
                return { webView, data, mimeType, encoding, url in
                    if webView.navigationDelegate == nil {
                        webView.navigationDelegate = nil  // forcefully trigger setNavigationDelegate swizzler
                    }

                    return originalImplementation(webView, Self.selector, data, mimeType, encoding, url)
                }
            }
        }
    }

    protocol WebViewSwizzlerDelegate: AnyObject {
        func didLoad(url: URL?, statusCode: Int?)
    }
#endif
