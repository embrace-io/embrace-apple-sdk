//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCore

class UploadTaskWithRequestFromDataAndCompletionSwizzlerTests: SwizzlerTestCase {
    fileprivate typealias Received = (Data?, URLResponse?, Error?)

    private var handler: MockURLSessionTaskHandler!
    private var stubSession: StubURLSession!
    private var sentData: Data?
    private var sentResponse: URLResponse?
    private var sentError: NSError?
    private var sut: UploadTaskWithRequestFromDataWithCompletionSwizzler!
    private var session: URLSession!
    private var request: URLRequest!

    private var uploadTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
        try super.tearDownWithError()
    }

    func testAfterInstall_onExecutingRequest_taskWillBeCreatedInHandler() throws {
        givenUploadTaskWithURLRequestAndCompletionSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenRequest()
        givenStubSession()
        whenInvokingUploadTaskWithURLRequest(completionHandler: { _, _, _ in }, resume: false)
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func testAfterInstall_onFinishingRequest_taskWillBeFinishedInHandler() throws {
        givenUploadTaskWithURLRequestAndCompletionSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenRequest()
        givenStubSession()
        var received: Received?
        whenInvokingUploadTaskWithURLRequest(completionHandler: { received = ($0, $1, $2) }, resume: false)
        whenTheSessionFinishesSuccessfully()
        thenHandlerShouldHaveInvokedFinishTask()
        thenTheCompletionShouldHaveReceivedWhatTheSessionSent(received)
    }

    func testAfterInstall_onFailedRequest_taskWillBeFinishedInHandler() throws {
        givenUploadTaskWithURLRequestAndCompletionSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenRequest()
        givenStubSession()
        var received: Received?
        whenInvokingUploadTaskWithURLRequest(completionHandler: { received = ($0, $1, $2) }, resume: false)
        whenTheSessionFails()
        thenHandlerShouldHaveInvokedFinishTaskWithError()
        thenTheCompletionShouldHaveReceivedWhatTheSessionSent(received)
    }

    func test_afterInstall_taskShouldHaveEmbraceHeaders() throws {
        givenUploadTaskWithURLRequestAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingUploadTaskWithURLRequest(completionHandler: { _, _, _ in })
        try thenDataTaskShouldHaveEmbraceHeaders()
        uploadTask.cancel()
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() throws {
        givenUploadTaskWithURLRequestAndCompletionSwizzler()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingUploadTaskWithURLRequest(completionHandler: { _, _, _ in })
        thenHandlerShouldntHaveInvokedCreate()
        uploadTask.cancel()
    }
}

extension UploadTaskWithRequestFromDataAndCompletionSwizzlerTests {
    fileprivate func givenUploadTaskWithURLRequestAndCompletionSwizzler(baseClass: AnyClass = URLSession.self) {
        handler = MockURLSessionTaskHandler()
        sut = UploadTaskWithRequestFromDataWithCompletionSwizzler(handler: handler, baseClass: baseClass)
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
        StubURLSession.assertOverrides(UploadTaskWithRequestFromDataWithCompletionSwizzler.selector)
        stubSession = StubURLSession.make()
        session = stubSession
    }

    fileprivate func whenTheSessionFinishesSuccessfully() {
        sentData = Data("Mock Data".utf8)
        sentResponse = HTTPURLResponse(url: URL(string: "https://embrace.io")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        stubSession.completeDataTask(data: sentData, response: sentResponse, error: nil)
    }

    fileprivate func whenTheSessionFails() {
        sentResponse = HTTPURLResponse(url: URL(string: "https://embrace.io")!, statusCode: 400, httpVersion: nil, headerFields: nil)
        sentError = NSError(domain: UUID().uuidString, code: 0)
        stubSession.completeDataTask(data: nil, response: sentResponse, error: sentError)
    }

    fileprivate func thenTheCompletionShouldHaveReceivedWhatTheSessionSent(
        _ received: Received?, file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let received else {
            return XCTFail("The completion wasn't called", file: file, line: line)
        }
        XCTAssertEqual(received.0, sentData, file: file, line: line)
        XCTAssertIdentical(received.1, sentResponse, file: file, line: line)
        XCTAssertIdentical(received.2 as NSError?, sentError, file: file, line: line)
    }

    fileprivate func whenInvokingUploadTaskWithURLRequest(
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void,
        resume: Bool = true
    ) {
        uploadTask = session.uploadTask(with: request, from: Data()) { data, response, error in
            completionHandler(data, response, error)
        }
        if resume {
            uploadTask.resume()
        }
    }

    fileprivate func thenHandlerShouldHaveInvokedCreateWithTask() {
        handler.verifyCreated(uploadTask)
    }

    fileprivate func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }

    fileprivate func thenHandlerShouldHaveInvokedFinishTask() {
        XCTAssertTrue(handler.didInvokeFinishWithData)
        XCTAssertNotNil(handler.finishWithDataReceivedParameters?.1)
        XCTAssertIdentical(handler.finishWithDataReceivedParameters?.0, uploadTask)
    }

    fileprivate func thenHandlerShouldHaveInvokedFinishTaskWithError() {
        XCTAssertTrue(handler.didInvokeFinishWithData)
        XCTAssertNotNil(handler.finishWithDataReceivedParameters?.2)
        XCTAssertIdentical(handler.finishWithDataReceivedParameters?.0, uploadTask)
    }

    fileprivate func thenDataTaskShouldHaveEmbraceHeaders() throws {
        let headers = try XCTUnwrap(uploadTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }
}
