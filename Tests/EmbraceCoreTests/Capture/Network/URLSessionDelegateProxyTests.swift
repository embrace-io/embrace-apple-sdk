//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore

class URLSessionDelegateProxyTests: XCTestCase {
    private var originalDelegate: FullyImplementedURLSessionTaskDelegate!
    private var sut: URLSessionDelegateProxy!
    private var handler: MockURLSessionTaskHandler!

    func test_onExecuteDidCompleteWithError_shouldCallBothProxyAndOriginalDelegate() throws {
        givenProxyWithFullyImplementedOriginalDelegate()
        // This method is implemented in both proxy and original delegate.
        try whenInvokingDidCompleteWithError()
        thenOriginalDelegateShouldHaveInvokedDidCompleteWithError()
        thenProxyShouldHaveFinishedTaskInHandler()
    }

    func test_onExecutingNonImplementedMethod_shouldForwardToOriginalDelegate() throws {
        let expectation = expectation(description: #function)
        givenProxyWithFullyImplementedOriginalDelegate()
        // This is a non-implemented method in the proxy
        try whenInvokingDidReceiveChallenge(withExpectation: expectation)
        thenOriginalDelegateShouldHaveInvokedDidReceiveChallenge()
        wait(for: [expectation])
    }
}

private extension URLSessionDelegateProxyTests {
    func givenProxyWithFullyImplementedOriginalDelegate() {
        handler = .init()
        originalDelegate = .init()
        sut = .init(originalDelegate: originalDelegate, handler: handler)
    }

    func whenInvokingDidCompleteWithError() throws {
        if #available(iOS 16.0, *) {
            try XCTUnwrap(sut as URLSessionDataDelegate)
                .urlSession?(.shared,
                             task: aTask(),
                             didCompleteWithError: NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown))
        } else {
            throw XCTSkip("This test applies only for iOS 16 and above")
        }
    }

    func whenInvokingDidReceiveChallenge(withExpectation expectation: XCTestExpectation) throws {
        try XCTUnwrap(sut as URLSessionDataDelegate).urlSession?(.shared,
                                                                 didReceive: .init(),
                                                                 completionHandler: { _, _ in
            expectation.fulfill()
        })
    }

    func thenOriginalDelegateShouldHaveInvokedDidReceiveChallenge() {
        XCTAssertTrue(originalDelegate.didCallDidReceiveChallenge)
    }

    func thenOriginalDelegateShouldHaveInvokedDidCompleteWithError() {
        XCTAssertTrue(originalDelegate.didCallDidCompleteWithError)
    }

    func thenProxyShouldHaveFinishedTaskInHandler() {
        XCTAssertTrue(handler.didInvokeFinish)
    }

    func aTask() -> URLSessionDataTask {
        let url = URL(string: "https://embrace.io")!
        let request = URLRequest(url: url)
        return URLSession.shared.dataTask(with: request)
    }

    func aResponse() -> URLResponse { .init() }
}
