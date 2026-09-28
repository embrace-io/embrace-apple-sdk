//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceIO

/// When the SDK starts disabled, spans must still reach the customer's OTel processors and
/// exporters. Child forwarding is gated on the SDK's start being resolved, so a disabled start
/// has to open that gate too or the customer's span pipeline stalls for the whole process.
final class EmbraceIODisabledSpanForwardingTests: XCTestCase {

    override func setUpWithError() throws {
        Embrace.client = nil
        EmbraceIO.shared.otelBridge.safeValue = nil
    }

    override func tearDownWithError() throws {
        _ = try? Embrace.client?.stop()
        Embrace.client = nil
        EmbraceIO.shared.otelBridge.safeValue = nil
    }

    func test_startDisabled_customerExporterStillReceivesSpans() throws {
        let exporter = ThreadSafeSpanExporter()
        let processor = ThreadSafeSpanProcessor()
        try startDisabled(exporter: exporter, processor: processor)

        let tracer = try XCTUnwrap(EmbraceIO.shared.tracer(instrumentationName: "test"))
        tracer.spanBuilder(spanName: "customer-span").startSpan().end()

        try forceFlushWithTimeout()

        XCTAssertEqual(exporter.exportedSpanNames, ["customer-span"])
        XCTAssertEqual(processor.startedSpanNames, ["customer-span"])
        XCTAssertEqual(processor.endedSpanNames, ["customer-span"])
    }

    func test_startDisabled_calledTwice_doesNotCrashAndStillForwards() throws {
        let exporter = ThreadSafeSpanExporter()
        try startDisabled(exporter: exporter, processor: ThreadSafeSpanProcessor())

        // The second start resolves through the same disabled path; the gate must only be opened once.
        try Embrace.client?.start()

        let tracer = try XCTUnwrap(EmbraceIO.shared.tracer(instrumentationName: "test"))
        tracer.spanBuilder(spanName: "customer-span").startSpan().end()

        try forceFlushWithTimeout()

        XCTAssertEqual(exporter.exportedSpanNames, ["customer-span"])
    }

    // MARK: - Helpers

    private func startDisabled(exporter: SpanExporter, processor: SpanProcessor) throws {
        let options = EmbraceIO.Options.withLocalConfiguration(
            MockEmbraceConfigurable(isSDKEnabled: false),
            captureServices: CaptureServicesOptionsBuilder().build(),
            crashReporter: .none,
            otel: EmbraceIO.OTelOptions(spanProcessors: [processor], spanExporters: [exporter])
        )
        try EmbraceIO.start(options: options)

        XCTAssertFalse(Embrace.client?.isSDKEnabled ?? true)
    }

    /// `forceFlush` runs synchronously behind all queued forwarding work, so it is also the
    /// check that forwarding is not stalled. It runs off the main thread with a timeout so a
    /// regression fails the test instead of hanging the suite.
    private func forceFlushWithTimeout() throws {
        let provider = try XCTUnwrap(EmbraceIO.shared.tracerProvider as? TracerProviderSdk)
        let flushed = expectation(description: "forceFlush returned")
        DispatchQueue.global().async {
            provider.forceFlush(timeout: nil)
            flushed.fulfill()
        }
        wait(for: [flushed], timeout: 5)
    }
}

private final class ThreadSafeSpanExporter: SpanExporter {
    @TestLocked var exportedSpanNames: [String] = []

    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        exportedSpanNames.append(contentsOf: spans.map(\.name))
        return .success
    }

    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode { .success }

    func shutdown(explicitTimeout: TimeInterval?) {}
}

private final class ThreadSafeSpanProcessor: SpanProcessor {
    let isStartRequired = true
    let isEndRequired = true

    @TestLocked var startedSpanNames: [String] = []
    @TestLocked var endedSpanNames: [String] = []

    func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        startedSpanNames.append(span.name)
    }

    func onEnd(span: ReadableSpan) {
        endedSpanNames.append(span.name)
    }

    func forceFlush(timeout: TimeInterval?) {}

    func shutdown(explicitTimeout: TimeInterval?) {}
}
