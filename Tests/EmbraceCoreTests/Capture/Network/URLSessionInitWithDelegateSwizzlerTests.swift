//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore

class DummyURLSessionDelegate: NSObject, URLSessionDelegate {}

class URLSessionInitWithDelegateSwizzlerTests: XCTestCase {
    private var sut: URLSessionInitWithDelegateSwizzler!
    private var session: URLSession!
    private var originalDelegate: URLSessionDelegate!

    func testAfterInstall_onCreateURLSessionWithDelegate_originalShouldBeWrapped() throws {
        givenDataTaskWithURLRequestSwizzler()
        try givenSwizzlingWasDone()
        whenInitializingURLSessionWithDummyDelegate()
        thenSessionsDelegateShouldntBeDummyDelegate()
        thenSessionsDelegateShouldBeEmbracesProxy()
    }

    /// This test reflects something _I_ consider as a bug. We should add ourselves as
    /// a delegate when there's none.
    func testAfterInstall_onCreateURLSessionWithoutDelegate_delegateShouldBeNil() throws {
        givenDataTaskWithURLRequestSwizzler()
        try givenSwizzlingWasDone()
        whenInitializingURLSessionWithoutDelegate()
        thenSessionsDelegateShouldBeNil()
    }

    func test_onInitWithHandler_defaultBaseClassIsURLSession() throws {
        givenDataTaskWithURLRequestSwizzler()
        thenBaseClassShouldBeURLSession()
    }
}

private extension URLSessionInitWithDelegateSwizzlerTests {
    func givenDataTaskWithURLRequestSwizzler() {
        let handler = MockURLSessionTaskHandler()
        sut = URLSessionInitWithDelegateSwizzler(handler: handler)
    }

    func givenSwizzlingWasDone() throws {
        try sut.install()
    }

    func whenInitializingURLSessionWithDummyDelegate() {
        let originalDelegate = DummyURLSessionDelegate()
        session = URLSession(configuration: .default,
                             delegate: originalDelegate,
                             delegateQueue: nil)
    }

    func whenInitializingURLSessionWithoutDelegate() {
        session = URLSession(configuration: .default)
    }

    func thenSessionsDelegateShouldntBeDummyDelegate() {
        XCTAssertFalse(session.delegate.self is DummyURLSessionDelegate)
    }

    func thenSessionsDelegateShouldBeEmbracesProxy() {
        XCTAssertTrue(session.delegate.self is URLSessionDelegateProxy)
    }

    func thenSessionsDelegateShouldBeNil() {
        XCTAssertNil(session.delegate)
    }

    func thenBaseClassShouldBeURLSession() {
        XCTAssertTrue(sut.baseClass == URLSession.self)
    }
}
