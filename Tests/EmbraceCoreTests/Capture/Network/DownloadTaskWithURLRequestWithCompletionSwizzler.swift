//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCore

class DownloadTaskWithURLWithCompletionSwizzlerTests: SwizzlerTestCase {
    fileprivate typealias Received = (URL?, URLResponse?, Error?)

    private var handler: MockURLSessionTaskHandler!
    private var stubSession: StubURLSession!
    private var sentLocation: URL?
    private var sentResponse: URLResponse?
    private var sentError: NSError?
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
        givenRequest()
        givenStubSession()
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { _, _, _ in }, resume: false)
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func testAfterInstall_onFinishingRequest_taskWillBeFinishedInHandler() throws {
        givenDownloadTaskWithURLRequestAndCompletionSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenRequest()
        givenStubSession()
        var received: Received?
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { received = ($0, $1, $2) }, resume: false)
        try whenTheSessionFinishesSuccessfully()
        thenHandlerShouldHaveInvokedFinishTask()
        thenTheCompletionShouldHaveReceivedWhatTheSessionSent(received)
    }

    func testAfterInstall_onFailedRequest_taskWillBeFinishedInHandler() throws {
        givenDownloadTaskWithURLRequestAndCompletionSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenRequest()
        givenStubSession()
        var received: Received?
        whenInvokingDownloadTaskWithURLRequest(completionHandler: { received = ($0, $1, $2) }, resume: false)
        whenTheSessionFails()
        thenHandlerShouldHaveInvokedFinishTaskWithError()
        thenTheCompletionShouldHaveReceivedWhatTheSessionSent(received)
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

    fileprivate func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
    }

    fileprivate func givenRequest() {
        request = URLRequest(url: URL(string: "https://embrace.io")!)
        request.httpMethod = "POST"
    }

    fileprivate func givenStubSession() {
        StubURLSession.assertOverrides(DownloadTaskWithURLRequestWithCompletionSwizzler.selector)
        stubSession = StubURLSession.make()
        session = stubSession
    }

    fileprivate func whenTheSessionFinishesSuccessfully() throws {
        let location = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("Mock Data".utf8).write(to: location)
        defer { try? FileManager.default.removeItem(at: location) }
        sentLocation = location
        sentResponse = HTTPURLResponse(url: URL(string: "https://embrace.io")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        stubSession.completeDownloadTask(location: location, response: sentResponse, error: nil)
    }

    fileprivate func whenTheSessionFails() {
        sentResponse = HTTPURLResponse(url: URL(string: "https://embrace.io")!, statusCode: 400, httpVersion: nil, headerFields: nil)
        sentError = NSError(domain: UUID().uuidString, code: 0)
        stubSession.completeDownloadTask(location: nil, response: sentResponse, error: sentError)
    }

    fileprivate func thenTheCompletionShouldHaveReceivedWhatTheSessionSent(
        _ received: Received?, file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let received else {
            return XCTFail("The completion wasn't called", file: file, line: line)
        }
        XCTAssertEqual(received.0, sentLocation, file: file, line: line)
        XCTAssertIdentical(received.1, sentResponse, file: file, line: line)
        XCTAssertIdentical(received.2 as NSError?, sentError, file: file, line: line)
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
        XCTAssertIdentical(handler.finishWithDataReceivedParameters?.0, downloadTask)
        XCTAssertEqual(handler.finishWithDataReceivedParameters?.1, Data("Mock Data".utf8))
    }

    fileprivate func thenHandlerShouldHaveInvokedFinishTaskWithError() {
        XCTAssertTrue(handler.didInvokeFinishWithData)
        XCTAssertNotNil(handler.finishWithDataReceivedParameters?.2)
        XCTAssertIdentical(handler.finishWithDataReceivedParameters?.0, downloadTask)
    }

    fileprivate func thenDataTaskShouldHaveEmbraceHeaders() throws {
        let headers = try XCTUnwrap(downloadTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }
}
