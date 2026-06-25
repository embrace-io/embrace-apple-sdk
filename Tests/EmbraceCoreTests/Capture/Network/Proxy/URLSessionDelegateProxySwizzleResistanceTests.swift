//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import ObjectiveC.runtime
import XCTest

@testable import EmbraceCore
@testable import EmbraceObjCUtilsInternal

// 3rd party debugging tools rename Embrace's original IMP to a prefixed selector, e.g.
// `_sdk_swizzle_XXX_URLSession:dataTask:didReceiveData:`. When the runtime dispatches to
// that renamed IMP, `_cmd` equals the prefix — not the canonical protocol selector — so
// any `respondsToSelector:_cmd` check against the host delegate returns NO, silently
// dropping the callback.
//
// Each test reproduces this exact dispatch-time state by extracting the proxy's IMP and
// calling it directly under a fake selector, then asserting the original delegate was
// still reached.
class URLSessionDelegateProxySwizzleResistanceTests: XCTestCase {

    private var originalDelegate: FullyImplementedURLSessionDelegate!
    private var handler: MockURLSessionTaskHandler!
    private var proxy: EMBURLSessionDelegateProxy!
    private var proxyClass: AnyClass!

    // A selector that no real delegate ever implements, standing in for the 3rd party generated prefix.
    private let swizzledCmd = NSSelectorFromString("_testSwizzle_fakeSelector")

    override func setUp() {
        super.setUp()
        handler = .init()
        originalDelegate = .init()
        proxy = EmbraceMakeURLSessionDelegateProxy(originalDelegate, handler)
        proxyClass = object_getClass(proxy)
    }

    // MARK: - NSURLSessionDelegate

    func test_didBecomeInvalidWithError_forwardsUnderSwizzledSelector() {
        typealias F = @convention(c) (AnyObject, Selector, URLSession, NSError?) -> Void
        let fn: F = extractIMP(for: NSSelectorFromString("URLSession:didBecomeInvalidWithError:"))
        fn(proxy, swizzledCmd, URLSession.shared, nil)
        XCTAssertTrue(originalDelegate.didCallDidBecomeInvalidWithError)
    }

    func test_didReceiveChallenge_sessionLevel_forwardsUnderSwizzledSelector() {
        typealias Handler = @convention(block) (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        typealias F = @convention(c) (AnyObject, Selector, URLSession, URLAuthenticationChallenge, Handler) -> Void
        let fn: F = extractIMP(for: NSSelectorFromString("URLSession:didReceiveChallenge:completionHandler:"))
        fn(proxy, swizzledCmd, URLSession.shared, URLAuthenticationChallenge()) { _, _ in }
        XCTAssertTrue(originalDelegate.didCallDidReceiveChallenge)
    }

    func test_didReceiveChallenge_taskLevel_forwardsUnderSwizzledSelector() {
        typealias Handler = @convention(block) (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        typealias F = @convention(c) (AnyObject, Selector, URLSession, URLSessionTask, URLAuthenticationChallenge, Handler) -> Void
        let fn: F = extractIMP(for: NSSelectorFromString("URLSession:task:didReceiveChallenge:completionHandler:"))
        fn(proxy, swizzledCmd, URLSession.shared, aTask(), URLAuthenticationChallenge()) { _, _ in }
        XCTAssertTrue(originalDelegate.didCallTaskWithReceivedAuthenticationChallenge)
    }

    // MARK: - NSURLSessionTaskDelegate

    func test_didCompleteWithError_forwardsUnderSwizzledSelector() {
        typealias F = @convention(c) (AnyObject, Selector, URLSession, URLSessionTask, NSError?) -> Void
        let fn: F = extractIMP(for: NSSelectorFromString("URLSession:task:didCompleteWithError:"))
        fn(proxy, swizzledCmd, URLSession.shared, aTask(), nil)
        XCTAssertTrue(originalDelegate.didCallDidCompleteWithError)
    }

    func test_didFinishCollectingMetrics_forwardsUnderSwizzledSelector() {
        typealias F = @convention(c) (AnyObject, Selector, URLSession, URLSessionTask, URLSessionTaskMetrics) -> Void
        let fn: F = extractIMP(for: NSSelectorFromString("URLSession:task:didFinishCollectingMetrics:"))
        fn(proxy, swizzledCmd, URLSession.shared, aTask(), makeMetrics())
        XCTAssertTrue(originalDelegate.didCallDidFinishCollecting)
    }

    func test_willPerformHTTPRedirection_forwardsUnderSwizzledSelector() {
        typealias Handler = @convention(block) (URLRequest?) -> Void
        typealias F = @convention(c) (AnyObject, Selector, URLSession, URLSessionTask, HTTPURLResponse, URLRequest, Handler) -> Void
        let fn: F = extractIMP(for: NSSelectorFromString("URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:"))
        fn(proxy, swizzledCmd, URLSession.shared, aTask(), HTTPURLResponse(), URLRequest(url: URL(string: "https://embrace.io")!)) { _ in }
        XCTAssertTrue(originalDelegate.didCallWillPerformHTTPRedirection)
    }

    // MARK: - NSURLSessionDataDelegate

    func test_didReceiveData_forwardsUnderSwizzledSelector() {
        typealias F = @convention(c) (AnyObject, Selector, URLSession, URLSessionDataTask, Data) -> Void
        let fn: F = extractIMP(for: NSSelectorFromString("URLSession:dataTask:didReceiveData:"))
        fn(proxy, swizzledCmd, URLSession.shared, aTask(), Data())
        XCTAssertTrue(originalDelegate.didCallDidReceiveData)
    }

    func test_didReceiveResponse_forwardsUnderSwizzledSelector() {
        typealias Handler = @convention(block) (URLSession.ResponseDisposition) -> Void
        typealias F = @convention(c) (AnyObject, Selector, URLSession, URLSessionDataTask, URLResponse, Handler) -> Void
        let fn: F = extractIMP(for: NSSelectorFromString("URLSession:dataTask:didReceiveResponse:completionHandler:"))
        fn(proxy, swizzledCmd, URLSession.shared, aTask(), URLResponse()) { _ in }
        XCTAssertTrue(originalDelegate.didCallDidReceiveResponseWithHandler)
    }

    // MARK: - NSURLSessionDownloadDelegate

    func test_didFinishDownloadingToURL_forwardsUnderSwizzledSelector() {
        typealias F = @convention(c) (AnyObject, Selector, URLSession, URLSessionDownloadTask, URL) -> Void
        let fn: F = extractIMP(for: NSSelectorFromString("URLSession:downloadTask:didFinishDownloadingToURL:"))
        fn(proxy, swizzledCmd, URLSession.shared, aDownloadTask(), URL(string: "https://embrace.io")!)
        XCTAssertTrue(originalDelegate.didCallDidFinishDownloadingTo)
    }
}

// MARK: - Private helpers

extension URLSessionDelegateProxySwizzleResistanceTests {

    // Extracts the IMP for `selector` from the proxy's runtime class and casts it to `T`.
    // The caller then invokes it with `swizzledCmd` in place of the real `_cmd`, which is
    // precisely what a 3rd party sdk method_exchangeImplementations produces at dispatch time.
    fileprivate func extractIMP<T>(for selector: Selector, file: StaticString = #file, line: UInt = #line) -> T {
        guard let method = class_getInstanceMethod(proxyClass, selector) else {
            XCTFail("Method \(selector) not found on \(proxyClass!)", file: file, line: line)
            fatalError()
        }
        return unsafeBitCast(method_getImplementation(method), to: T.self)
    }

    fileprivate func aTask() -> URLSessionDataTask {
        URLSession.shared.dataTask(with: URLRequest(url: URL(string: "https://embrace.io")!))
    }

    fileprivate func aDownloadTask() -> URLSessionDownloadTask {
        URLSession.shared.downloadTask(with: URLRequest(url: URL(string: "https://embrace.io")!))
    }

    fileprivate func makeMetrics() -> URLSessionTaskMetrics {
        let klass: AnyClass = NSClassFromString("NSURLSessionTaskMetrics")!
        return klass.alloc().perform(NSSelectorFromString("init")).takeUnretainedValue() as! URLSessionTaskMetrics
    }
}
