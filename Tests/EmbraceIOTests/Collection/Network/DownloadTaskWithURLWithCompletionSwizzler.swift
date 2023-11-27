//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//


import XCTest
import TestSupport

@testable import EmbraceIO

class DownloadTaskWithURLWithCompletionSwizzlerTests: XCTestCase {
    private var handler: MockURLSessionTaskHandler!
    private var sut: DownloadTaskWithURLWithCompletionSwizzler!
    private var session: URLSession!
    private var request: URLRequest!

    private var downloadTask: URLSessionDownloadTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    func testAfterInstall_onExecutingRequest_taskWillBeCreatedInHandler() throws {
        let expectation = expectation(description: #function)
        givenDownloadTaskWithURLRequestAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { _, _, _ in
            self.thenHandlerShouldHaveInvokedCreateWithTask()
            expectation.fulfill()
        })
        wait(for: [expectation])
    }

    func testAfterInstall_onFinishingRequest_taskWillBeFinishedInHandler() throws {
        let expectation = expectation(description: #function)
        givenDownloadTaskWithURLRequestAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { _, _, _ in
            self.thenHandlerShouldHaveInvokedFinishTask()
            expectation.fulfill()
        })
        wait(for: [expectation])
    }

    func testAfterInstall_onFailedRequest_taskWillBeFinishedInHandler() throws {
        let expectation = expectation(description: #function)
        givenDownloadTaskWithURLRequestAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenFailedRequest()
        givenProxiedUrlSession()
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { _, _, _ in
            self.thenHandlerShouldHaveInvokedFinishTaskWithError()
            expectation.fulfill()
        })
        wait(for: [expectation])
    }

    func test_afterInstall_taskShouldHaveEmbraceHeaders() throws {
        let expectation = expectation(description: #function)
        givenDownloadTaskWithURLRequestAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { _, _, _ in
            // swiftlint:disable force_try
            try! self.thenDataTaskShouldHaveEmbraceHeaders()
            // swiftlint:enable force_try
            expectation.fulfill()
        })
        wait(for: [expectation])
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() throws {
        let expectation = expectation(description: #function)
        givenDownloadTaskWithURLRequestAndCompletionSwizzler()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { _, _, _ in
            self.thenHandlerShouldntHaveInvokedCreate()
            expectation.fulfill()
        })
        wait(for: [expectation])
    }
}

private extension DownloadTaskWithURLWithCompletionSwizzlerTests {
    func givenDownloadTaskWithURLRequestAndCompletionSwizzler() {
        handler = MockURLSessionTaskHandler()
        sut = DownloadTaskWithURLWithCompletionSwizzler(handler: handler)
    }

    func givenSwizzlingWasDone() throws {
        try sut.install()
    }

    func givenSuccessfulRequest() {
        var url = URL(string: "https://embrace.io")!
        let mockData = "Mock Data".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .sucessful(withData: mockData, response: mockResponse)
        request = URLRequest(url: url)
        request.httpMethod = "POST"
    }

    func givenFailedRequest() {
        var url = URL(string: "https://embrace.io")!
        let error = NSError(domain: UUID().uuidString, code: 0)
        let mockResponse = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .failure(withError: error, response: mockResponse)
        request = URLRequest(url: url)
        request.httpMethod = "POST"
    }

    func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    func whenInvokingDownloadTaskWithURLRequest(completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) {
        downloadTask = session.downloadTask(with: request) { url, response, error in
            completionHandler(url, response, error)

        }
        downloadTask.resume()
    }

    func thenHandlerShouldHaveInvokedCreateWithTask() {
        XCTAssertTrue(handler.didInvokeCreate)
        XCTAssertEqual(handler.createReceivedTask, downloadTask)
    }

    func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }

    func thenHandlerShouldHaveInvokedFinishTask() {
        XCTAssertTrue(handler.didInvokeFinish)
        XCTAssertNotNil(handler.finishReceivedParameters?.1)
    }

    func thenHandlerShouldHaveInvokedFinishTaskWithError() {
        XCTAssertTrue(handler.didInvokeFinish)
        XCTAssertNotNil(handler.finishReceivedParameters?.2)
    }

    func thenDataTaskShouldHaveEmbraceHeaders() throws {
        let headers = try XCTUnwrap(downloadTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }
}
