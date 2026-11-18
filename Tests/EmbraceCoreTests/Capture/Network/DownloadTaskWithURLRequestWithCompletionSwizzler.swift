//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCore

class DownloadTaskWithURLWithCompletionSwizzlerTests: SwizzlerTestCase {
    private var handler: MockURLSessionTaskHandler!
    private var stubSession: StubURLSession!
    private var sut: DownloadTaskWithURLRequestWithCompletionSwizzler!
    private var session: URLSession!
    private var request: URLRequest!

    private var downloadTask: URLSessionDownloadTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
        try super.tearDownWithError()
    }

    func testAfterInstall_onExecutingRequest_taskWillBeCreatedInHandler() throws {
        givenDownloadTaskWithURLRequestAndCompletionSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenStubSession()
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { _, _, _ in }, resume: false)
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func testAfterInstall_onFinishingRequest_taskWillBeFinishedInHandler() throws {
        givenDownloadTaskWithURLRequestAndCompletionSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenStubSession()
        var didCallCompletion = false
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { _, _, _ in didCallCompletion = true }, resume: false)
        try whenTheSessionFinishesSuccessfully()
        thenHandlerShouldHaveInvokedFinishTask()
        XCTAssertTrue(didCallCompletion)
    }

    func testAfterInstall_onFailedRequest_taskWillBeFinishedInHandler() throws {
        givenDownloadTaskWithURLRequestAndCompletionSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenFailedRequest()
        givenStubSession()
        var didCallCompletion = false
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { _, _, _ in didCallCompletion = true }, resume: false)
        whenTheSessionFails()
        thenHandlerShouldHaveInvokedFinishTaskWithError()
        XCTAssertTrue(didCallCompletion)
    }

    func test_afterInstall_taskShouldHaveEmbraceHeaders() throws {
        givenDownloadTaskWithURLRequestAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { _, _, _ in })
        try thenDataTaskShouldHaveEmbraceHeaders()
        downloadTask.cancel()
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() throws {
        givenDownloadTaskWithURLRequestAndCompletionSwizzler()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { _, _, _ in })
        thenHandlerShouldntHaveInvokedCreate()
        downloadTask.cancel()
    }
}

extension DownloadTaskWithURLWithCompletionSwizzlerTests {
    fileprivate func givenDownloadTaskWithURLRequestAndCompletionSwizzler(baseClass: AnyClass = URLSession.self) {
        handler = MockURLSessionTaskHandler()
        sut = DownloadTaskWithURLRequestWithCompletionSwizzler(handler: handler, baseClass: baseClass)
    }

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

    fileprivate func givenStubSession() {
        stubSession = StubURLSession()
        session = stubSession
    }

    fileprivate func whenTheSessionFinishesSuccessfully() throws {
        let location = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("Mock Data".utf8).write(to: location)
        defer { try? FileManager.default.removeItem(at: location) }
        let response = HTTPURLResponse(url: URL(string: "https://embrace.io")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        stubSession.completeDownloadTask(location: location, response: response, error: nil)
    }

    fileprivate func whenTheSessionFails() {
        let response = HTTPURLResponse(url: URL(string: "https://embrace.io")!, statusCode: 400, httpVersion: nil, headerFields: nil)
        stubSession.completeDownloadTask(location: nil, response: response, error: NSError(domain: UUID().uuidString, code: 0))
    }

    fileprivate func whenInvokingDownloadTaskWithURLRequest(
        completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void,
        resume: Bool = true
    ) {
        downloadTask = session.downloadTask(with: request) { url, response, error in
            completionHandler(url, response, error)

        }
        if resume {
            downloadTask.resume()
        }
    }

    fileprivate func thenHandlerShouldHaveInvokedCreateWithTask() {
        handler.verifyCreated(downloadTask)
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
