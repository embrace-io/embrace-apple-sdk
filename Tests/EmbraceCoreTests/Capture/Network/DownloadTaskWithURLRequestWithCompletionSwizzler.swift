//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCore

class DownloadTaskWithURLWithCompletionSwizzlerTests: XCTestCase, @unchecked Sendable {
    private var handler: MockURLSessionTaskHandler!
    private var sut: DownloadTaskWithURLRequestWithCompletionSwizzler!
    private var session: URLSession!
    private var request: URLRequest!

    private var downloadTask: URLSessionDownloadTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    func testAfterInstall_onExecutingRequest_taskWillBeCreatedInHandler() async throws {
        let expectation = expectation(description: #function)
        givenDownloadTaskWithURLRequestAndCompletionSwizzler()
        try await givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { _, _, _ in
            self.thenHandlerShouldHaveInvokedCreateWithTask()
            expectation.fulfill()
        })
        await fulfillment(of: [expectation])
    }

    func testAfterInstall_onFinishingRequest_taskWillBeFinishedInHandler() async throws {
        let expectation = expectation(description: #function)
        givenDownloadTaskWithURLRequestAndCompletionSwizzler()
        try await givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { _, _, _ in
            self.thenHandlerShouldHaveInvokedFinishTask()
            expectation.fulfill()
        })
        await fulfillment(of: [expectation])
    }

    #if !os(watchOS)
        func testAfterInstall_onFailedRequest_taskWillBeFinishedInHandler() async throws {
            let expectation = expectation(description: #function)
            givenDownloadTaskWithURLRequestAndCompletionSwizzler()
            try await givenSwizzlingWasDone()
            givenFailedRequest()
            givenProxiedUrlSession()
            whenInvokingDownloadTaskWithURLRequest(completionHandler: { _, _, _ in
                self.thenHandlerShouldHaveInvokedFinishTaskWithError()
                expectation.fulfill()
            })
            await fulfillment(of: [expectation])
        }
    #endif

    func test_afterInstall_taskShouldHaveEmbraceHeaders() async throws {
        let expectation = expectation(description: #function)
        givenDownloadTaskWithURLRequestAndCompletionSwizzler()
        try await givenSwizzlingWasDone()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { _, _, _ in
            // swiftlint:disable force_try
            try! self.thenDataTaskShouldHaveEmbraceHeaders()
            // swiftlint:enable force_try
            expectation.fulfill()
        })
        await fulfillment(of: [expectation])
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

extension DownloadTaskWithURLWithCompletionSwizzlerTests {
    fileprivate func givenDownloadTaskWithURLRequestAndCompletionSwizzler() {
        handler = MockURLSessionTaskHandler()
        sut = DownloadTaskWithURLRequestWithCompletionSwizzler(handler: handler)
    }

    @MainActor
    fileprivate func givenSwizzlingWasDone() throws {
        try sut.install()
    }

    fileprivate func givenSuccessfulRequest() {
        var url = URL(string: "https://embrace.io")!
        let mockData = "Mock Data".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .successful(withData: mockData, response: mockResponse)
        request = URLRequest(url: url)
        request.httpMethod = "POST"
    }

    fileprivate func givenFailedRequest() {
        var url = URL(string: "https://embrace.io")!
        let error = NSError(domain: UUID().uuidString, code: 0)
        let mockResponse = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!
        url.mockResponse = .failure(withError: error, response: mockResponse)
        request = URLRequest(url: url)
        request.httpMethod = "POST"
    }

    fileprivate func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    fileprivate func whenInvokingDownloadTaskWithURLRequest(
        completionHandler: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void
    ) {
        downloadTask = session.downloadTask(with: request) { url, response, error in
            completionHandler(url, response, error)

        }
        downloadTask.resume()
    }

    fileprivate func thenHandlerShouldHaveInvokedCreateWithTask() {
        XCTAssertTrue(handler.didInvokeCreate)
        XCTAssertEqual(handler.createReceivedTask, downloadTask)
    }

    fileprivate func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }

    fileprivate func thenHandlerShouldHaveInvokedFinishTask() {
        XCTAssertTrue(handler.didInvokeFinishWithData)
        XCTAssertNotNil(handler.finishWithDataReceivedParameters?.1)
    }

    fileprivate func thenHandlerShouldHaveInvokedFinishTaskWithError() {
        XCTAssertTrue(handler.didInvokeFinishWithData)
        XCTAssertNotNil(handler.finishWithDataReceivedParameters?.2)
    }

    fileprivate func thenDataTaskShouldHaveEmbraceHeaders() throws {
        let headers = try XCTUnwrap(downloadTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }
}
