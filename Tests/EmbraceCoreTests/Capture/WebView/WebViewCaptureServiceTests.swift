//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(WebKit)
@testable import EmbraceCore
@testable @_implementationOnly import EmbraceObjCUtilsInternal
import WebKit
import XCTest
import TestSupport

class WebViewCaptureServiceTests: XCTestCase {

    let otel = MockEmbraceOpenTelemetry()
    let service = WebViewCaptureService()
    let navigation = WKNavigation()
    let response = WKNavigationResponse()

    override func setUpWithError() throws {
        otel.clear()
        service.install(otel: otel) // only does something the first time its called
    }

    func test_setNavigationDelegate() {
        // given a webview
        let webView = WKWebView()

        // when setting a navigationDelegate
        let originalDelegate = MockWKNavigationDelegate()
        webView.navigationDelegate = originalDelegate

        // then a proxy delegate is correctly set
        XCTAssert(webView.navigationDelegate!.isKind(of: EMBWKNavigationDelegateProxy.self))
        XCTAssertNotNil(webView.emb_proxy!.originalDelegate)
        XCTAssert(webView.emb_proxy!.originalDelegate!.isKind(of: MockWKNavigationDelegate.self))
    }

    func test_setNavigationDelegate_ShouldntGenerateRecursion() throws {
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

    func test_spanEvent() {
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

    func test_spanEvent_withError() {
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
