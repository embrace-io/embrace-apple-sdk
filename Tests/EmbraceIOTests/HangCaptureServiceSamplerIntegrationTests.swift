//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import EmbraceCommonInternal
    import EmbraceConfiguration
    import EmbraceSemantics
    import Foundation
    import OpenTelemetryApi
    import TestSupport
    import XCTest

    @testable import EmbraceCore
    @testable import EmbraceIO

    /// End-to-end wiring of the during-block sampler into `HangCaptureService`, with a **real**
    /// backtracer/symbolicator (from `Embrace.setup`) so `thread_blockage_sample` frames actually
    /// resolve. `EmbraceCoreTests` can't do this — it has no symbolicator — so it only checks the
    /// reconciliation/query wiring; the "event actually attaches with frames" proof lives here.
    final class HangCaptureServiceSamplerIntegrationTests: XCTestCase {

        override class func setUp() {
            super.setUp()
            _ = try? Embrace.setup(options: Embrace.Options(appId: "myApp")).start()
        }

        override class func tearDown() {
            _ = try? Embrace.client?.stop()
            Embrace.client = nil
            super.tearDown()
        }

        private func makeService(otel: MockEmbraceOpenTelemetry, sampler: MainThreadStackSampler) -> HangCaptureService {
            let service = HangCaptureService(limits: HangLimits(hangThreshold: 0.249, hangPerSession: 6))
            service.install(otel: otel)
            service.start()
            service.limitData.withLock {
                $0.sampler?.stop()
                $0.sampler = sampler
            }
            return service
        }

        func test_hangEnded_attachesInWindowSampleAsThreadBlockageEvent() throws {
            try XCTSkipIfSanitizing("KSCrash symbolication is incompatible with sanitizer instrumentation")

            let otel = MockEmbraceOpenTelemetry()
            let sampler = MockSampler()
            // A real self-capture: gives addresses the symbolicator can resolve to non-nil frames.
            let backtrace = EmbraceBacktrace.backtrace(of: pthread_self(), threadIndex: 0)
            sampler.cannedSamples = [
                MainThreadStackSample(timestamp: backtrace.timestamp, overhead: 4321, backtrace: backtrace)
            ]
            let service = makeService(otel: otel, sampler: sampler)

            let start = Date()
            service.hangStarted(at: start, duration: 0.5)
            service.hangEnded(at: start.addingTimeInterval(0.5), duration: 0.5)

            wait(timeout: .defaultTimeout) {
                otel.spanProcessor.endedSpans.contains { $0.name == SpanSemantics.Hang.name }
            }

            let span = otel.spanProcessor.endedSpans.first { $0.name == SpanSemantics.Hang.name }
            let event = span?.events.first { $0.name == SpanEventSemantics.Hang.name }
            XCTAssertNotNil(event, "hangEnded should attach a thread_blockage_sample event for an in-window sample")

            if case let .int(frameCount)? = event?.attributes[SpanEventSemantics.Hang.keyFrameCount] {
                XCTAssertGreaterThan(frameCount, 0, "attached sample should carry resolved frames")
            } else {
                XCTFail("frame_count attribute missing or not an int")
            }
        }

        func test_hangEnded_withNoSample_endsSpanWithoutEvent() {
            let otel = MockEmbraceOpenTelemetry()
            let service = makeService(otel: otel, sampler: MockSampler())  // returns nothing

            let start = Date()
            service.hangStarted(at: start, duration: 0.5)
            service.hangEnded(at: start.addingTimeInterval(0.5), duration: 0.5)

            wait(timeout: .defaultTimeout) {
                otel.spanProcessor.endedSpans.contains { $0.name == SpanSemantics.Hang.name }
            }

            let span = otel.spanProcessor.endedSpans.first { $0.name == SpanSemantics.Hang.name }
            XCTAssertNotNil(span, "span should still end when no sample is available")
            XCTAssertNil(
                span?.events.first { $0.name == SpanEventSemantics.Hang.name },
                "no in-window sample → honest no-stack (no thread_blockage_sample event)"
            )
        }
    }

    private final class MockSampler: MainThreadStackSampler {
        var cannedSamples: [MainThreadStackSample] = []
        func start() {}
        func stop() {}
        func pause() {}
        func resume() {}
        func samples(in range: ClosedRange<UInt64>) -> [MainThreadStackSample] { cannedSamples }
    }

#endif
