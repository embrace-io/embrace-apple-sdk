//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
@testable import EmbraceObjCUtilsInternal

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

        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:task:didCompleteWithError:"),
            parameters: [
                URLSession.shared,
                aTask(),
                NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown)
            ]
        )
    }

    fileprivate func whenInvokingMethodThatIsNotImplementedInProxyNorDelegate() {

        let completionClosure = { (_: CachedURLResponse) in }
        let block: AnyObject = unsafeBitCast(completionClosure as @convention(block) (CachedURLResponse) -> Void, to: AnyObject.self)

        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:dataTask:willCacheResponse:completionHandler:"),
            parameters: [
                URLSession.shared,
                aTask(),
                CachedURLResponse(),
                block
            ],
            expect: false
        )
    }

    fileprivate func whenInvokingMethodFromNonConformantDelegate() {

        InvocationHelper.invoke(
            on: sut,
            selector: NSSelectorFromString("URLSession:webSocketTask:didCloseWithCode:reason:"),
            parameters: [
                URLSession.shared,
                aWebSocketTask(),
                URLSessionWebSocketTask.CloseCode.abnormalClosure,
                Data()
            ],
            expect: false
        )
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
