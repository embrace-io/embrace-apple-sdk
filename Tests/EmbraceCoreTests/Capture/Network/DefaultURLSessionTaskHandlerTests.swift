//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommonInternal
import EmbraceOTelInternal
import OpenTelemetrySdk

@testable import EmbraceCaptureService
@testable import EmbraceCore

// swiftlint:disable line_length

class DefaultURLSessionTaskHandlerTests: XCTestCase {
    private var sut: DefaultURLSessionTaskHandler!
    private var task: URLSessionDataTask!
    private var session: URLSession!
    private var dataSource: MockURLSessionTaskHandlerDataSource!
    private var networkPayloadCapture: SpyNetworkPayloadCaptureHandler!
    private var otel: MockEmbraceOpenTelemetry!

    override func setUpWithError() throws {
        session = ProxiedURLSessionProvider.default()

        otel = MockEmbraceOpenTelemetry()

        dataSource = MockURLSessionTaskHandlerDataSource()
        dataSource.otel = otel
        dataSource.ignoredURLs = []

        networkPayloadCapture = SpyNetworkPayloadCaptureHandler()
    }

    // MARK: - Create Tests

    func test_onCreateTaskWithHandlerNotListening_ShouldntCreateSpan() {
        givenTaskHandler()
        givenStateChanged(toState: .paused)
        givenAnURLSessionTask()
        whenInvokingCreate(withoutWaiting: true)
        thenNoSpanShouldBeCreated()
    }

    func test_onCreateTask_ShouldBuildAndStartANetworkHTTPSpan() {
        givenTaskHandler()
        givenAnURLSessionTask()
        whenInvokingCreate()
        thenHTTPNetworkSpanShouldBeCreated()
    }

    func test_onCreateTaskWithUrlAndHTTPMethod_SpanNameShouldContainUrlPathAndMethod() {
        givenTaskHandler()
        givenAnURLSessionTask(urlString: "https://ThisIsAUrl/with/some/path", method: "POST")
        whenInvokingCreate()
        thenSpanName(is: "POST /with/some/path")
    }

    func test_onCreateTaskWithoutMethod_SpanNameShouldOnlyBePath() {
        givenTaskHandler()
        givenAnURLSessionTask(urlString: "https://embrace.io/with/path", method: "")
        whenInvokingCreate()
        thenSpanName(is: "/with/path")
    }

    func test_onCreateTask_UrlShouldBeSetOnSpanAsAttribute() {
        givenTaskHandler()
        givenAnURLSessionTask(urlString: "https://embrace-is-great.io")
        whenInvokingCreate()
        thenSpanShouldHaveURLAttribute(withValue: "https://\(testName).embrace-is-great.io")
    }

    func test_onCreateTaskHavingMethod_HttpMethodShouldBeSetOnSpanAsAttribute() {
        givenTaskHandler()
        givenAnURLSessionTask(method: "GET")
        whenInvokingCreate()
        thenSpanShouldHaveHttpMethodAttribute(withValue: "GET")
    }

    func test_onCreateTaskWithBody_BodySizeShouldBeSetOnSpanAsAttribute() {
        let randomData = UUID().uuidString.data(using: .utf8)!
        givenTaskHandler()
        givenAnURLSessionTask(method: "POST", body: randomData)
        whenInvokingCreate()
        thenSpanShouldHaveBodySizeAttribute(withValue: randomData.count)
    }

    // MARK: - Finish Test

    func test_onFinishTaskWithData_ResponseBodySizeShouldBeSetOnSpanAsAttribute() {
        let randomData = UUID().uuidString.data(using: .utf8)!
        givenTaskHandler()
        givenHandlerCreatedASpan()
        whenInvokingFinish(withData: randomData)
        thenSpanShouldHaveResponseBodySizeAttribute(withValue: randomData.count)
    }

    func test_onFinishTaskWithHandlerNotListening_ShouldntEndSpan() {
        givenTaskHandler()
        givenHandlerCreatedASpan()
        waitForCreationToEnd()
        givenStateChanged(toState: .paused)
        whenInvokingFinish(withoutWaiting: true)
        thenSpanShouldntEnd()
    }

    func test_onFinishWithoutHavingPreviousTasks_ShouldntEndAnySpan() {
        givenTaskHandler()
        givenAnURLSessionTask()
        whenInvokingFinish(withoutWaiting: true)
        thenSpanShouldntEnd()
    }

    func test_onFinishWithValidResponse_StatusCodeShouldSetOnSpanAsAttribute() {
        givenTaskHandler()
        givenHandlerCreatedASpan(withResponse: aValidResponse(withStatusCode: 201))
        whenInvokingFinish()
        thenSpanShouldHaveStatusCodeAttribute(withValue: 201)
    }

    func test_onFinishWithError_AllErrorFieldsOnSpanShouldBeFilled() {
        givenTaskHandler()
        givenHandlerCreatedASpan()
        whenInvokingFinish(error: NSError(domain: "RequestDomain", code: 1234, userInfo: [NSLocalizedDescriptionKey: "Sad Error!"]))
        thenSpanShouldHaveErrorDomainAttribute(withValue: "RequestDomain")
        thenSpanShouldHaveErrorCodeAttribute(withValue: 1234)
        thenSpanShouldHaveErrorMessageAttribute(withValue: "Sad Error!")
    }

    // MARK: - Tracing header

    func test_configsEnabled_tracingHeaderIncluded() {
        givenTaskHandler()
        givenTracingHeaderEnabled(true)
        givenAnURLSessionTask(method: "GET")
        whenInvokingCreate()
        thenOriginalRequestShouldHaveTheTracingHeader()
        whenInvokingFinish()
        thenSpanShouldHaveTheTracingHeaderAttribute()
    }

    func test_configsDisabled_tracingHeaderNotIncluded() {
        givenTaskHandler()
        givenTracingHeaderEnabled(false)
        givenAnURLSessionTask(method: "GET")
        whenInvokingCreate()
        thenOriginalRequestShouldNotHaveTheTracingHeader()
        whenInvokingFinish()
        thenSpanShouldNotHaveTheTracingHeaderAttribute()
    }

    // MARK: - Requests Data Source

    func test_requestsDataSource_path() {
        givenTaskHandler()
        givenRequestsDataSourceWithBlock { originalRequest in
            var request = originalRequest
            request.url = URL(string: "https://www.test.com")
            return request
        }
        givenAnURLSessionTask(method: "GET")
        whenInvokingCreate()
        whenInvokingFinish()
        thenSpanHasTheCorrectPath("https://www.test.com")
    }

    func test_requestsDataSource_method() {
        givenTaskHandler()
        givenRequestsDataSourceWithBlock { originalRequest in
            var request = originalRequest
            request.httpMethod = "POST"
            return request
        }
        givenAnURLSessionTask(method: "GET")
        whenInvokingCreate()
        whenInvokingFinish()
        thenSpanHasTheCorrectMethod("POST")
    }

    func test_requestsDataSource_bodySize() {
        givenTaskHandler()
        givenRequestsDataSourceWithBlock { originalRequest in
            var request = originalRequest
            request.httpBody = "test".data(using: .utf8)!
            return request
        }
        givenAnURLSessionTask(method: "GET")
        whenInvokingCreate()
        whenInvokingFinish()
        thenSpanHasTheCorrectBodySize(4)
    }

    func test_ignoredURLs_matches() {
        givenTaskHandler()
        givenIgnoredURLs()
        givenAnURLSessionTask()
        whenInvokingCreate(withoutWaiting: true)

        wait {
            return self.otel.spanProcessor.startedSpans.count == 0
        }
    }

    func test_ignoredURLs_no_match() {
        givenTaskHandler()
        givenIgnoredURLs()
        givenAnURLSessionTask(urlString: "https://ThisIsAUrl/with/some/path")
        whenInvokingCreate()
        thenHTTPNetworkSpanShouldBeCreated()
    }

    // MARK: - AddData Tests

    func testOnPayloadCaptureDisabled_addData_doesntDoAnything() {
        givenNetworkPayloadCaptureIsDisabled()
        givenAnURLSessionTask()
        givenTaskHandler()
        whenInvokingAddData()
        thenTaskHasNoAssociatedData()
    }

    func testOnPayloadCaptureEnabled_addData_appendsDataToTask() {
        givenNetworkPayloadCaptureIsEnabled()
        givenAnURLSessionTask()
        givenTaskHandler()
        whenInvokingAddData("Hello".data(using: .utf8)!)
        whenInvokingAddData(" World".data(using: .utf8)!)
        thenTaskAssociatedDataIs("Hello World".data(using: .utf8)!)
    }

    func testBeingAccessedFromManyThreads_addData_appendsAllDataToTaskWithoutThreadingIssues() {
        givenNetworkPayloadCaptureIsEnabled()
        givenAnURLSessionTask()
        givenTaskHandler()
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            whenInvokingAddData("a".data(using: .utf8)!)
            // This verifies that both getter and setter access to `embraceData` are handled in a thread-safe manner.
            thenTaskHasAssociatedData()
        }
        thenTaskAssociatedDataIs(String(repeating: "a", count: 100).data(using: .utf8)!)
    }
}

private extension DefaultURLSessionTaskHandlerTests {
    func givenTaskHandler() {
        dataSource.state = .active
        sut = DefaultURLSessionTaskHandler(
            processingQueue: MockQueue(),
            dataSource: dataSource,
            payloadCaptureHandler: networkPayloadCapture
        )
    }

    func givenStateChanged(toState: CaptureServiceState) {
        dataSource.state = toState
    }

    func givenNetworkPayloadCaptureIsDisabled() {
        networkPayloadCapture.stubbedIsEnabled = false
    }

    func givenNetworkPayloadCaptureIsEnabled() {
        networkPayloadCapture.stubbedIsEnabled = true
    }

    func givenTracingHeaderEnabled(_ enabled: Bool) {
        dataSource.injectTracingHeader = enabled
    }

    func givenRequestsDataSourceWithBlock(_ block: @escaping (URLRequest) -> URLRequest) {
        let requestsDataSource = MockURLSessionRequestsDataSource()
        requestsDataSource.block = block
        dataSource.requestsDataSource = requestsDataSource
    }

    func givenIgnoredURLs() {
        dataSource.ignoredURLs = ["embrace.io"]
    }

    func givenHandlerCreatedASpan(withResponse response: URLResponse? = nil) {
        givenAnURLSessionTask(response: response)
        sut.create(task: task)
    }

    func givenAnURLSessionTask(urlString: String = "https://embrace.io", method: String? = nil, body: Data? = nil, response: URLResponse? = nil) {
        var url = URL(string: urlString.replacingOccurrences(of: "https://", with: "https://\(testName)."))!
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body = body {
            request.httpBody = body
        }
        let urlResponse = response ?? aValidResponse()
        url.mockResponse = .successful(withData: UUID().uuidString.data(using: .utf8)!, response: urlResponse)
        task = session.dataTask(with: request)
    }

    func whenInvokingCreate(withoutWaiting: Bool = false) {
        sut.create(task: task)
        if !withoutWaiting {
            waitForCreationToEnd()
        }
    }

    func whenInvokingAddData(_ data: Data = Data()) {
        sut.addData(data, dataTask: task)
    }

    func whenInvokingFinish(withData data: Data? = nil, error: Error? = nil, withoutWaiting: Bool = false) {
        task.resume()
        waitForRequestToFinish()
        sut.finish(task: task, data: data, error: error)
        if !withoutWaiting {
            waitForFinishMethodToEnd()
        }
    }

    func thenTaskHasNoAssociatedData() {
        XCTAssertNil(task.embraceData)
    }

    func thenTaskHasAssociatedData() {
        XCTAssertNotNil(task.embraceData)
    }

    func thenTaskAssociatedDataIs(_ data: Data) {
        XCTAssertNotNil(task.embraceData)
        XCTAssertEqual(task.embraceData, data)
    }

    func thenSpanShouldHaveResponseBodySizeAttribute(withValue size: Int) {
        do {
            let span = try XCTUnwrap(otel.spanProcessor.endedSpans.first)
            let methodAttribute = span.attributes["http.response.body.size"]
            XCTAssertNotNil(methodAttribute)
            XCTAssertEqual(methodAttribute?.description, String(size))
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenHTTPNetworkSpanShouldBeCreated() {
        do {
            let span = try XCTUnwrap(otel.spanProcessor.startedSpans.first)
            XCTAssertEqual(span.embType, .networkRequest)
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldHaveURLAttribute(withValue url: String) {
        do {
            let span = try XCTUnwrap(otel.spanProcessor.startedSpans.first)
            let savedUrl = span.attributes["url.full"]
            XCTAssertNotNil(savedUrl)
            XCTAssertEqual(savedUrl?.description, url)

        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenTaskHandlerState(is state: CaptureServiceState) {
        XCTAssertEqual(sut.dataSource?.state, state)
    }

    func thenNoSpanShouldBeCreated() {
        XCTAssertTrue(otel.spanProcessor.startedSpans.count == 0)
    }

    func thenSpanName(is spanName: String) {
        let span = otel.spanProcessor.startedSpans.first { $0.name == spanName }
        XCTAssertNotNil(span)
    }

    func thenSpanShouldHaveHttpMethodAttribute(withValue method: String) {
        do {
            let span = try XCTUnwrap(otel.spanProcessor.startedSpans.first)
            let methodAttribute = span.attributes["http.request.method"]
            XCTAssertNotNil(methodAttribute)
            XCTAssertEqual(methodAttribute?.description, method)
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldHaveBodySizeAttribute(withValue size: Int) {
        do {
            let span = try XCTUnwrap(otel.spanProcessor.startedSpans.first)
            let bodySizeAttribute = span.attributes["http.request.body.size"]
            XCTAssertNotNil(bodySizeAttribute)
            XCTAssertEqual(bodySizeAttribute?.description, String(size))
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldHaveStatusCodeAttribute(withValue statusCode: Int) {
        do {
            let span = try XCTUnwrap(otel.spanProcessor.endedSpans.first)
            let statusCodeAttribute = span.attributes["http.response.status_code"]
            XCTAssertNotNil(statusCodeAttribute)
            XCTAssertEqual(statusCodeAttribute?.description, String(statusCode))
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldHaveErrorDomainAttribute(withValue domain: String) {
        do {
            let span = try XCTUnwrap(otel.spanProcessor.endedSpans.first)
            let errroTypeAttribute = span.attributes["error.type"]
            XCTAssertNotNil(errroTypeAttribute)
            XCTAssertEqual(errroTypeAttribute?.description, domain)
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldHaveErrorCodeAttribute(withValue code: Int) {
        do {
            let span = try XCTUnwrap(otel.spanProcessor.endedSpans.first)
            let errorCodeAttribute = span.attributes["error.code"]
            XCTAssertNotNil(errorCodeAttribute)
            XCTAssertEqual(errorCodeAttribute?.description, String(code))
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldHaveErrorMessageAttribute(withValue message: String) {
        do {
            let span = try XCTUnwrap(otel.spanProcessor.endedSpans.first)
            let errorMessageAttribute = span.attributes["error.message"]
            XCTAssertNotNil(errorMessageAttribute)
            XCTAssertEqual(errorMessageAttribute?.description, message)
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldntEnd() {
        XCTAssertTrue(otel.spanProcessor.endedSpans.isEmpty)
    }

    func validateTracingHeaderForSpan(tracingHeader: String, span: SpanData) {
        let components = tracingHeader.components(separatedBy: "-")
        XCTAssertEqual(components[0], "00")

        XCTAssertEqual(components[1].count, 32)
        XCTAssertEqual(components[1], span.traceId.hexString)

        XCTAssertEqual(components[2].count, 16)
        XCTAssertEqual(components[2], span.spanId.hexString)

        XCTAssertEqual(components[3], "01")
    }

    func thenOriginalRequestShouldHaveTheTracingHeader() {
        do {
            let headers = task.originalRequest?.allHTTPHeaderFields
            XCTAssertNotNil(headers)

            let tracingHeader = headers!["traceparent"]
            XCTAssertNotNil(tracingHeader)

            let currentHeaders = task.currentRequest?.allHTTPHeaderFields
            XCTAssertNotNil(currentHeaders)

            let currentTracingHeader = currentHeaders!["traceparent"]
            XCTAssertNotNil(currentTracingHeader)

            let span = try XCTUnwrap(otel.spanProcessor.startedSpans.first)
            validateTracingHeaderForSpan(tracingHeader: tracingHeader!, span: span)
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenOriginalRequestShouldNotHaveTheTracingHeader() {
        let headers = task.originalRequest?.allHTTPHeaderFields
        XCTAssertNil(headers?["traceparent"])
    }

    func thenSpanShouldHaveTheTracingHeaderAttribute() {
        do {
            let span = try XCTUnwrap(otel.spanProcessor.endedSpans.first)

            let tracingHeader = span.attributes["emb.w3c_traceparent"]!.description
            validateTracingHeaderForSpan(tracingHeader: tracingHeader, span: span)

        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldNotHaveTheTracingHeaderAttribute() {
        do {
            let span = try XCTUnwrap(otel.spanProcessor.endedSpans.first)
            XCTAssertNil(span.attributes["emb.w3c_traceparent"])

        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanHasTheCorrectPath(_ path: String) {
        do {
            let span = try XCTUnwrap(otel.spanProcessor.endedSpans.first)

            XCTAssertEqual(span.attributes["url.full"], .string(path))
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanHasTheCorrectMethod(_ method: String) {
        do {
            let span = try XCTUnwrap(otel.spanProcessor.endedSpans.first)

            XCTAssertEqual(span.attributes["http.request.method"], .string(method))
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanHasTheCorrectBodySize(_ bodySize: Int) {
        do {
            let span = try XCTUnwrap(otel.spanProcessor.endedSpans.first)

            XCTAssertEqual(span.attributes["http.request.body.size"], .int(bodySize))
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }
}

// MARK: - Utility Methods
private extension DefaultURLSessionTaskHandlerTests {
    func aValidResponse(withStatusCode statusCode: Int = 200) -> HTTPURLResponse {
        .init(url: URL(string: "https://embrace.io")!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    func waitForCreationToEnd() {
        wait(timeout: 1.0, until: { self.otel.spanProcessor.startedSpans.count > 0 })
    }

    func waitForFinishMethodToEnd() {
        wait(timeout: 1.0, until: { self.otel.spanProcessor.endedSpans.count > 0 })
    }

    func waitForRequestToFinish() {
        wait(timeout: 1.0, until: { self.task.response != nil })
    }
}

// swiftlint:enable line_length
