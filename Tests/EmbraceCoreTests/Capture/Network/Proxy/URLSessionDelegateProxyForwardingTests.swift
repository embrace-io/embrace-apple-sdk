//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore

/// The purpose of these tests is to prevent any crashes/errores related to the forwarding mechanism of the proxy.
/// Some of these tests might not have an assertion. This is intended.
/// If some of these tests crashes, we're hopefully catching something that was going to be on production
///
/// More tests on the specific forwarding behavior for each method can be found in the `URLSessionDelegateProxyTests` class.
class URLSessionDelegateProxyForwardingTests: XCTestCase {
    private var originalDelegate: URLSessionDelegateWithoutImplementingMethods!
    private var sut: URLSessionDelegateProxy!
    private var handler: MockURLSessionTaskHandler!

    func test_onExecutingMethodImplementedOnlyInProxy_shouldExecuteJustTheProxy() {
        givenProxyContainingDelegateWithoutImplementingMethods()
        whenInvokingDidCompleteWithError()
        thenProxyShouldHaveFinishedTaskInHandler()
    }

    func test_onExecutingMethodThatIsNotImplementedNeitherInProxyNorDelegate_shouldntCrash() {
        givenProxyContainingDelegateWithoutImplementingMethods()
        whenInvokingMethodThatIsNotImplementedInProxyNorDelegate()
    }

    func test_onExecutingMethodFromNonConformantDelegate_shouldntCrash() {
        givenProxyContainingDelegateWithoutImplementingMethods()
        whenInvokingMethodFromNonConformantDelegate()
    }
}

// MARK: - Private Utility Methods
private extension URLSessionDelegateProxyForwardingTests {
    func givenProxyContainingDelegateWithoutImplementingMethods() {
        originalDelegate = .init()
        handler = .init()
        sut = .init(originalDelegate: originalDelegate, handler: handler)
    }

    func whenInvokingDidCompleteWithError() {
        (sut as URLSessionDataDelegate).urlSession?(.shared,
                                                    task: aTask(),
                                                    didCompleteWithError: NSError(domain: "domain", code: 1234))
    }

    func whenInvokingMethodThatIsNotImplementedInProxyNorDelegate() {
        (sut as URLSessionDataDelegate).urlSession?(.shared,
                                                    dataTask: aTask(),
                                                    willCacheResponse: .init(),
                                                    completionHandler: { _ in })
    }

    func whenInvokingMethodFromNonConformantDelegate() {
        (sut as? URLSessionWebSocketDelegate)?.urlSession?(.shared,
                                                         webSocketTask: aWebSocketTask(),
                                                         didCloseWith: .abnormalClosure,
                                                         reason: Data())
    }

    func thenProxyShouldHaveFinishedTaskInHandler() {
        XCTAssertTrue(handler.didInvokeFinish)
    }

    func aTask() -> URLSessionDataTask {
        let url = URL(string: "https://embrace.io")!
        let request = URLRequest(url: url)
        return URLSession.shared.dataTask(with: request)
    }

    func aWebSocketTask() -> URLSessionWebSocketTask {
        URLSession.shared.webSocketTask(with: URLRequest(url: URL(string: "https://embrace.io")!))
    }
}
