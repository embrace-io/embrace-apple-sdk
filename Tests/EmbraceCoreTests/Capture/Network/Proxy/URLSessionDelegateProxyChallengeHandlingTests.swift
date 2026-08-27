//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import TestSupportObjc
import XCTest

@testable import EmbraceCore
@testable import EmbraceObjCUtilsInternal

class URLSessionDelegateProxyChallengeHandlingTests: XCTestCase {

    private var handler: MockURLSessionTaskHandler!

    override func setUp() {
        super.setUp()
        handler = .init()
    }

    // MARK: - Proxy

    func test_proxy_respondsToSessionChallenge_returnsFalse_whenDelegateIsEmpty() {
        let proxy = EmbraceMakeURLSessionDelegateProxy(EmbraceDummyURLSessionDelegate(), handler)
        let sel = NSSelectorFromString("URLSession:didReceiveChallenge:completionHandler:")
        XCTAssertFalse(proxy.responds(to: sel))
    }

    func test_proxy_respondsToTaskChallenge_returnsFalse_whenDelegateIsEmpty() {
        let proxy = EmbraceMakeURLSessionDelegateProxy(EmbraceDummyURLSessionDelegate(), handler)
        let sel = NSSelectorFromString("URLSession:task:didReceiveChallenge:completionHandler:")
        XCTAssertFalse(proxy.responds(to: sel))
    }

    func test_proxy_respondsToSessionChallenge_returnsTrue_whenDelegateImplementsIt() {
        let proxy = EmbraceMakeURLSessionDelegateProxy(FullyImplementedURLSessionDelegate(), handler)
        let sel = NSSelectorFromString("URLSession:didReceiveChallenge:completionHandler:")
        XCTAssertTrue(proxy.responds(to: sel))
    }

    func test_proxy_respondsToTaskChallenge_returnsTrue_whenDelegateImplementsIt() {
        let proxy = EmbraceMakeURLSessionDelegateProxy(FullyImplementedURLSessionDelegate(), handler)
        let sel = NSSelectorFromString("URLSession:task:didReceiveChallenge:completionHandler:")
        XCTAssertTrue(proxy.responds(to: sel))
    }

    func test_proxy_sessionChallenge_isForwardedToDelegate() {
        let delegate = FullyImplementedURLSessionDelegate()
        let proxy = EmbraceMakeURLSessionDelegateProxy(delegate, handler)

        let expectation = expectation(description: "challenge completion handler called")
        let handler: AnyObject = unsafeBitCast(
            { (_: URLSession.AuthChallengeDisposition, _: URLCredential?) in
                expectation.fulfill()
            } as @convention(block) (URLSession.AuthChallengeDisposition, URLCredential?) -> Void,
            to: AnyObject.self
        )

        InvocationHelper.invoke(
            on: proxy,
            selector: NSSelectorFromString("URLSession:didReceiveChallenge:completionHandler:"),
            parameters: [URLSession.shared, URLAuthenticationChallenge(), handler]
        )

        XCTAssertTrue(delegate.didCallDidReceiveChallenge)
        wait(for: [expectation])
    }

    func test_proxy_taskChallenge_isForwardedToDelegate() {
        let delegate = FullyImplementedURLSessionDelegate()
        let proxy = EmbraceMakeURLSessionDelegateProxy(delegate, handler)

        InvocationHelper.invoke(
            on: proxy,
            selector: NSSelectorFromString("URLSession:task:didReceiveChallenge:completionHandler:"),
            parameters: [
                URLSession.shared,
                URLSession.shared.dataTask(with: URLRequest(url: URL(string: "https://embrace.io")!)),
                URLAuthenticationChallenge(),
                unsafeBitCast(
                    { (_: URLSession.AuthChallengeDisposition, _: URLCredential?) in
                    } as @convention(block) (URLSession.AuthChallengeDisposition, URLCredential?) -> Void,
                    to: AnyObject.self
                )
            ]
        )

        XCTAssertTrue(delegate.didCallTaskWithReceivedAuthenticationChallenge)
    }
}
