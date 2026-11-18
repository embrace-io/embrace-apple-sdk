//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCore

class UploadTaskWithRequestFromFileWithCompletionSwizzlerTests: SwizzlerTestCase {
    private var handler: MockURLSessionTaskHandler!
    private var stubSession: StubURLSession!
    private var sut: UploadTaskWithRequestFromFileWithCompletionSwizzler!
    private var session: URLSession!
    private var request: URLRequest!

    private var uploadTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
        try super.tearDownWithError()
    }

    func testAfterInstall_onExecutingRequest_taskWillBeCreatedInHandler() throws {
        givenUploadTaskWithRequestFromFileAndCompletionSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenStubSession()
        whenInvokingUploadTaskWithURLRequestFromFile(completionHandler: { _, _, _ in }, resume: false)
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func testAfterInstall_onFinishingRequest_taskWillBeFinishedInHandler() throws {
        givenUploadTaskWithRequestFromFileAndCompletionSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenStubSession()
        var didCallCompletion = false
        whenInvokingUploadTaskWithURLRequestFromFile(completionHandler: { _, _, _ in didCallCompletion = true }, resume: false)
        try whenTheSessionFinishesSuccessfully()
        thenHandlerShouldHaveInvokedFinishTask()
        XCTAssertTrue(didCallCompletion)
    }

    func testAfterInstall_onFailedRequest_taskWillBeFinishedInHandler() throws {
        givenUploadTaskWithRequestFromFileAndCompletionSwizzler(baseClass: StubURLSession.self)
        try givenSwizzlingWasDone()
        givenFailedRequest()
        givenStubSession()
        var didCallCompletion = false
        whenInvokingUploadTaskWithURLRequestFromFile(completionHandler: { _, _, _ in didCallCompletion = true }, resume: false)
        whenTheSessionFails()
        thenHandlerShouldHaveInvokedFinishTaskWithError()
        XCTAssertTrue(didCallCompletion)
    }

    func test_afterInstall_taskShouldHaveEmbraceHeaders() throws {
        givenUploadTaskWithRequestFromFileAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingUploadTaskWithURLRequestFromFile(completionHandler: { _, _, _ in })
        try thenDataTaskShouldHaveEmbraceHeaders()
        uploadTask.cancel()
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() throws {
        givenUploadTaskWithRequestFromFileAndCompletionSwizzler()
        givenProxiedUrlSession()
        givenSuccessfulRequest()
        whenInvokingUploadTaskWithURLRequestFromFile(completionHandler: { _, _, _ in })
        thenHandlerShouldntHaveInvokedCreate()
        uploadTask.cancel()
    }
}

extension UploadTaskWithRequestFromFileWithCompletionSwizzlerTests {
    fileprivate func givenUploadTaskWithRequestFromFileAndCompletionSwizzler(baseClass: AnyClass = URLSession.self) {
        handler = MockURLSessionTaskHandler()
        sut = UploadTaskWithRequestFromFileWithCompletionSwizzler(handler: handler, baseClass: baseClass)
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
        let response = HTTPURLResponse(url: URL(string: "https://embrace.io")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        stubSession.completeDataTask(data: Data("Mock Data".utf8), response: response, error: nil)
    }

    fileprivate func whenTheSessionFails() {
        let response = HTTPURLResponse(url: URL(string: "https://embrace.io")!, statusCode: 400, httpVersion: nil, headerFields: nil)
        stubSession.completeDataTask(data: nil, response: response, error: NSError(domain: UUID().uuidString, code: 0))
    }

    fileprivate func whenInvokingUploadTaskWithURLRequestFromFile(
        completionHandler: @escaping ((Data?, URLResponse?, Error?) -> Void),
        resume: Bool = true
    ) {
        let dummyFile = Bundle.module.url(forResource: "dummy", withExtension: "json", subdirectory: "Mocks")!
        uploadTask = session.uploadTask(
            with: request,
            fromFile: dummyFile,
            completionHandler: { data, response, error in

                completionHandler(data, response, error)
            })
        if resume {
            uploadTask.resume()
        }
    }

    fileprivate func thenHandlerShouldHaveInvokedCreateWithTask() {
        handler.verifyCreated(uploadTask)
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
        let headers = try XCTUnwrap(uploadTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }

    fileprivate func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }
}
