//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
@testable import EmbraceObjCUtilsInternal

final class DummyURLSessionDelegate: NSObject, URLSessionDelegate {}

class URLSessionInitWithDelegateSwizzlerTests: XCTestCase, @unchecked Sendable {
    private var sut: URLSessionInitWithDelegateSwizzler!
    private var session: URLSession!
    private var originalDelegate: URLSessionDelegate!
    private var previouslySwizzledProxy: EMBURLSessionDelegateProxy!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
        try? sut.unswizzleClassMethod()
    }

    func testAfterInstall_onCreateURLSessionWithDelegate_originalShouldBeWrapped() async throws {
        givenURLSessionInitWithDelegateSwizzler()
        try await givenSwizzlingWasDone()
        whenInitializingURLSessionWithDelegate()
        thenSessionsDelegateShouldntBeDummyDelegate()
        thenSessionsDelegateShouldBeAnEmbracesProxy()
    }

    func testAfterInstall_onCreateURLSessionWithoutDelegate_delegateShouldntBeNil() async throws {
        givenURLSessionInitWithDelegateSwizzler()
        try await givenSwizzlingWasDone()
        whenInitializingURLSessionWithoutDelegate()
        thenSessionsDelegateShouldBeAnEmbracesProxy()
    }

    func test_onInitWithHandler_defaultBaseClassIsURLSession() throws {
        givenURLSessionInitWithDelegateSwizzler()
        thenBaseClassShouldBeURLSession()
    }

    func test_unsupportedDelegates() async throws {
        givenURLSessionInitWithDelegateSwizzler()
        try await givenSwizzlingWasDone()
        whenInitializingURLSessionWithDelegate(GTMSessionFetcher())
        thenSessionsDelegateShouldntBeEmbracesProxy()
        XCTAssertTrue(session.delegate.self is GTMSessionFetcher)
    }

    func test_preventProxyingOurselves() async throws {
        givenURLSessionInitWithDelegateSwizzler()
        try await givenSwizzlingWasDone()
        whenInitializingURLSessionWithPreviouslySwizzledProxy()
        thenSessionsDelegateShouldBeAnEmbracesProxy()
        thenSessionDelegateShouldBePreviouslySwizzledProxy()
    }
}

extension URLSessionInitWithDelegateSwizzlerTests {
    fileprivate func givenURLSessionInitWithDelegateSwizzler() {
        let handler = MockURLSessionTaskHandler()
        sut = URLSessionInitWithDelegateSwizzler(handler: handler)
    }

    @MainActor
    fileprivate func givenSwizzlingWasDone() throws {
        try sut.install()
    }

    fileprivate func whenInitializingURLSessionWithDelegate(_ delegate: URLSessionDelegate = DummyURLSessionDelegate()) {
        session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil)
    }

    fileprivate func whenInitializingURLSessionWithPreviouslySwizzledProxy() {
        previouslySwizzledProxy = EmbraceMakeURLSessionDelegateProxy(nil, MockURLSessionTaskHandler())
        whenInitializingURLSessionWithDelegate(previouslySwizzledProxy)
    }

    fileprivate func whenInitializingURLSessionWithoutDelegate() {
        session = URLSession(configuration: .default)
    }

    fileprivate func thenSessionsDelegateShouldntBeDummyDelegate() {
        XCTAssertFalse(session.delegate.self is DummyURLSessionDelegate)
    }

    fileprivate func thenSessionsDelegateShouldBeAnEmbracesProxy() {
        XCTAssertTrue(session.delegate.self is EMBURLSessionDelegateProxy)
    }

    fileprivate func thenSessionsDelegateShouldntBeEmbracesProxy() {
        XCTAssertFalse(session.delegate.self is EMBURLSessionDelegateProxy)
    }

    fileprivate func thenSessionDelegateShouldBePreviouslySwizzledProxy() {
        XCTAssertTrue(session.delegate === previouslySwizzledProxy)
    }

    fileprivate func thenBaseClassShouldBeURLSession() {
        XCTAssertTrue(sut.baseClass == URLSession.self)
    }
}

// unsupported delegates
final class GTMSessionFetcher: NSObject, URLSessionDelegate {}
