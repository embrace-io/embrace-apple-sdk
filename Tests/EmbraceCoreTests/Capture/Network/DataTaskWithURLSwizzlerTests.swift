//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCommonInternal
@testable import EmbraceCore

class DataTaskWithURLSwizzlerTests: XCTestCase {
    private var session: URLSession!
    private var sut: DataTaskWithURLSwizzler!
    private var sut2: DataTaskWithURLRequestSwizzler!
    private var handler: MockURLSessionTaskHandler!
    private var dataTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    @MainActor
    func test_afterInstall_taskWillBeCreatedInHandler() async throws {
        givenDataTaskWithURLSwizzler()
        try await givenSwizzlingWasDone()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl()
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() throws {
        givenDataTaskWithURLSwizzler()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl()
        thenHandlerShouldntHaveInvokedCreate()
    }
}

extension DataTaskWithURLSwizzlerTests {
    fileprivate func givenDataTaskWithURLSwizzler() {
        handler = MockURLSessionTaskHandler()
        sut = DataTaskWithURLSwizzler(handler: handler)
        sut2 = DataTaskWithURLRequestSwizzler(handler: handler)
    }

    @MainActor
    fileprivate func givenSwizzlingWasDone() async throws {
        try sut.install()
        try sut2.install()
    }

    fileprivate func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    fileprivate func whenInvokingDataTaskWithUrl() {
        var url = URL(string: "https://embrace.io")!
        let mockData = "Mock Data".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .successful(withData: mockData, response: mockResponse)
        dataTask = session.dataTask(with: url)
        dataTask.resume()
    }

    fileprivate func thenHandlerShouldHaveInvokedCreateWithTask() {
        XCTAssertTrue(handler.didInvokeCreate)
        XCTAssertEqual(handler.createReceivedTask, dataTask)
    }

    fileprivate func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }
}
