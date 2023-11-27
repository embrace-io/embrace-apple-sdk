//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport

@testable import EmbraceIO

class DownloadTaskWithURLRequestSwizzlerTests: XCTestCase {
    private var handler: MockURLSessionTaskHandler!
    private var sut: DownloadTaskWithURLRequestSwizzler!
    private var session: URLSession!
    private var request: URLRequest!

    private var downloadTask: URLSessionDownloadTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    func test_afterInstall_taskWillBeCreatedInHandler() throws {
        givenDownloadTaskWithURLRequestSwizzler()
        try givenSwizzlingWasDone()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl()
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func test_afterInstall_taskShouldHaveEmbraceHeaders() throws {
        givenDownloadTaskWithURLRequestSwizzler()
        try givenSwizzlingWasDone()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl()
        try thenDataTaskShouldHaveEmbraceHeaders()
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() throws {
        givenDownloadTaskWithURLRequestSwizzler()
        givenProxiedUrlSession()
        whenInvokingDataTaskWithUrl()
        thenHandlerShouldntHaveInvokedCreate()
    }
}

private extension DownloadTaskWithURLRequestSwizzlerTests {
    func givenDownloadTaskWithURLRequestSwizzler() {
        handler = MockURLSessionTaskHandler()
        sut = DownloadTaskWithURLRequestSwizzler(handler: handler)
    }

    func givenSwizzlingWasDone() throws {
        try sut.install()
    }

    func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    func whenInvokingDataTaskWithUrl() {
        var url = URL(string: "https://embrace.io")!
        let request = URLRequest(url: url)
        let mockData = "Mock Data".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .sucessful(withData: mockData, response: mockResponse)
        downloadTask = session.downloadTask(with: request)
        downloadTask.resume()
    }

    func thenHandlerShouldHaveInvokedCreateWithTask() {
        XCTAssertTrue(handler.didInvokeCreate)
        XCTAssertEqual(handler.createReceivedTask, downloadTask)
    }

    func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }

    func thenDataTaskShouldHaveEmbraceHeaders() throws {
        let headers = try XCTUnwrap(downloadTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }
}
