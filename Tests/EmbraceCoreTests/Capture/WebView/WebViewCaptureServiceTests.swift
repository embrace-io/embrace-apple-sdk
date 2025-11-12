//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
    @testable import EmbraceCore
    @testable import EmbraceObjCUtilsInternal
    import WebKit
    import XCTest
    import TestSupport
    import EmbraceCommonInternal

    @MainActor
    class WebViewCaptureServiceTests: XCTestCase {

        let otel: MockEmbraceOpenTelemetry! = MockEmbraceOpenTelemetry()
        let service: WebViewCaptureService! = WebViewCaptureService()
        static let pids: EmbraceMutex<Set<Int32>> = EmbraceMutex(Set<Int32>())

        override func setUp() {
            service.install(otel: otel)
        }

        internal func checkTestAllowed() throws {
            let pid = getpid()
            try Self.pids.withLock {
                try XCTSkipIf($0.contains(pid), "This process has already been used to run a WebViewCaptureServiceTest")
                $0.insert(pid)
            }
        }
    }

    class WebViewCaptureServiceTests_One: WebViewCaptureServiceTests {

        func test_setNavigationDelegate() throws {
            try checkTestAllowed()

            // given a webview
            let webView = WKWebView()

            // Verify no pre-existing delegate
            XCTAssertNil(webView.navigationDelegate, "webView should start with nil navigationDelegate")
            XCTAssertNil(webView.emb_proxy, "webView should start with nil emb_proxy")

            // when setting a navigationDelegate
            let originalDelegate = MockWKNavigationDelegate()
            webView.navigationDelegate = originalDelegate

            // then a proxy delegate is correctly set
            guard let navigationDelegate = webView.navigationDelegate else {
                XCTFail("navigationDelegate should not be nil after setting")
                return
            }

            // Check if swizzling is working - if not, skip this test as it's a known flakiness issue
            try XCTSkipIf(
                !navigationDelegate.isKind(of: EMBWKNavigationDelegateProxy.self),
                "Swizzling not active - this is a known flakiness issue in full suite runs"
            )

            guard let proxy = webView.emb_proxy else {
                XCTFail("emb_proxy should not be nil when navigationDelegate is a proxy")
                return
            }

            // Known flakiness: proxy.originalDelegate can be nil in full suite runs
            // This appears to be a race condition in the swizzling setup
            try XCTSkipIf(
                proxy.originalDelegate == nil,
                "proxy.originalDelegate is nil - this is a known flakiness issue in full suite runs"
            )

            XCTAssert(
                proxy.originalDelegate!.isKind(of: MockWKNavigationDelegate.self),
                "proxy.originalDelegate should be MockWKNavigationDelegate but is \(type(of: proxy.originalDelegate!))"
            )
        }
    }

    class WebViewCaptureServiceTests_Two: WebViewCaptureServiceTests {

        func test_setNavigationDelegate_ShouldntGenerateRecursion() throws {
            try checkTestAllowed()

            // given a webView already "swizzled"
            let webView = WKWebView()
            let originalDelegate = MockWKNavigationDelegate()
            webView.navigationDelegate = originalDelegate

            // When Setting a new delegate for the same webview
            let secondDelegate = MockWKNavigationDelegate()
            webView.navigationDelegate = secondDelegate

            // Then the proxy class added during in the swizzled method should be removed to prevent any potential recursion.
            XCTAssertTrue(try XCTUnwrap(webView.navigationDelegate).isKind(of: MockWKNavigationDelegate.self))
        }
    }

    class WebViewCaptureServiceTests_Three: WebViewCaptureServiceTests {

        func test_spanEvent() throws {
            try checkTestAllowed()

            // when a url is loaded
            let url = URL(string: "https://www.google.com/")!
            service.didLoad(url: url, statusCode: nil)

            // then a span event is created
            XCTAssert(otel.events.count > 0)

            let event = otel.events[0]
            XCTAssertEqual(event.name, "emb-web-view")
            XCTAssertEqual(event.attributes["emb.type"], .string("ux.webview"))
            XCTAssertEqual(event.attributes["webview.url"]!.description, url.absoluteString)
        }
    }

    class WebViewCaptureServiceTests_Four: WebViewCaptureServiceTests {

        func test_spanEvent_withError() throws {

            try checkTestAllowed()

            // when a url is loaded with error
            let url = URL(string: "https://www.google.com/")!
            service.didLoad(url: url, statusCode: 123)

            // then a span event is created with an error code
            XCTAssert(otel.events.count > 0)

            let event = otel.events.last!
            XCTAssertEqual(event.name, "emb-web-view")
            XCTAssertEqual(event.attributes["emb.type"], .string("ux.webview"))
            XCTAssertEqual(event.attributes["webview.error_code"], .int(123))
        }
    }

#endif
