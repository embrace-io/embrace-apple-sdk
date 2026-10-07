//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCaptureService
import EmbraceCommonInternal
import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceIO

/// App code that runs on the main thread while `Embrace.start()` is still in progress must be able to flush
/// the tracer provider. Span work queued at that point waits for `start()` to finish, so a flush that
/// waited behind it would hang the main thread forever.
final class StartupForceFlushTests: XCTestCase {

    /// Capture service that ends a span and then flushes the SDK's tracer provider when it's started.
    final class FlushingCaptureService: CaptureService {
        @TestLocked var didFlush = false

        override func onStart() {
            guard let provider = EmbraceIO.shared.tracerProvider as? TracerProviderSdk else {
                return
            }

            // ensure there's span work parked on the processor queue ahead of the flush
            provider.get(instrumentationName: "test", instrumentationVersion: nil)
                .spanBuilder(spanName: "during-start").startSpan().end()

            provider.forceFlush(timeout: nil)
            didFlush = true
        }
    }

    override func setUpWithError() throws {
        Embrace.client = nil
        EmbraceIO.shared.otelBridge.safeValue = nil
    }

    override func tearDownWithError() throws {
        _ = try? Embrace.client?.stop()
        Embrace.client = nil
        EmbraceIO.shared.otelBridge.safeValue = nil
    }

    func test_forceFlush_fromCaptureServiceDuringStart_doesNotDeadlock() throws {
        // given a capture service that flushes the tracer provider from `onStart`
        let service = FlushingCaptureService()
        let options = EmbraceIO.Options.withLocalConfiguration(
            captureServices: CaptureServicesOptionsBuilder().add(service).build(),
            crashReporter: .none,
            otel: EmbraceIO.OTelOptions()
        )

        // when the SDK is started on the main thread
        try EmbraceIO.start(options: options)

        // then the flush returned and start finished
        XCTAssertTrue(service.didFlush)
        XCTAssertEqual(Embrace.client?.state, .started)
    }
}
