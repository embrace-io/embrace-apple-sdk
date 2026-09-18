//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceOTelBridge
import EmbraceSemantics
import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import EmbraceCore
@testable import EmbraceIO

/// Covers the public provider surface on `EmbraceIO` and the opt-in global registration.
///
/// The accessors read the bridge published by `start(options:)`. These tests publish a bridge
/// directly instead of starting the whole SDK, so what is under test is the accessor layer and
/// the registration mechanism rather than the SDK lifecycle.
final class EmbraceIOOTelProvidersTests: XCTestCase {

    var bridge: EmbraceOTelBridge!
    var mockDelegate: ProvidersMockOTelDelegate!
    var mockMetadata: ProvidersMockMetadataProvider!

    /// `OpenTelemetry` has no deregistration API, so the globals are snapshotted and put back by
    /// hand. Without this any test that registers would leak the Embrace providers into every
    /// test that runs after it in the same process.
    var originalTracerProvider: TracerProvider!
    var originalLoggerProvider: LoggerProvider!

    override func setUpWithError() throws {
        Embrace.client = nil
        EmbraceIO.shared.otelBridge.safeValue = nil

        originalTracerProvider = OpenTelemetry.instance.tracerProvider
        originalLoggerProvider = OpenTelemetry.instance.loggerProvider

        mockDelegate = ProvidersMockOTelDelegate()
        mockMetadata = ProvidersMockMetadataProvider()
        bridge = EmbraceOTelBridge()
        bridge.setup(delegate: mockDelegate, metadataProvider: mockMetadata)
    }

    override func tearDownWithError() throws {
        _ = try? Embrace.client?.stop()
        Embrace.client = nil
        EmbraceIO.shared.otelBridge.safeValue = nil

        OpenTelemetry.registerTracerProvider(tracerProvider: originalTracerProvider)
        OpenTelemetry.registerLoggerProvider(loggerProvider: originalLoggerProvider)
    }

    // MARK: - No bridge

    func test_accessors_withoutBridge_returnNil() {
        XCTAssertNil(EmbraceIO.shared.tracerProvider)
        XCTAssertNil(EmbraceIO.shared.loggerProvider)
        XCTAssertNil(EmbraceIO.shared.tracer(instrumentationName: "test"))
        XCTAssertNil(EmbraceIO.shared.logger(instrumentationScopeName: "test"))
    }

    func test_accessors_withoutBridge_returnNilRatherThanANoOpProvider() {
        // A no-op stand-in would make the missing `OTelOptions` invisible: callers would create
        // spans that go nowhere. The contract is an explicit nil.
        XCTAssertNil(EmbraceIO.shared.tracer(instrumentationName: "test", instrumentationVersion: "1.0.0"))
        XCTAssertNil(EmbraceIO.shared.logger(instrumentationScopeName: "test", instrumentationVersion: "1.0.0"))
    }

    // MARK: - With a bridge

    // `TracerProvider` is not class-constrained, so identity is compared through `AnyObject`.
    // The underlying `TracerProviderSdk` is a class, so this is a reference comparison.
    func test_tracerProvider_withBridge_isTheBridgeProvider() {
        EmbraceIO.shared.otelBridge.safeValue = bridge

        XCTAssertTrue(EmbraceIO.shared.tracerProvider as AnyObject === bridge.otelTracerProvider as AnyObject)
    }

    func test_loggerProvider_withBridge_isTheBridgeProvider() {
        EmbraceIO.shared.otelBridge.safeValue = bridge

        XCTAssertTrue(EmbraceIO.shared.loggerProvider === bridge.otelLoggerProvider)
    }

    func test_tracer_withBridge_producesSpansThatReachTheDelegate() throws {
        EmbraceIO.shared.otelBridge.safeValue = bridge

        let tracer = try XCTUnwrap(EmbraceIO.shared.tracer(instrumentationName: "test-instrumentation"))
        tracer.spanBuilder(spanName: "public-api-span").startSpan().end()

        XCTAssertEqual(mockDelegate.startedSpans.count, 1)
        XCTAssertEqual(mockDelegate.startedSpans.first?.name, "public-api-span")
        XCTAssertEqual(
            mockDelegate.startedSpans.first?.attributes[SpanSemantics.keySessionId] as? String,
            "test-user-session-id"
        )
    }

    func test_tracer_withInstrumentationVersion_producesSpansThatReachTheDelegate() throws {
        EmbraceIO.shared.otelBridge.safeValue = bridge

        let tracer = try XCTUnwrap(
            EmbraceIO.shared.tracer(instrumentationName: "test-instrumentation", instrumentationVersion: "1.2.3")
        )
        tracer.spanBuilder(spanName: "versioned-span").startSpan().end()

        XCTAssertEqual(mockDelegate.startedSpans.count, 1)
        XCTAssertEqual(mockDelegate.startedSpans.first?.name, "versioned-span")
    }

    func test_logger_withBridge_producesLogsThatReachTheDelegate() throws {
        EmbraceIO.shared.otelBridge.safeValue = bridge

        let logger = try XCTUnwrap(EmbraceIO.shared.logger(instrumentationScopeName: "test-instrumentation"))
        logger.logRecordBuilder().setBody(.string("public-api-log")).setSeverity(.info).emit()

        XCTAssertEqual(mockDelegate.emittedLogs.count, 1)
        XCTAssertEqual(mockDelegate.emittedLogs.first?.body, "public-api-log")
        XCTAssertEqual(
            mockDelegate.emittedLogs.first?.attributes[LogSemantics.keySessionId] as? String,
            "test-user-session-id"
        )
    }

    /// `LoggerProvider` has no versioned `get`, so this path goes through the builder. It has to
    /// end up on the same pipeline as the unversioned one.
    func test_logger_withInstrumentationVersion_producesLogsThatReachTheDelegate() throws {
        EmbraceIO.shared.otelBridge.safeValue = bridge

        let logger = try XCTUnwrap(
            EmbraceIO.shared.logger(instrumentationScopeName: "test-instrumentation", instrumentationVersion: "1.2.3")
        )
        logger.logRecordBuilder().setBody(.string("versioned-log")).setSeverity(.info).emit()

        XCTAssertEqual(mockDelegate.emittedLogs.count, 1)
        XCTAssertEqual(mockDelegate.emittedLogs.first?.body, "versioned-log")
    }

    // MARK: - OTelOptions

    func test_registersGlobalProviders_defaultsToFalse() {
        XCTAssertFalse(EmbraceIO.OTelOptions().registersGlobalProviders)
    }

    func test_registersGlobalProviders_canBeEnabled() {
        XCTAssertTrue(EmbraceIO.OTelOptions(registersGlobalProviders: true).registersGlobalProviders)
    }

    // MARK: - Global registration

    func test_globalRegistration_makesEmbraceProvidersResolvableThroughOpenTelemetryInstance() {
        OpenTelemetry.registerTracerProvider(tracerProvider: bridge.otelTracerProvider)
        OpenTelemetry.registerLoggerProvider(loggerProvider: bridge.otelLoggerProvider)

        XCTAssertTrue(OpenTelemetry.instance.tracerProvider as AnyObject === bridge.otelTracerProvider as AnyObject)
        XCTAssertTrue(OpenTelemetry.instance.loggerProvider === bridge.otelLoggerProvider)
    }

    func test_globalRegistration_routesSpansFromOpenTelemetryInstanceIntoEmbrace() {
        OpenTelemetry.registerTracerProvider(tracerProvider: bridge.otelTracerProvider)

        let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "third-party")
        tracer.spanBuilder(spanName: "global-span").startSpan().end()

        XCTAssertEqual(mockDelegate.startedSpans.count, 1)
        XCTAssertEqual(mockDelegate.startedSpans.first?.name, "global-span")
    }

    func test_globalRegistration_routesLogsFromOpenTelemetryInstanceIntoEmbrace() {
        OpenTelemetry.registerLoggerProvider(loggerProvider: bridge.otelLoggerProvider)

        let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: "third-party")
        logger.logRecordBuilder().setBody(.string("global-log")).setSeverity(.info).emit()

        XCTAssertEqual(mockDelegate.emittedLogs.count, 1)
        XCTAssertEqual(mockDelegate.emittedLogs.first?.body, "global-log")
    }

    // MARK: - Repeated start

    /// `Embrace.setup` keeps the client created by the first successful call, so a second
    /// `start` builds a bridge the client never adopts. That bridge must not be wired or
    /// published: what the accessors return always has to be the pipeline `EmbraceCore`
    /// actually emits through.
    func test_startTwice_keepsThePublishedBridgeTiedToTheClient() throws {
        let options = EmbraceIO.Options.withAppId(
            "myApp",
            captureServices: CaptureServicesOptionsBuilder().build(),
            crashReporter: .none,
            otel: EmbraceIO.OTelOptions()
        )

        try EmbraceIO.start(options: options)

        let publishedAfterFirstStart = EmbraceIO.shared.otelBridge.safeValue
        XCTAssertNotNil(publishedAfterFirstStart)
        XCTAssertTrue(Embrace.client?.otel.bridge as AnyObject === publishedAfterFirstStart as AnyObject)

        try EmbraceIO.start(options: options)

        XCTAssertTrue(EmbraceIO.shared.otelBridge.safeValue === publishedAfterFirstStart)
        XCTAssertTrue(Embrace.client?.otel.bridge as AnyObject === EmbraceIO.shared.otelBridge.safeValue as AnyObject)
    }

    /// A bridge the client did not adopt is never handed a delegate, so nothing it produces can
    /// reach `EmbraceCore` even if a caller somehow got hold of its providers.
    func test_bridgeNotAdoptedByTheClient_isNeverWired() throws {
        let orphan = EmbraceOTelBridge()
        let tracer = orphan.otelTracerProvider.get(instrumentationName: "orphan-instrumentation")

        tracer.spanBuilder(spanName: "orphan-span").startSpan().end()

        XCTAssertTrue(mockDelegate.startedSpans.isEmpty)
        XCTAssertTrue(mockDelegate.endedSpans.isEmpty)
    }

    func test_withoutGlobalRegistration_openTelemetryInstanceIsUntouched() {
        EmbraceIO.shared.otelBridge.safeValue = bridge

        // Publishing the bridge is what `start(options:)` does for every configuration. Only the
        // opt-in flag may additionally touch the process-wide providers.
        XCTAssertTrue(OpenTelemetry.instance.tracerProvider as AnyObject === originalTracerProvider as AnyObject)
        XCTAssertTrue(OpenTelemetry.instance.loggerProvider === originalLoggerProvider)
    }
}

// MARK: - Mocks

class ProvidersMockOTelDelegate: EmbraceOTelDelegate {
    var startedSpans: [EmbraceSpan] = []
    var endedSpans: [EmbraceSpan] = []
    var emittedLogs: [EmbraceLog] = []

    func onStartSpan(_ span: EmbraceSpan) { startedSpans.append(span) }
    func onEndSpan(_ span: EmbraceSpan) { endedSpans.append(span) }
    func onEmitLog(_ log: EmbraceLog) { emittedLogs.append(log) }
}

class ProvidersMockMetadataProvider: EmbraceMetadataProvider {
    var currentSessionId: EmbraceIdentifier? = EmbraceIdentifier(stringValue: "test-session-id")
    var currentUserSessionId: EmbraceIdentifier? = EmbraceIdentifier(stringValue: "test-user-session-id")
    var currentProcessId: EmbraceIdentifier = EmbraceIdentifier(stringValue: "test-process-id")
    var currentSessionState: SessionState = .foreground
}
