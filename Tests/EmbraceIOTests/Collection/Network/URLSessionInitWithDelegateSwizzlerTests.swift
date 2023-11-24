//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceIO

class DummyURLSessionDelegate: NSObject, URLSessionDelegate {

}

class URLSessionInitWithDelegateSwizzlerTests: XCTestCase {
    func testAfterInstall_onCreateURLSessionWithDelegate_originalShouldBeWrapped() throws {
        let handler = MockURLSessionTaskHandler()
        let sut = URLSessionInitWithDelegateSwizzler(handler: handler)
        try sut.install()
        let originalDelegate = DummyURLSessionDelegate()
        let session = URLSession(configuration: .default,
                                 delegate: originalDelegate,
                                 delegateQueue: nil)
        XCTAssertFalse(session.delegate.self is DummyURLSessionDelegate)
        XCTAssertTrue(session.delegate.self is URLSessionDelegateProxy)
    }
    
    /// This test reflects something _I_ consider as a bug. We should add ourselves as
    /// a delegate when there's none.
    func testAfterInstall_onCreateURLSessionWithoutDelegate_delegateShouldBeNil() throws {
        let handler = MockURLSessionTaskHandler()
        let sut = URLSessionInitWithDelegateSwizzler(handler: handler)
        try sut.install()
        let session = URLSession(configuration: .default)
        XCTAssertNil(session.delegate)
    }

    func test_onInitWithHandler_defaultBaseClassIsURLSession() throws {
        let handler = MockURLSessionTaskHandler()
        let sut = URLSessionInitWithDelegateSwizzler(handler: handler)
        XCTAssertTrue(sut.baseClass == URLSession.self)
    }
}
