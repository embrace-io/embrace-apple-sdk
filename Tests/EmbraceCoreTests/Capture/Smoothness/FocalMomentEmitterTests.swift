//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import EmbraceCommonInternal
    import EmbraceConfiguration
    import EmbraceSemantics
    import TestSupport
    import XCTest

    @testable import EmbraceCore

    final class FocalMomentEmitterTests: XCTestCase {

        private typealias Snapshot = ActivityMonitor.Snapshot

        private let interval = 1.0 / 60.0
        private let clockOffset: TimeInterval = 1_700_000_000

        private var otel: MockOTelSignalsHandler!
        private var notificationCenter: NotificationCenter!
        private var queue: DispatchQueue!
        private var isQueueSuspended = false
        private var currentSession: EmbraceSession?
        private var tracker: FocalMomentTracker!
        private var emitter: FocalMomentEmitter!
        private var now: TimeInterval = 100

        override func setUp() {
            super.setUp()
            otel = MockOTelSignalsHandler()
            notificationCenter = NotificationCenter()
            queue = DispatchQueue(label: "FocalMomentEmitterTests")
            isQueueSuspended = false
            currentSession = MockSession.with(id: .random, state: .foreground)
            tracker = FocalMomentTracker()
            now = 100
            emitter = makeEmitter()
        }

        override func tearDown() {
            resumeQueue()
            emitter = nil
            tracker = nil
            otel = nil
            notificationCenter = nil
            queue = nil
            currentSession = nil
            super.tearDown()
        }

        // MARK: - Helpers

        private func makeEmitter(spanLimit: Int = SmoothnessLimits.defaultSpanLimit) -> FocalMomentEmitter {
            FocalMomentEmitter(
                tracker: tracker,
                currentPartId: { [unowned self] in self.currentSession?.id },
                otel: { [unowned self] in self.otel },
                embraceNotificationCenter: notificationCenter,
                queue: queue,
                spanLimit: spanLimit,
                clockOffset: { [unowned self] in self.clockOffset }
            )
        }

        private func tick(_ activity: Snapshot, lateFrames: Double = 0) {
            now += interval * (1 + lateFrames)
            tracker.record(
                MeasuredTick(
                    FrameTimingSource.Tick(timestamp: now, delay: interval * lateFrames, frameInterval: interval, previousFrameInterval: interval)),
                activity: activity
            )
        }

        private func openMoment() {
            tick(Snapshot(touchBegan: true, touchChanged: true, activeTouchCount: 1, didWork: true))
        }

        private func interruptedMoment() {
            openMoment()
            tracker.interrupt()
        }

        private func endPart() {
            notificationCenter.post(name: .embraceSessionPartWillEndSync, object: currentSession)
        }

        private func drainQueue() {
            queue.sync {}
        }

        private func suspendQueue() {
            queue.suspend()
            isQueueSuspended = true
        }

        private func resumeQueue() {
            guard isQueueSuspended else { return }
            isQueueSuspended = false
            queue.resume()
        }

        private var spans: [EmbraceSpan] {
            otel.startedSpans.filter { $0.name == SpanSemantics.Smoothness.focalMomentName }
        }

        // MARK: - Span contract

        func test_settledMoment_emitsPrivateCompletedSpan() throws {
            tick(Snapshot(touchBegan: true, touchChanged: true, activeTouchCount: 1, didWork: true), lateFrames: 1)
            let start = now - interval
            tick(Snapshot(touchChanged: true, didWork: true), lateFrames: 2)
            let end = now
            for _ in 0..<7 { tick(Snapshot()) }

            drainQueue()

            let span = try XCTUnwrap(spans.first)
            XCTAssertEqual(spans.count, 1)
            XCTAssertEqual(span.type, .smoothness)
            XCTAssertEqual(span.startTime.timeIntervalSince1970, clockOffset + start, accuracy: 0.000_001)
            XCTAssertEqual(try XCTUnwrap(span.endTime).timeIntervalSince1970, clockOffset + end, accuracy: 0.000_001)
            XCTAssertEqual(span.attributes[SpanSemantics.keyPrivate] as? String, "true")
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyOutcome] as? String, SpanSemantics.Smoothness.Outcome.settled)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyFrameCount] as? Int, 2)
            XCTAssertEqual(try XCTUnwrap(span.attributes[SpanSemantics.Smoothness.keyNormalizedDroppedFrames] as? Double), 3, accuracy: 0.001)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyIdleThresholdMs] as? Int, 100)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyHeldIdleThresholdMs] as? Int, 500)
        }

        func test_spanIsNotCreatedOnTheEndingThread() {
            suspendQueue()

            interruptedMoment()

            XCTAssertTrue(spans.isEmpty)
            resumeQueue()
            drainQueue()
            XCTAssertEqual(spans.count, 1)
        }

        // MARK: - Span limit

        func test_spanLimit_dropsMomentsPastTheLimitInAPart() {
            emitter = makeEmitter(spanLimit: 2)

            for _ in 0..<3 { interruptedMoment() }
            drainQueue()

            XCTAssertEqual(spans.count, 2)
        }

        func test_spanLimit_resetsOnNewPart() {
            emitter = makeEmitter(spanLimit: 1)

            interruptedMoment()
            interruptedMoment()
            drainQueue()
            currentSession = MockSession.with(id: .random, state: .foreground)
            interruptedMoment()
            drainQueue()

            XCTAssertEqual(spans.count, 2)
        }

        // MARK: - Part attribution

        func test_noCurrentPart_dropsMoment() {
            currentSession = nil

            interruptedMoment()
            drainQueue()

            XCTAssertTrue(spans.isEmpty)
        }

        func test_partChangesBeforeDrain_dropsMoment() {
            suspendQueue()
            interruptedMoment()

            currentSession = MockSession.with(id: .random, state: .background)
            resumeQueue()
            drainQueue()

            XCTAssertTrue(spans.isEmpty)
        }

        // MARK: - Part end

        func test_partWillEnd_forceClosesOpenMomentSynchronously() {
            suspendQueue()
            openMoment()

            endPart()

            XCTAssertEqual(spans.map { $0.attributes[SpanSemantics.Smoothness.keyOutcome] as? String }, [SpanSemantics.Smoothness.Outcome.interrupted])
        }

        func test_partWillEnd_emitsPendingMomentsSynchronouslyOnce() {
            suspendQueue()
            interruptedMoment()
            interruptedMoment()

            endPart()
            XCTAssertEqual(spans.count, 2)

            resumeQueue()
            drainQueue()
            XCTAssertEqual(spans.count, 2)
        }

        func test_partWillEnd_dropsPendingMomentsOfOtherParts() {
            suspendQueue()
            interruptedMoment()
            currentSession = MockSession.with(id: .random, state: .foreground)

            endPart()

            XCTAssertTrue(spans.isEmpty)
        }

        // MARK: - Invalidation

        func test_invalidate_dropsOpenMoment() {
            openMoment()

            emitter.invalidate()
            tracker.interrupt()
            endPart()
            drainQueue()

            XCTAssertTrue(spans.isEmpty)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
