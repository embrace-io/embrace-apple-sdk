//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import EmbraceCommonInternal
    import EmbraceConfiguration
    import EmbraceSemantics
    import Foundation
    import TestSupport
    import XCTest

    @testable import EmbraceCore
    @testable import EmbraceIO

    /// End-to-end wiring of the during-block sampler into `HangCaptureService` against a started SDK,
    /// proving a `thread_blockage_sample` event actually attaches with **resolved** frames. The
    /// `EmbraceCoreTests` counterpart covers the reconciliation/query wiring with canned samples; this
    /// is the one that runs a real capture + symbolication through the whole path.
    final class HangCaptureServiceSamplerIntegrationTests: XCTestCase {

        override class func setUp() {
            super.setUp()
            _ = try? Embrace.setup(options: Embrace.Options(appId: "myApp", captureServices: [], crashReporter: nil)).start()
        }

        override class func tearDown() {
            _ = try? Embrace.client?.stop()
            Embrace.client = nil
            super.tearDown()
        }

        private func makeService(otel: MockOTelSignalsHandler, sampler: MainThreadStackSampler) -> HangCaptureService {
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

            let otel = MockOTelSignalsHandler()
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
                otel.endedSpans.contains { $0.name == SpanSemantics.Hang.name }
            }

            let span = otel.endedSpans.first { $0.name == SpanSemantics.Hang.name }
            let event = span?.events.first { $0.name == SpanEventSemantics.Hang.name }
            XCTAssertNotNil(event, "hangEnded should attach a thread_blockage_sample event for an in-window sample")

            if let frameCount = event?.attributes[SpanEventSemantics.Hang.keyFrameCount] as? Int {
                XCTAssertGreaterThan(frameCount, 0, "attached sample should carry resolved frames")
            } else {
                XCTFail("frame_count attribute missing or not an int")
            }
        }

        func test_hangEnded_attachesEarliestInWindowSample() throws {
            try XCTSkipIfSanitizing("KSCrash symbolication is incompatible with sanitizer instrumentation")

            let otel = MockOTelSignalsHandler()
            let sampler = MockSampler()
            let backtrace = EmbraceBacktrace.backtrace(of: pthread_self(), threadIndex: 0)
            // Two in-window samples; the service must attach the FIRST (earliest) one, not the last.
            sampler.cannedSamples = [
                MainThreadStackSample(timestamp: backtrace.timestamp, overhead: 1111, backtrace: backtrace),
                MainThreadStackSample(timestamp: backtrace.timestamp, overhead: 9999, backtrace: backtrace)
            ]
            let service = makeService(otel: otel, sampler: sampler)

            let start = Date()
            service.hangStarted(at: start, duration: 0.5)
            service.hangEnded(at: start.addingTimeInterval(0.5), duration: 0.5)

            wait(timeout: .defaultTimeout) {
                otel.endedSpans.contains { $0.name == SpanSemantics.Hang.name }
            }

            let span = otel.endedSpans.first { $0.name == SpanSemantics.Hang.name }
            let event = span?.events.first { $0.name == SpanEventSemantics.Hang.name }
            XCTAssertNotNil(event)
            if let overhead = event?.attributes[SpanEventSemantics.Hang.keySampleOverhead] as? Int {
                XCTAssertEqual(overhead, 1111, "should attach the earliest in-window sample, not the last")
            } else {
                XCTFail("sample_overhead attribute missing or not an int")
            }
        }

        func test_hangEnded_withNoSample_endsSpanWithoutEvent() {
            let otel = MockOTelSignalsHandler()
            let service = makeService(otel: otel, sampler: MockSampler())  // returns nothing

            let start = Date()
            service.hangStarted(at: start, duration: 0.5)
            service.hangEnded(at: start.addingTimeInterval(0.5), duration: 0.5)

            wait(timeout: .defaultTimeout) {
                otel.endedSpans.contains { $0.name == SpanSemantics.Hang.name }
            }

            let span = otel.endedSpans.first { $0.name == SpanSemantics.Hang.name }
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
