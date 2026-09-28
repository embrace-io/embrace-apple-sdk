//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceOTelBridge

/// Covers the providers the bridge vends. A signal created through one of them is, from the
/// bridge's point of view, indistinguishable from one created by third-party instrumentation:
/// it must be classified as external, stamped with the Embrace identity attributes, and handed
/// to the delegate.
final class EmbraceOTelBridgeProvidersTests: XCTestCase {

    var bridge: EmbraceOTelBridge!
    var mockDelegate: MockOTelDelegate!
    var mockMetadata: MockMetadataProvider!
    var spanProcessor: MockSpanProcessor!
    var logExporter: MockLogExporter!

    override func setUp() {
        super.setUp()
        mockDelegate = MockOTelDelegate()
        mockMetadata = MockMetadataProvider()
        spanProcessor = MockSpanProcessor()
        logExporter = MockLogExporter()
        bridge = EmbraceOTelBridge(
            spanProcessors: [spanProcessor],
            logExporters: [logExporter]
        )
        bridge.setup(delegate: mockDelegate, metadataProvider: mockMetadata)
    }

    // MARK: - Identity

    // `TracerProvider` is not class-constrained, so identity is compared through `AnyObject`.
    // The underlying `TracerProviderSdk` is a class, so this is a reference comparison.
    func test_otelTracerProvider_returnsTheSameInstanceOnEveryAccess() {
        let first = bridge.otelTracerProvider
        let second = bridge.otelTracerProvider

        XCTAssertTrue(first as AnyObject === second as AnyObject)
    }

    func test_otelLoggerProvider_returnsTheSameInstanceOnEveryAccess() {
        let first = bridge.otelLoggerProvider
        let second = bridge.otelLoggerProvider

        XCTAssertTrue(first === second)
    }

    // MARK: - Spans

    func test_spanFromVendedProvider_isClassifiedExternal_andReachesDelegate() {
        let tracer = bridge.otelTracerProvider.get(instrumentationName: "test-instrumentation")

        let span = tracer.spanBuilder(spanName: "external-span").startSpan()

        XCTAssertEqual(mockDelegate.startedSpans.count, 1)
        XCTAssertEqual(mockDelegate.startedSpans.first?.name, "external-span")

        span.end()

        XCTAssertEqual(mockDelegate.endedSpans.count, 1)
        XCTAssertEqual(mockDelegate.endedSpans.first?.name, "external-span")
    }

    func test_spanFromVendedProvider_receivesInjectedIdentityAttributes() {
        let tracer = bridge.otelTracerProvider.get(instrumentationName: "test-instrumentation")

        tracer.spanBuilder(spanName: "external-span").startSpan().end()

        let attributes = try? XCTUnwrap(mockDelegate.startedSpans.first?.attributes)
        XCTAssertEqual(attributes?[SpanSemantics.keyEmbraceType] as? String, EmbraceType.performance.rawValue)
        XCTAssertEqual(attributes?[SpanSemantics.Session.keyState] as? String, SessionState.foreground.rawValue)
        XCTAssertEqual(attributes?[SpanSemantics.keySessionId] as? String, "test-user-session-id")
        XCTAssertEqual(attributes?[SpanSemantics.Session.keyUserSessionId] as? String, "test-user-session-id")
        XCTAssertEqual(attributes?[SpanSemantics.Session.keyPartId] as? String, "test-session-id")
    }

    func test_spanFromVendedProvider_alsoReachesChildProcessors() {
        let tracer = bridge.otelTracerProvider.get(instrumentationName: "test-instrumentation")

        tracer.spanBuilder(spanName: "external-span").startSpan().end()

        bridge.waitForAllWork()

        XCTAssertEqual(spanProcessor.endedSpans.count, 1)
        XCTAssertEqual(spanProcessor.endedSpans.first?.name, "external-span")
    }

    /// Spans the bridge creates itself must stay internal even though both paths ultimately use
    /// the same provider, otherwise every outbound signal would be forwarded back into Core.
    func test_spanFromBridge_isNotClassifiedExternal() {
        _ = bridge.startSpan(
            name: "internal-span",
            parentSpan: nil,
            status: .unset,
            startTime: Date(),
            endTime: Date(),
            events: [],
            links: [],
            attributes: [:]
        )

        XCTAssertTrue(mockDelegate.startedSpans.isEmpty)
        XCTAssertTrue(mockDelegate.endedSpans.isEmpty)
    }

    // MARK: - Logs

    func test_logFromVendedProvider_isClassifiedExternal_andReachesDelegate() {
        let logger = bridge.otelLoggerProvider.get(instrumentationScopeName: "test-instrumentation")

        logger.logRecordBuilder()
            .setBody(.string("external-log"))
            .setSeverity(.info)
            .emit()

        XCTAssertEqual(mockDelegate.emittedLogs.count, 1)
        XCTAssertEqual(mockDelegate.emittedLogs.first?.body, "external-log")
    }

    func test_logFromVendedProvider_receivesInjectedIdentityAttributes() {
        let logger = bridge.otelLoggerProvider.get(instrumentationScopeName: "test-instrumentation")

        logger.logRecordBuilder()
            .setBody(.string("external-log"))
            .setSeverity(.info)
            .emit()

        let attributes = try? XCTUnwrap(mockDelegate.emittedLogs.first?.attributes)
        XCTAssertEqual(attributes?[LogSemantics.keyEmbraceType] as? String, EmbraceType.message.rawValue)
        XCTAssertEqual(attributes?[LogSemantics.keyState] as? String, SessionState.foreground.rawValue)
        XCTAssertEqual(attributes?[LogSemantics.keySessionId] as? String, "test-user-session-id")
        XCTAssertEqual(attributes?[LogSemantics.keyUserSessionId] as? String, "test-user-session-id")
        XCTAssertEqual(attributes?[LogSemantics.keyPartId] as? String, "test-session-id")
    }

    func test_loggerBuiltWithInstrumentationVersion_stillReachesDelegate() {
        let logger = bridge.otelLoggerProvider
            .loggerBuilder(instrumentationScopeName: "test-instrumentation")
            .setInstrumentationVersion("1.2.3")
            .build()

        logger.logRecordBuilder()
            .setBody(.string("versioned-log"))
            .setSeverity(.info)
            .emit()

        XCTAssertEqual(mockDelegate.emittedLogs.count, 1)
        XCTAssertEqual(mockDelegate.emittedLogs.first?.body, "versioned-log")
    }

    // MARK: - Ordering

    /// Before `setup(delegate:metadataProvider:)` runs there is no delegate, so nothing can be
    /// forwarded. This is why `EmbraceIO` publishes the bridge only after wiring it: a caller who
    /// can reach a provider can always reach a delegate too.
    func test_spanFromVendedProvider_beforeSetup_isNotForwarded() {
        let unwiredBridge = EmbraceOTelBridge()
        let tracer = unwiredBridge.otelTracerProvider.get(instrumentationName: "test-instrumentation")

        tracer.spanBuilder(spanName: "orphan-span").startSpan().end()

        XCTAssertTrue(mockDelegate.startedSpans.isEmpty)
        XCTAssertTrue(mockDelegate.endedSpans.isEmpty)
    }
}
