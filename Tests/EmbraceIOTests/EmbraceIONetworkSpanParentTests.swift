//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import OpenTelemetryApi
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceIO

/// The controller's behavior is covered by `NetworkSpanParentControllerTests`. What matters here is that
/// the public API reaches it, that it is a no-op before setup, and that the SDK tells it when spans end.
final class EmbraceIONetworkSpanParentTests: XCTestCase {

    private var originalTracerProvider: TracerProvider!

    override func setUpWithError() throws {
        Embrace.client = nil
        EmbraceIO.shared.otelBridge.safeValue = nil
        originalTracerProvider = OpenTelemetry.instance.tracerProvider
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

    private func start() throws {
        let options = EmbraceIO.Options.withLocalConfiguration(
            captureServices: CaptureServicesOptionsBuilder().build(),
            crashReporter: .none,
            otel: EmbraceIO.OTelOptions()
        )
        try EmbraceIO.start(options: options)
    }
}
