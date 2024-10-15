//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
@testable import EmbraceCore
@testable import EmbraceCommonInternal

class SessionTaskResumeSwizzlerTests: XCTestCase {
    private var session: URLSession!
    private var sut: SessionTaskResumeSwizzler!
    private var handler: MockURLSessionTaskHandler!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    func test_afterInstall_taskWillBeCreatedInHandler() async throws {
        givenSessionTaskResumeSwizzler()
        try givenSwizzlingWasDone()
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

private extension SessionTaskResumeSwizzlerTests {
    func givenSessionTaskResumeSwizzler() {
        handler = MockURLSessionTaskHandler()
        sut = SessionTaskResumeSwizzler(handler: handler)
    }

    func givenSwizzlingWasDone() throws {
        try sut.install()
    }

    func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    func whenInvokingDataTaskResume() async throws {
        var url = URL(string: "https://embrace.io")!
        let mockData = "Mock Data".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .successful(withData: mockData, response: mockResponse)

        _ = try await session.data(from: url)
    }

    func thenHandlerShouldHaveInvokedCreateWithTask() {
        XCTAssertTrue(handler.didInvokeCreate)
    }

    func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }
}
