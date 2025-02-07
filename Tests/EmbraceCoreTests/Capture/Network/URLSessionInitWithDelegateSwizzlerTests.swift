//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
@testable import EmbraceObjCUtilsInternal

class DummyURLSessionDelegate: NSObject, URLSessionDelegate {}

class URLSessionInitWithDelegateSwizzlerTests: XCTestCase {
    private var sut: URLSessionInitWithDelegateSwizzler!
    private var session: URLSession!
    private var originalDelegate: URLSessionDelegate!

    func testAfterInstall_onCreateURLSessionWithDelegate_originalShouldBeWrapped() throws {
        givenDataTaskWithURLRequestSwizzler()
        try givenSwizzlingWasDone()
        whenInitializingURLSessionWithDelegate()
        thenSessionsDelegateShouldntBeDummyDelegate()
        thenSessionsDelegateShouldBeEmbracesProxy()
    }

    func testAfterInstall_onCreateURLSessionWithoutDelegate_delegateShouldntBeNil() throws {
        givenDataTaskWithURLRequestSwizzler()
        try givenSwizzlingWasDone()
        whenInitializingURLSessionWithoutDelegate()
        thenSessionsDelegateShouldBeEmbracesProxy()
    }

    func test_onInitWithHandler_defaultBaseClassIsURLSession() throws {
        givenDataTaskWithURLRequestSwizzler()
        thenBaseClassShouldBeURLSession()
    }

    func test_unsupportedDelegates() throws {
        givenDataTaskWithURLRequestSwizzler()
        try givenSwizzlingWasDone()
        whenInitializingURLSessionWithDelegate(GTMSessionFetcher())
        thenSessionsDelegateShouldntBeEmbracesProxy()
        XCTAssertTrue(session.delegate.self is GTMSessionFetcher)
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

    func whenInitializingURLSessionWithDelegate(_ delegate: URLSessionDelegate = DummyURLSessionDelegate()) {
        session = URLSession(configuration: .default,
                             delegate: delegate,
                             delegateQueue: nil)
    }

    func whenInitializingURLSessionWithoutDelegate() {
        session = URLSession(configuration: .default)
    }

    func thenSessionsDelegateShouldntBeDummyDelegate() {
        XCTAssertFalse(session.delegate.self is DummyURLSessionDelegate)
    }

    func thenSessionsDelegateShouldBeEmbracesProxy() {
        XCTAssertNotNil(session.delegate.self is EMBURLSessionDelegateProxy)
    }

    func thenSessionsDelegateShouldntBeEmbracesProxy() {
        XCTAssertFalse(session.delegate.self is EMBURLSessionDelegateProxy)
    }

    func thenBaseClassShouldBeURLSession() {
        XCTAssertTrue(sut.baseClass == URLSession.self)
    }
}

// unsupported delegates
class GTMSessionFetcher: NSObject, URLSessionDelegate {}
