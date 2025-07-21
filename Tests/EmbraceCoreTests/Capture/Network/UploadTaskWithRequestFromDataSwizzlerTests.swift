//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCore

class UploadTaskWithRequestFromDataSwizzlerTests: XCTestCase {
    private var handler: MockURLSessionTaskHandler!
    private var sut: UploadTaskWithRequestFromDataSwizzler!
    private var session: URLSession!
    private var request: URLRequest!

    private var uploadTask: URLSessionDataTask!

    override func tearDownWithError() throws {
        try? sut.unswizzleInstanceMethod()
    }

    func test_afterInstall_taskWillBeCreatedInHandler() throws {
        givenUploadTaskWithURLRequestAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        whenInvokingUploadTaskWithRequestFromData()
        thenHandlerShouldHaveInvokedCreateWithTask()
    }

    func test_afterInstall_taskShouldHaveEmbraceHeaders() throws {
        givenUploadTaskWithURLRequestAndCompletionSwizzler()
        try givenSwizzlingWasDone()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        whenInvokingUploadTaskWithRequestFromData()
        try thenTaskShouldHaveEmbraceHeaders()
    }

    func test_withoutInstall_taskWontBeCreatedInHandler() {
        givenUploadTaskWithURLRequestAndCompletionSwizzler()
        givenSuccessfulRequest()
        givenProxiedUrlSession()
        whenInvokingUploadTaskWithRequestFromData()
        thenHandlerShouldntHaveInvokedCreate()
    }
}

extension UploadTaskWithRequestFromDataSwizzlerTests {
    fileprivate func givenUploadTaskWithURLRequestAndCompletionSwizzler() {
        handler = MockURLSessionTaskHandler()
        sut = UploadTaskWithRequestFromDataSwizzler(handler: handler)
    }

    fileprivate func givenSwizzlingWasDone() throws {
        try sut.install()
    }

    fileprivate func givenProxiedUrlSession() {
        session = ProxiedURLSessionProvider.default()
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

    fileprivate func whenInvokingUploadTaskWithRequestFromData() {
        uploadTask = session.uploadTask(with: request, from: Data())
        uploadTask.resume()
    }

    fileprivate func thenHandlerShouldHaveInvokedCreateWithTask() {
        XCTAssertTrue(handler.didInvokeCreate)
        XCTAssertEqual(handler.createReceivedTask, uploadTask)
    }

    fileprivate func thenHandlerShouldntHaveInvokedCreate() {
        XCTAssertFalse(handler.didInvokeCreate)
    }

    fileprivate func thenTaskShouldHaveEmbraceHeaders() throws {
        let headers = try XCTUnwrap(uploadTask.originalRequest?.allHTTPHeaderFields)
        XCTAssertNotNil(headers["x-emb-id"])
        XCTAssertNotNil(headers["x-emb-st"])
    }
}
