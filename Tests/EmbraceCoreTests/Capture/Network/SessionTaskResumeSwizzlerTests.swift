//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCommonInternal
@testable import EmbraceCore

class SessionTaskResumeSwizzlerTests: XCTestCase, @unchecked Sendable {
    private var session: URLSession!
    private var sut: SessionTaskResumeSwizzler!
    private var handler: MockURLSessionTaskHandler!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    func test_afterInstall_taskWillBeCreatedInHandler() async throws {
        givenSessionTaskResumeSwizzler()
        try await givenSwizzlingWasDone()
        givenProxiedUrlSession()
        try await whenInvokingDataTaskResume()
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() async throws {
        givenSessionTaskResumeSwizzler()
        givenProxiedUrlSession()
        try await whenInvokingDataTaskResume()
        thenHandlerShouldntHaveInvokedCreate()
    }
}

extension SessionTaskResumeSwizzlerTests {
    fileprivate func givenSessionTaskResumeSwizzler() {
        handler = MockURLSessionTaskHandler()
        sut = SessionTaskResumeSwizzler(handler: handler)
    }

    @MainActor
    fileprivate func givenSwizzlingWasDone() async throws {
        try sut.install()
    }

    fileprivate func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    fileprivate func whenInvokingDataTaskResume() async throws {
        var url = URL(string: "https://embrace.io")!
        let mockData = "Mock Data".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .successful(withData: mockData, response: mockResponse)

        _ = try await session.data(from: url)
    }

    fileprivate func thenHandlerShouldHaveInvokedCreateWithTask() {
        XCTAssertTrue(handler.didInvokeCreate)
    }

    fileprivate func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }
}
