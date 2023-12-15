//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//


import XCTest
import TestSupport

import EmbraceStorage
import EmbraceOTel
import EmbraceCommon

@testable import EmbraceCore

class DefaultURLSessionTaskHandlerTests: XCTestCase {
    private var sut: DefaultURLSessionTaskHandler!
    private var processor: MockSpanProcessor!
    private var task: URLSessionTask!
    private var otel: EmbraceOTel!

    override func setUpWithError() throws {
        processor = MockSpanProcessor()
        EmbraceOTel.setup(spanProcessor: processor)
    }

    // MARK: - State Tests

    func testHandlerDefaultStateIsInitialized() {
        XCTAssertEqual(DefaultURLSessionTaskHandler().state, .initialized)
    }

    func test_OnChanceStateToPaused_stateShouldChangeToPaused() {
        givenTaskHandler(withInitialState: .initialized)
        whenInvokingOnChangeState(withNewState: .paused)
        thenTaskHandlerState(is: .paused)
    }

    func test_OnChanceStateToUninstalled_stateShouldChangeToPaused() {
        givenTaskHandler(withInitialState: .initialized)
        whenInvokingOnChangeState(withNewState: .uninstalled)
        thenTaskHandlerState(is: .paused)
    }

    func test_OnChanceStateToListening_stateShouldChangeToListening() {
        givenTaskHandler(withInitialState: .initialized)
        whenInvokingOnChangeState(withNewState: .listening)
        thenTaskHandlerState(is: .listening)
    }

    // MARK: - Create Tests

    func test_onCreateTaskWithHandlerNotListening_shouldntCreateSpan() {
        givenTaskHandler(withInitialState: .paused)
        givenAnURLSessionTask()
        whenInvokingCreate()
        thenNoSpanShouldBeCreated()
    }

    func test_onCreateTask_shouldBuildAndStartANetworkHTTPSpan() {
        givenTaskHandler(withInitialState: .listening)
        givenAnURLSessionTask()
        whenInvokingCreate()
        thenHTTPNetworkSpanShouldBeCreated()
    }

    func test_onCreateTaskWithUrlAndHTTPMethod_spanNameShouldContainUrlPathAndMethod() {
        givenTaskHandler(withInitialState: .listening)
        givenAnURLSessionTask(urlString: "https://ThisIsAUrl/with/some/path", method: "POST")
        whenInvokingCreate()
        thenSpanName(is: "POST /with/some/path")
    }

    func test_onCreateTaskWithoutMethod_spanNameShouldOnlyBePath() {
        givenTaskHandler(withInitialState: .listening)
        givenAnURLSessionTask(urlString: "https://embrace.io/with/path/", method: "")
        whenInvokingCreate()
        thenSpanName(is: "/with/path")
    }

    func test_onCreateTask_urlShouldBeSetOnSpanAsAttribute() {
        givenTaskHandler(withInitialState: .listening)
        givenAnURLSessionTask(urlString: "https://embrace-is-great.io")
        whenInvokingCreate()
        thenSpanShouldHaveURLAttribute(withValue: "https://embrace-is-great.io")
    }

    func test_onCreateTaskHavingMethod_httpMethodShouldBeSetOnSpanAsAttribute() {
        givenTaskHandler(withInitialState: .listening)
        givenAnURLSessionTask(method: "GET")
        whenInvokingCreate()
        thenSpanShouldHaveHttpMethodAttribute(withValue: "GET")
    }

    func test_onCreateTaskWithBody_bodySizeShouldBeSetOnSpanAsAttribute() {
        let randomData = UUID().uuidString.data(using: .utf8)!
        givenTaskHandler(withInitialState: .listening)
        givenAnURLSessionTask(method: "POST", body: randomData)
        whenInvokingCreate()
        thenSpanShouldHaveBodySizeAttribute(withValue: randomData.count)
    }

    // MARK: - Finish Test
}

private extension DefaultURLSessionTaskHandlerTests {
    func givenTaskHandler(withInitialState initialState: CaptureServiceHandlerState = .initialized) {
        otel = .init()
        sut = .init(DefaultURLSessionTaskHandler(otel: otel, initialState: initialState, processingQueue: .main))
    }

    func whenInvokingOnChangeState(withNewState state: CaptureServiceState) {
        sut.changedState(to: state)
    }

    func whenInvokingCreate() {
        sut.create(task: task)
    }

    func thenHTTPNetworkSpanShouldBeCreated() {
        waitForCreationToEnd()
        do {
            let span = try XCTUnwrap(processor.startedSpans.first)
            XCTAssertEqual(span.embType, .networkHTTP)
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldHaveURLAttribute(withValue url: String) {
        waitForCreationToEnd()
        do {
            let span = try XCTUnwrap(processor.startedSpans.first)
            let savedUrl = span.attributes["url.full"]
            XCTAssertNotNil(savedUrl)
            XCTAssertEqual(savedUrl?.description, url)

        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func waitForCreationToEnd() {
        wait(timeout: 1.0, until: { self.processor.startedSpans.count > 0 })
    }

    func givenAnURLSessionTask(urlString: String = "https://embrace.io", method: String? = nil, body: Data? = nil) {
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body = body {
            request.httpBody = body
        }
        task = URLSession(configuration: .default).dataTask(with: request)
    }

    func thenTaskHandlerState(is state: CaptureServiceHandlerState) {
        XCTAssertEqual(sut.state, state)
    }

    func thenNoSpanShouldBeCreated() {
        XCTAssertTrue(processor.startedSpans.count == 0)
    }

    func thenSpanName(is spanName: String) {
        waitForCreationToEnd()
        do {
            let span = try XCTUnwrap(processor.startedSpans.first)
            XCTAssertEqual(span.name, spanName)
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }

    func thenSpanShouldHaveHttpMethodAttribute(withValue method: String) {
        waitForCreationToEnd()
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
        waitForCreationToEnd()
        do {
            let span = try XCTUnwrap(processor.startedSpans.first)
            let methodAttribute = span.attributes["http.request.body.size"]
            XCTAssertNotNil(methodAttribute)
            XCTAssertEqual(methodAttribute?.description, String(size))
        } catch let exception {
            XCTFail("Couldn't get span: \(exception.localizedDescription)")
        }
    }
}
