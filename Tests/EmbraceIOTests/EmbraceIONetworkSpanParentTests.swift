//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceIO

/// The controller's behavior is covered by `NetworkSpanParentControllerTests`. What matters here is that
/// the public API reaches it, that it is a no-op before setup, that the SDK tells it when spans and user
/// sessions end, and that captured requests are parented to it.
final class EmbraceIONetworkSpanParentTests: XCTestCase {

    private var originalTracerProvider: TracerProvider!
    private var spanProcessor: MockSpanProcessor!

    override func setUpWithError() throws {
        Embrace.client = nil
        EmbraceIO.shared.otelBridge.safeValue = nil
        originalTracerProvider = OpenTelemetry.instance.tracerProvider
        spanProcessor = MockSpanProcessor()
    }

    override func tearDownWithError() throws {
        _ = try? Embrace.client?.stop()
        Embrace.client = nil
        EmbraceIO.shared.otelBridge.safeValue = nil
        OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)
    }

    func test_beforeSetup_returnsInertToken_andClearIsANoOp() {
        let span = MockSpan(name: "checkout")
        XCTAssertEqual(EmbraceIO.shared.setNetworkSpanParent(span), .inert)
        XCTAssertEqual(EmbraceIO.shared.setNetworkSpanParent(span.context), .inert)
        XCTAssertFalse(EmbraceIO.shared.clearNetworkSpanParent(.inert))
    }

    func test_setAndClear_reachTheController() throws {
        try start()
        let controller = try XCTUnwrap(Embrace.client?.networkSpanParentController)
        let context = EmbraceSpanContext(spanId: .randomSpanId(), traceId: .randomTraceId())

        let token = EmbraceIO.shared.setNetworkSpanParent(context)
        XCTAssertEqual(controller.currentContext()?.spanId, context.spanId)

        XCTAssertTrue(EmbraceIO.shared.clearNetworkSpanParent(token))
        XCTAssertNil(controller.currentContext())
        XCTAssertFalse(EmbraceIO.shared.clearNetworkSpanParent(token))
    }

    func test_embraceSpanEnding_clearsTheNetworkSpanParent() throws {
        try start()
        let controller = try XCTUnwrap(Embrace.client?.networkSpanParentController)
        let span = try XCTUnwrap(EmbraceIO.shared.createSpan(name: "checkout"))

        _ = EmbraceIO.shared.setNetworkSpanParent(span)
        XCTAssertEqual(controller.currentContext()?.spanId, span.context.spanId)

        span.end()
        XCTAssertNil(controller.currentContext())
    }

    func test_otelSpanEnding_clearsTheNetworkSpanParentSetByContext() throws {
        try start()
        let controller = try XCTUnwrap(Embrace.client?.networkSpanParentController)
        let tracer = try XCTUnwrap(EmbraceIO.shared.tracer(instrumentationName: "test"))
        let otelSpan = tracer.spanBuilder(spanName: "checkout").startSpan()
        let context = EmbraceSpanContext(
            spanId: otelSpan.context.spanId.hexString,
            traceId: otelSpan.context.traceId.hexString
        )

        _ = EmbraceIO.shared.setNetworkSpanParent(context)
        XCTAssertEqual(controller.currentContext()?.spanId, context.spanId)

        otelSpan.end()
        XCTAssertNil(controller.currentContext())
    }

    func test_parentSetWithoutSessionPart_isOnlyClearedByItsUserSession() throws {
        try start()
        let client = try XCTUnwrap(Embrace.client)
        _ = client.sessionController.endSession()
        XCTAssertNil(client.sessionController.currentSession)
        let userSessionId = try XCTUnwrap(client.sessionController.currentUserSession?.id)

        _ = EmbraceIO.shared.setNetworkSpanParent(EmbraceSpanContext(spanId: .randomSpanId(), traceId: .randomTraceId()))

        NotificationCenter.default.post(name: .embraceUserSessionDidEnd, object: userSession(id: .random))
        XCTAssertNotNil(client.networkSpanParentController.currentContext())

        NotificationCenter.default.post(name: .embraceUserSessionDidEnd, object: userSession(id: userSessionId))
        XCTAssertNil(client.networkSpanParentController.currentContext())
    }

    // MARK: - Captured requests

    func test_capturedRequest_isChildOfTheNetworkSpanParent_untilItEnds() throws {
        try start(capturingRequests: true)
        let parent = try XCTUnwrap(EmbraceIO.shared.createSpan(name: "checkout"))
        _ = EmbraceIO.shared.setNetworkSpanParent(parent)

        _ = URLSession.shared.dataTask(with: url(path: "/during"))
        let during = try XCTUnwrap(startedSpan(named: "GET /during"))
        XCTAssertEqual(during.parentSpanId?.hexString, parent.context.spanId)
        XCTAssertEqual(during.traceId.hexString, parent.context.traceId)

        parent.end()
        _ = URLSession.shared.dataTask(with: url(path: "/after"))
        let after = try XCTUnwrap(startedSpan(named: "GET /after"))
        XCTAssertNil(after.parentSpanId)
    }

    func test_spanParentCallback_canUseTheNetworkSpanParentAPI() throws {
        let requestsDataSource = NetworkSpanParentAPICallingDataSource()
        try start(capturingRequests: true, requestsDataSource: requestsDataSource)
        let parent = EmbraceSpanContext(spanId: .randomSpanId(), traceId: .randomTraceId())
        _ = EmbraceIO.shared.setNetworkSpanParent(parent)

        _ = URLSession.shared.dataTask(with: url(path: "/callback"))

        // The callback replaced the parent and cleared its replacement, without deadlocking.
        let span = try XCTUnwrap(startedSpan(named: "GET /callback"))
        XCTAssertEqual(requestsDataSource.receivedContext?.spanId, parent.spanId)
        XCTAssertEqual(requestsDataSource.didClearReplacement, true)
        XCTAssertEqual(span.parentSpanId?.hexString, parent.spanId)
        XCTAssertNil(Embrace.client?.networkSpanParentController.currentContext())
    }

    // MARK: - Sessions

    func test_sessionPartEnding_keepsTheParent_userSessionEnding_clearsIt() throws {
        try start()
        let client = try XCTUnwrap(Embrace.client)
        let context = EmbraceSpanContext(spanId: .randomSpanId(), traceId: .randomTraceId())
        _ = EmbraceIO.shared.setNetworkSpanParent(context)

        _ = client.sessionController.endSession()
        XCTAssertEqual(client.networkSpanParentController.currentContext()?.spanId, context.spanId)

        let userSessionEnded = expectation(forNotification: .embraceUserSessionDidEnd, object: nil)
        client.userSessionController.endActiveUserSession(reason: .manual, at: Date())
        wait(for: [userSessionEnded], timeout: 5)
        XCTAssertNil(client.networkSpanParentController.currentContext())
    }

    // MARK: - Other spans

    func test_spansOtherThanNetworkSpans_ignoreTheNetworkSpanParent() throws {
        try start()
        _ = EmbraceIO.shared.setNetworkSpanParent(EmbraceSpanContext(spanId: .randomSpanId(), traceId: .randomTraceId()))

        let embraceSpan = try XCTUnwrap(EmbraceIO.shared.createSpan(name: "embrace-span"))
        XCTAssertNil(embraceSpan.parentSpanId)

        let tracer = try XCTUnwrap(EmbraceIO.shared.tracer(instrumentationName: "test"))
        _ = tracer.spanBuilder(spanName: "otel-span").startSpan()
        let otelSpan = try XCTUnwrap(startedSpan(named: "otel-span"))
        XCTAssertNil(otelSpan.parentSpanId)
    }

    // MARK: - Slow-call telemetry

    func test_slowSpanParentCall_isCountedOnTheSessionPartSpan_untilTheSessionPartEnds() throws {
        try start()
        let client = try XCTUnwrap(Embrace.client)
        let captureService = URLSessionCaptureService()
        let countKey = "emb.private.slow_callback.network_span_parent_provider.count"
        let maxMsKey = "emb.private.slow_callback.network_span_parent_provider.max_ms"

        XCTAssertEqual(captureService.spanParentSlowCallThreshold, 0.005)

        captureService.recordSlowSpanParentCall(duration: 0.012)
        captureService.recordSlowSpanParentCall(duration: 0.0079)
        let firstPart = try XCTUnwrap(client.sessionController.currentSessionSpan)
        XCTAssertEqual(firstPart.attributes[countKey]?.description, "2")
        XCTAssertEqual(firstPart.attributes[maxMsKey]?.description, "12")

        _ = client.sessionController.endSession()
        _ = client.sessionController.startSession(state: .foreground)
        let secondPart = try XCTUnwrap(client.sessionController.currentSessionSpan)
        XCTAssertNil(secondPart.attributes[countKey])
        XCTAssertNil(secondPart.attributes[maxMsKey])

        captureService.recordSlowSpanParentCall(duration: 0.006)
        XCTAssertEqual(secondPart.attributes[countKey]?.description, "1")
        XCTAssertEqual(secondPart.attributes[maxMsKey]?.description, "6")
    }

    // MARK: - Helpers

    private func url(path: String) -> URL {
        return URL(string: "https://network-span-parent.embrace-tests.io\(path)")!
    }

    private func startedSpan(named name: String) -> SpanData? {
        Embrace.client?.waitForAllWork()
        return spanProcessor.startedSpans.first { $0.name == name }
    }

    private func userSession(id: EmbraceIdentifier) -> EmbraceUserSession {
        return ImmutableUserSession(
            id: id,
            startTime: Date(),
            maxDuration: 3600,
            inactivityTimeout: 600,
            partIndex: 1,
            endTime: Date(),
            isBackgroundOnly: false
        )
    }

    private func start(capturingRequests: Bool = false, requestsDataSource: URLSessionRequestsDataSource? = nil) throws {
        let builder = CaptureServicesOptionsBuilder()
        if capturingRequests {
            _ = builder.addUrlSessionCaptureService(withOptions: .init(requestsDataSource: requestsDataSource))
        }
        let options = EmbraceIO.Options.withLocalConfiguration(
            captureServices: builder.build(),
            crashReporter: .none,
            otel: EmbraceIO.OTelOptions(spanProcessors: [spanProcessor])
        )
        try EmbraceIO.start(options: options)
    }
}

/// Requests data source whose callback replaces the network span parent and then clears its replacement.
private final class NetworkSpanParentAPICallingDataSource: URLSessionRequestsDataSource {
    private(set) var receivedContext: EmbraceSpanContext?
    private(set) var didClearReplacement: Bool?

    func modifiedRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    func spanParent(for request: URLRequest, currentParentContext: EmbraceSpanContext?) -> EmbraceNetworkSpanParent {
        receivedContext = currentParentContext
        let replacement = EmbraceSpanContext(spanId: .randomSpanId(), traceId: .randomTraceId())
        let token = EmbraceIO.shared.setNetworkSpanParent(replacement)
        didClearReplacement = EmbraceIO.shared.clearNetworkSpanParent(token)
        return .default
    }
}
