//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
@testable @_implementationOnly import EmbraceObjCUtilsInternal

class DummyURLSessionDelegate: NSObject, URLSessionDelegate {}

class URLSessionInitWithDelegateSwizzlerTests: XCTestCase {
    private var sut: URLSessionInitWithDelegateSwizzler!
    private var session: URLSession!
    private var originalDelegate: URLSessionDelegate!
    private var previouslySwizzledProxy: EMBURLSessionDelegateProxy!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
        try? sut.unswizzleClassMethod()
    }

    func testAfterInstall_onCreateURLSessionWithDelegate_originalShouldBeWrapped() throws {
        givenURLSessionInitWithDelegateSwizzler()
        try givenSwizzlingWasDone()
        whenInitializingURLSessionWithDelegate()
        thenSessionsDelegateShouldntBeDummyDelegate()
        thenSessionsDelegateShouldBeAnEmbracesProxy()
    }

    func testAfterInstall_onCreateURLSessionWithoutDelegate_delegateShouldntBeNil() throws {
        givenURLSessionInitWithDelegateSwizzler()
        try givenSwizzlingWasDone()
        whenInitializingURLSessionWithoutDelegate()
        thenSessionsDelegateShouldBeAnEmbracesProxy()
    }

    func test_onInitWithHandler_defaultBaseClassIsURLSession() throws {
        givenURLSessionInitWithDelegateSwizzler()
        thenBaseClassShouldBeURLSession()
    }

    func test_unsupportedDelegates() throws {
        givenURLSessionInitWithDelegateSwizzler()
        try givenSwizzlingWasDone()
        whenInitializingURLSessionWithDelegate(GTMSessionFetcher())
        thenSessionsDelegateShouldntBeEmbracesProxy()
        XCTAssertTrue(session.delegate.self is GTMSessionFetcher)
    }

    func test_preventProxyingOurselves() throws {
        givenURLSessionInitWithDelegateSwizzler()
        try givenSwizzlingWasDone()
        whenInitializingURLSessionWithPreviouslySwizzledProxy()
        thenSessionsDelegateShouldBeAnEmbracesProxy()
        thenSessionDelegateShouldBePreviouslySwizzledProxy()
    }
}

private extension URLSessionInitWithDelegateSwizzlerTests {
    func givenURLSessionInitWithDelegateSwizzler() {
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

    func whenInitializingURLSessionWithPreviouslySwizzledProxy() {
        previouslySwizzledProxy = .init(delegate: nil, handler: MockURLSessionTaskHandler())
        whenInitializingURLSessionWithDelegate(previouslySwizzledProxy)
    }

    func whenInitializingURLSessionWithoutDelegate() {
        session = URLSession(configuration: .default)
    }

    func thenSessionsDelegateShouldntBeDummyDelegate() {
        XCTAssertFalse(session.delegate.self is DummyURLSessionDelegate)
    }

    func thenSessionsDelegateShouldBeAnEmbracesProxy() {
        XCTAssertTrue(session.delegate.self is EMBURLSessionDelegateProxy)
    }

    func thenSessionsDelegateShouldntBeEmbracesProxy() {
        XCTAssertFalse(session.delegate.self is EMBURLSessionDelegateProxy)
    }

    func thenSessionDelegateShouldBePreviouslySwizzledProxy() {
        XCTAssertTrue(session.delegate === previouslySwizzledProxy)
    }

    func thenBaseClassShouldBeURLSession() {
        XCTAssertTrue(sut.baseClass == URLSession.self)
    }
}

// unsupported delegates
class GTMSessionFetcher: NSObject, URLSessionDelegate {}
