//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport

import EmbraceStorage
import EmbraceOTel
import EmbraceCommon

@testable import EmbraceCore

// swiflint:disable line_length

class DefaultURLSessionTaskHandlerTests: XCTestCase {
    private var sut: DefaultURLSessionTaskHandler!
    private var processor: MockSpanProcessor!
    private var task: URLSessionTask!
    private var otel: EmbraceOTel!
    private var session: URLSession!

    override func setUpWithError() throws {
        session = ProxiedURLSessionProvider.default()
        processor = MockSpanProcessor()
        EmbraceOTel.setup(spanProcessor: processor)
    }

    // MARK: - State Tests

    func test_HandlerDefaultStateIsInitialized() {
        XCTAssertEqual(DefaultURLSessionTaskHandler().state, .initialized)
    }

    func test_OnChangeStateToPaused_StateShouldChangeToPaused() {
        givenTaskHandler(withInitialState: .initialized)
        whenInvokingOnChangeState(withNewState: .paused)
        thenTaskHandlerState(is: .paused)
    }

    func test_OnChangeStateToUninstalled_StateShouldChangeToPaused() {
        givenTaskHandler(withInitialState: .initialized)
        whenInvokingOnChangeState(withNewState: .uninstalled)
        thenTaskHandlerState(is: .paused)
    }

    func test_OnChangeStateToListening_StateShouldChangeToListening() {
        givenTaskHandler(withInitialState: .initialized)
        whenInvokingOnChangeState(withNewState: .listening)
        thenTaskHandlerState(is: .listening)
    }

    // MARK: - Create Tests

    func test_onCreateTaskWithHandlerNotListening_ShouldntCreateSpan() {
        givenTaskHandler(withInitialState: .paused)
        givenAnURLSessionTask()
        whenInvokingCreate(withoutWaiting: true)
        thenNoSpanShouldBeCreated()
    }

    func test_onCreateTask_ShouldBuildAndStartANetworkHTTPSpan() {
        givenTaskHandler(withInitialState: .listening)
        givenAnURLSessionTask()
        whenInvokingCreate()
        thenHTTPNetworkSpanShouldBeCreated()
    }

    func test_onCreateTaskWithUrlAndHTTPMethod_SpanNameShouldContainUrlPathAndMethod() {
        givenTaskHandler(withInitialState: .listening)
        givenAnURLSessionTask(urlString: "https://ThisIsAUrl/with/some/path", method: "POST")
        whenInvokingCreate()
        thenSpanName(is: "POST /with/some/path")
    }

    func test_onCreateTaskWithoutMethod_SpanNameShouldOnlyBePath() {
        givenTaskHandler(withInitialState: .listening)
        givenAnURLSessionTask(urlString: "https://embrace.io/with/path/", method: "")
        whenInvokingCreate()
        thenSpanName(is: "/with/path")
    }

    func test_onCreateTask_UrlShouldBeSetOnSpanAsAttribute() {
        givenTaskHandler(withInitialState: .listening)
        givenAnURLSessionTask(urlString: "https://embrace-is-great.io")
        whenInvokingCreate()
        thenSpanShouldHaveURLAttribute(withValue: "https://embrace-is-great.io")
    }

    func test_onCreateTaskHavingMethod_HttpMethodShouldBeSetOnSpanAsAttribute() {
        givenTaskHandler(withInitialState: .listening)
        givenAnURLSessionTask(method: "GET")
        whenInvokingCreate()
        thenSpanShouldHaveHttpMethodAttribute(withValue: "GET")
    }

    func test_onCreateTaskWithBody_BodySizeShouldBeSetOnSpanAsAttribute() {
        let randomData = UUID().uuidString.data(using: .utf8)!
        givenTaskHandler(withInitialState: .listening)
        givenAnURLSessionTask(method: "POST", body: randomData)
        whenInvokingCreate()
        thenSpanShouldHaveBodySizeAttribute(withValue: randomData.count)
    }

    // MARK: - Finish Test

    func test_onFinishTaskWithData_ResponseBodySizeShouldBeSetOnSpanAsAttribute() {
        let randomData = UUID().uuidString.data(using: .utf8)!
        givenTaskHandler(withInitialState: .listening)
        givenHandlerCreatedASpan()
        whenInvokingFinish(withData: randomData)
        thenSpanShouldHaveResponseBodySizeAttribute(withValue: randomData.count)
    }

    func test_onFinishTaskWithHandlerNotListening_ShouldntEndSpan() {
        givenTaskHandler(withInitialState: .listening)
        givenHandlerCreatedASpan()
        waitForCreationToEnd()
        givenStateChanged(toState: .paused)
        whenInvokingFinish(withoutWaiting: true)
        thenSpanShouldntEnd()
    }

    func test_onFinishWithoutHavingPreviousTasks_ShouldntEndAnySpan() {
        givenTaskHandler(withInitialState: .listening)
        givenAnURLSessionTask()
        whenInvokingFinish(withoutWaiting: true)
        thenSpanShouldntEnd()
    }

    func test_onFinishWithValidResponse_StatusCodeShouldSetOnSpanAsAttribute() {
        givenTaskHandler(withInitialState: .listening)
        givenHandlerCreatedASpan(withResponse: aValidResponse(withStatusCode: 201))
        whenInvokingFinish()
        thenSpanShouldHaveStatusCodeAttribute(withValue: 201)
    }

    func test_onFinishWithError_AllErrorFieldsOnSpanShouldBeFilled() {
        givenTaskHandler(withInitialState: .listening)
        givenHandlerCreatedASpan()
        whenInvokingFinish(error: NSError(domain: "RequestDomain", code: 1234, userInfo: [NSLocalizedDescriptionKey: "Sad Error!"]))
        thenSpanShouldHaveErrorDomainAttribute(withValue: "RequestDomain")
        thenSpanShouldHaveErrorCodeAttribute(withValue: 1234)
        thenSpanShouldHaveErrorMessageAttribute(withValue: "Sad Error!")
    }
}

private extension DefaultURLSessionTaskHandlerTests {
    func givenTaskHandler(withInitialState initialState: CaptureServiceHandlerState = .initialized) {
        otel = .init()
        sut = .init(DefaultURLSessionTaskHandler(otel: otel, initialState: initialState, processingQueue: .main))
    }

    func givenStateChanged(toState: CaptureServiceState) {
        whenInvokingOnChangeState(withNewState: .paused)
    }

    func givenHandlerCreatedASpan(withResponse response: URLResponse? = nil) {
        givenAnURLSessionTask(response: response)
        sut.create(task: task)
    }

    func givenAnURLSessionTask(urlString: String = "https://embrace.io", method: String? = nil, body: Data? = nil, response: URLResponse? = nil) {
        var url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body = body {
            request.httpBody = body
        }
        let urlResponse = response ?? aValidResponse()
        url.mockResponse = .sucessful(withData: UUID().uuidString.data(using: .utf8)!, response: urlResponse)
        task = session.dataTask(with: request)
    }

    func whenInvokingOnChangeState(withNewState state: CaptureServiceState) {
        sut.changedState(to: state)
    }

    func whenInvokingCreate(withoutWaiting: Bool = false) {
        sut.create(task: task)
        if !withoutWaiting {
            waitForCreationToEnd()
        }
    }

    func whenInvokingFinish(withData data: Data? = nil, error: Error? = nil, withoutWaiting: Bool = false) {
        task.resume()
        waitForRequestToFinish()
        sut.finish(task: task, data: data, error: error)
        if !withoutWaiting {
            waitForFinishMethodToEnd()
        }
    }

    func thenSpanShouldHaveResponseBodySizeAttribute(withValue size: Int) {
        do {
            let span = try XCTUnwrap(processor.endedSpans.first)
            let methodAttribute = span.attributes["http.response.body.size"]
            XCTAssertNotNil(methodAttribute)
            XCTAssertEqual(methodAttribute?.description, String(size))
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenHTTPNetworkSpanShouldBeCreated() {
        do {
            let span = try XCTUnwrap(processor.startedSpans.first)
            XCTAssertEqual(span.embType, .networkHTTP)
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldHaveURLAttribute(withValue url: String) {
        do {
            let span = try XCTUnwrap(processor.startedSpans.first)
            let savedUrl = span.attributes["url.full"]
            XCTAssertNotNil(savedUrl)
            XCTAssertEqual(savedUrl?.description, url)

        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenTaskHandlerState(is state: CaptureServiceHandlerState) {
        XCTAssertEqual(sut.state, state)
    }

    func thenNoSpanShouldBeCreated() {
        XCTAssertTrue(processor.startedSpans.count == 0)
    }

    func thenSpanName(is spanName: String) {
        do {
            let span = try XCTUnwrap(processor.startedSpans.first)
            XCTAssertEqual(span.name, spanName)
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldHaveHttpMethodAttribute(withValue method: String) {
        do {
            let span = try XCTUnwrap(processor.startedSpans.first)
            let methodAttribute = span.attributes["http.request.method"]
            XCTAssertNotNil(methodAttribute)
            XCTAssertEqual(methodAttribute?.description, method)
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldHaveBodySizeAttribute(withValue size: Int) {
        do {
            let span = try XCTUnwrap(processor.startedSpans.first)
            let bodySizeAttribute = span.attributes["http.request.body.size"]
            XCTAssertNotNil(bodySizeAttribute)
            XCTAssertEqual(bodySizeAttribute?.description, String(size))
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldHaveStatusCodeAttribute(withValue statusCode: Int) {
        do {
            let span = try XCTUnwrap(processor.endedSpans.first)
            let statusCodeAttribute = span.attributes["http.response.status_code"]
            XCTAssertNotNil(statusCodeAttribute)
            XCTAssertEqual(statusCodeAttribute?.description, String(statusCode))
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldHaveErrorDomainAttribute(withValue domain: String) {
        do {
            let span = try XCTUnwrap(processor.endedSpans.first)
            let errroTypeAttribute = span.attributes["error.type"]
            XCTAssertNotNil(errroTypeAttribute)
            XCTAssertEqual(errroTypeAttribute?.description, domain)
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldHaveErrorCodeAttribute(withValue code: Int) {
        do {
            let span = try XCTUnwrap(processor.endedSpans.first)
            let errorCodeAttribute = span.attributes["error.code"]
            XCTAssertNotNil(errorCodeAttribute)
            XCTAssertEqual(errorCodeAttribute?.description, String(code))
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldHaveErrorMessageAttribute(withValue message: String) {
        do {
            let span = try XCTUnwrap(processor.endedSpans.first)
            let errorMessageAttribute = span.attributes["error.message"]
            XCTAssertNotNil(errorMessageAttribute)
            XCTAssertEqual(errorMessageAttribute?.description, message)
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldntEnd() {
        XCTAssertTrue(processor.endedSpans.isEmpty)
    }
}

// MARK: - Utility Methods
private extension DefaultURLSessionTaskHandlerTests {
    func aValidResponse(withStatusCode statusCode: Int = 200) -> HTTPURLResponse {
        .init(url: URL(string: "https://embrace.io")!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    func waitForCreationToEnd() {
        wait(timeout: 1.0, until: { self.processor.startedSpans.count > 0 })
    }

    func waitForFinishMethodToEnd() {
        wait(timeout: 1.0, until: { self.processor.endedSpans.count > 0 })
    }

    func waitForRequestToFinish() {
        wait(timeout: 1.0, until: { self.task.response != nil })
    }
}

// swiflint:enable line_length
