//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
@testable @_implementationOnly import EmbraceObjCUtilsInternal

/// The purpose of these tests is to prevent any crashes/errors related to the proxy's forwarding mechanism.
/// Some of these tests might not have an assertion. This is intentional.
/// If any of these tests crash, we're hopefully catching something that could have occurred in production.
///
/// More tests on the specific forwarding behavior for each method can be found in the `URLSessionDelegateProxyTests` class.
class URLSessionDelegateProxyForwardingTests: XCTestCase {
    private var originalDelegate: NotImplementedURLSessionDelegate!
    private var sut: EMBURLSessionDelegateProxy!
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
extension URLSessionDelegateProxyForwardingTests {
    fileprivate func givenProxyContainingDelegateWithoutImplementingMethods() {
        originalDelegate = .init()
        handler = .init()
        sut = EMBURLSessionDelegateProxy(delegate: originalDelegate, handler: handler)
    }

    fileprivate func whenInvokingDidCompleteWithError() {
        (sut as URLSessionDataDelegate).urlSession?(
            .shared,
            task: aTask(),
            didCompleteWithError: NSError(domain: "domain", code: 1234))
    }

    fileprivate func whenInvokingMethodThatIsNotImplementedInProxyNorDelegate() {
        (sut as URLSessionDataDelegate).urlSession?(
            .shared,
            dataTask: aTask(),
            willCacheResponse: .init(),
            completionHandler: { _ in })
    }

    fileprivate func whenInvokingMethodFromNonConformantDelegate() {
        (sut as? URLSessionWebSocketDelegate)?.urlSession?(
            .shared,
            webSocketTask: aWebSocketTask(),
            didCloseWith: .abnormalClosure,
            reason: Data())
    }

    fileprivate func thenProxyShouldHaveFinishedTaskInHandler() {
        XCTAssertTrue(handler.didInvokeFinishWithData)
    }

    fileprivate func aTask() -> URLSessionDataTask {
        let url = URL(string: "https://embrace.io")!
        let request = URLRequest(url: url)
        return URLSession.shared.dataTask(with: request)
    }

    fileprivate func aWebSocketTask() -> URLSessionWebSocketTask {
        URLSession.shared.webSocketTask(with: URLRequest(url: URL(string: "https://embrace.io")!))
    }
}
