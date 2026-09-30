//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import CoreData
    import EmbraceCommonInternal
    import EmbraceConfiguration
    import EmbraceSemantics
    import EmbraceStorageInternal
    import TestSupport
    import XCTest

    @_spi(Private) @testable import EmbraceCore

    final class SmoothnessCaptureServiceTests: XCTestCase {

        private let accuracy = 1e-9

        private var otel: MockOTelSignalsHandler!
        private var notificationCenter: NotificationCenter!
        private var embraceNotificationCenter: NotificationCenter!
        private var currentSession: EmbraceSession?
        private var thermalState: ProcessInfo.ThermalState = .nominal
        private var service: SmoothnessCaptureService!
        /// Ended smoothness span count at each storage flush.
        private var flushes: [Int] = []

        override func setUpWithError() throws {
            try super.setUpWithError()
            otel = MockOTelSignalsHandler()
            notificationCenter = NotificationCenter()
            embraceNotificationCenter = NotificationCenter()
            currentSession = nil
            thermalState = .nominal
            flushes = []
            service = makeService()
        }

        /// The default checkpoint interval is long enough that the timer never fires during a test. The
        /// debugger check defaults to detached, so the suite also runs from Xcode.
        private func makeService(
            checkpointInterval: TimeInterval = SmoothnessCaptureService.defaultCheckpointInterval,
            debuggerAttached: @escaping () -> Bool = { false },
            environment: [String: String] = [:]
        ) -> SmoothnessCaptureService {
            SmoothnessCaptureService(
                currentSession: { [unowned self] in self.currentSession },
                notificationCenter: notificationCenter,
                embraceNotificationCenter: embraceNotificationCenter,
                flushStorage: { [unowned self] in self.flushes.append(self.endedSmoothnessSpans.count) },
                thermalState: { [unowned self] in self.thermalState },
                checkpointInterval: checkpointInterval,
                debuggerAttached: debuggerAttached,
                environment: environment
            )
        }

        override func tearDown() {
            service?.stop()
            service = nil
            otel = nil
            notificationCenter = nil
            embraceNotificationCenter = nil
            currentSession = nil
            super.tearDown()
        }

        // MARK: - Helpers

        private func startService() {
            service.install(otel: otel)
            service.start()
        }

        @discardableResult
        private func startPart(_ state: SessionState) -> EmbraceSession {
            let session = MockSession.with(id: .random, state: state)
            currentSession = session
            notificationCenter.post(name: .embraceSessionPartDidStart, object: session)
            return session
        }

        private func endPart(_ session: EmbraceSession? = nil, at endTime: Date = Date()) {
            embraceNotificationCenter.post(
                name: .embraceSessionPartWillEndSync,
                object: session ?? currentSession,
                userInfo: [SessionController.sessionPartWillEndSyncEndTimeKey: endTime]
            )
        }

        private func postWillTerminate() {
            notificationCenter.post(name: Notification.Name("UIApplicationWillTerminateNotification"), object: nil)
        }

        private func changeThermalState(to state: ProcessInfo.ThermalState) {
            thermalState = state
            notificationCenter.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        }

        private func peakThermalState(of span: EmbraceSpan?) -> String? {
            span?.attributes[SpanSemantics.Smoothness.keyPeakThermalState] as? String
        }

        private func postDidBecomeActive() {
            notificationCenter.post(name: Notification.Name("UIApplicationDidBecomeActiveNotification"), object: nil)
        }

        /// Runs the main queue past anything already enqueued on it.
        private func drainMain() {
            let drained = expectation(description: "main drained")
            DispatchQueue.main.async { drained.fulfill() }
            wait(for: [drained], timeout: 1)
        }

        private var smoothnessSpans: [EmbraceSpan] {
            otel.startedSpans.filter { $0.name == SpanSemantics.Smoothness.name }
        }

        private var endedSmoothnessSpans: [EmbraceSpan] {
            otel.endedSpans.filter { $0.name == SpanSemantics.Smoothness.name }
        }

        // MARK: - Lifecycle

        func test_start_buildsPipeline() {
            startService()

            XCTAssertNotNil(service.tracker)
        }

        func test_stop_releasesPipeline() {
            startService()

            service.stop()

            XCTAssertNil(service.tracker)
        }

        func test_stop_releasesFrameTimingSource() {
            startService()
            weak var source = service.frameTimingSource
            XCTAssertNotNil(source)

            service.stop()

            // The source owns the CADisplayLink and invalidates it on deinit.
            XCTAssertNil(source)
        }

        func test_debuggerAttached_disablesService() {
            service = makeService(debuggerAttached: { true })
            let logger = MockLogger()
            service.install(otel: otel, logger: logger)
            service.start()
            startPart(.foreground)
            endPart()

            XCTAssertNil(service.tracker)
            XCTAssertTrue(smoothnessSpans.isEmpty)
            XCTAssertTrue(logger.loggedMessages.contains { $0.level == .warning && $0.message.contains("debugger") })
        }

        func test_debuggerAttached_withAllowWatchdogInDebugger_keepsServiceEnabled() {
            service = makeService(debuggerAttached: { true }, environment: ["EMBAllowWatchdogInDebugger": "1"])
            startService()
            startPart(.foreground)
            endPart()

            XCTAssertNotNil(service.tracker)
            XCTAssertEqual(endedSmoothnessSpans.count, 1)
        }

        func test_startOffMain_buildsPipelineOnMain() {
            service.install(otel: otel)
            currentSession = MockSession.with(id: .random, state: .foreground)

            // A semaphore, not an expectation: waiting on it doesn't run main, so the hop can't
            // land before the checks below.
            let started = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                self.service.start()
                started.signal()
            }
            started.wait()
            XCTAssertNil(service.tracker)

            drainMain()

            XCTAssertNotNil(service.tracker)
            // The part was already current, so activation opens it.
            XCTAssertEqual(service.tracker?.openPartId, currentSession?.id)
            XCTAssertEqual(smoothnessSpans.count, 1)
        }

        func test_stopBeforeActivateRuns_leavesNoPipeline() {
            service.install(otel: otel)
            currentSession = MockSession.with(id: .random, state: .foreground)

            let started = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                self.service.start()
                started.signal()
            }
            started.wait()
            // `activate()` is still queued on main.
            service.stop()
            drainMain()

            XCTAssertNil(service.tracker)
            XCTAssertTrue(smoothnessSpans.isEmpty)
        }

        func test_notStarted_createsNoSpans() {
            service.install(otel: otel)

            startPart(.foreground)
            endPart()

            XCTAssertNil(service.tracker)
            XCTAssertTrue(smoothnessSpans.isEmpty)
        }

        func test_openPartFrameCount_isZeroWhenNotStarted() {
            service.install(otel: otel)
            startPart(.foreground)

            XCTAssertEqual(service.openPartFrameCount, 0)
        }

        func test_openPartFrameCount_countsFramesInOpenPartOnly() throws {
            startService()
            startPart(.foreground)
            let tracker = try XCTUnwrap(service.tracker)

            tracker.recordFrame(lateBy: 0)
            tracker.recordFrame(lateBy: 1.0 / 60.0)
            XCTAssertEqual(service.openPartFrameCount, 2)

            endPart()
            XCTAssertEqual(service.openPartFrameCount, 0)
        }

        func test_start_opensSpanForAlreadyForegroundPart() {
            currentSession = MockSession.with(id: .random, state: .foreground)

            startService()

            XCTAssertEqual(smoothnessSpans.count, 1)
        }

        // MARK: - Span

        func test_foregroundPartStart_opensSmoothnessSpan() throws {
            startService()

            let session = startPart(.foreground)

            let span = try XCTUnwrap(smoothnessSpans.first)
            XCTAssertEqual(smoothnessSpans.count, 1)
            XCTAssertEqual(span.type, .smoothness)
            XCTAssertEqual(span.startTime, session.startTime)
            XCTAssertNil(span.endTime)
        }

        func test_partWillEnd_endsSpanAtPartEndTime() throws {
            startService()
            let session = startPart(.foreground)
            let endTime = session.startTime.addingTimeInterval(1)

            endPart(at: endTime)

            let span = try XCTUnwrap(endedSmoothnessSpans.first)
            XCTAssertEqual(span.endTime, endTime)
        }

        func test_backgroundPartStart_createsNoSpan() {
            startService()

            startPart(.background)
            endPart()

            XCTAssertTrue(smoothnessSpans.isEmpty)
        }

        func test_partWillEnd_endsSpanWithFrameAttributes() throws {
            startService()
            startPart(.foreground)
            let tracker = try XCTUnwrap(service.tracker)

            tracker.recordFrame(lateBy: 0)
            tracker.recordFrame(lateBy: 1.0 / 60.0)
            tracker.recordFrame(lateBy: 2.5 / 60.0)
            endPart()

            let span = try XCTUnwrap(endedSmoothnessSpans.first)
            XCTAssertEqual(endedSmoothnessSpans.count, 1)
            XCTAssertNotNil(span.endTime)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyFrameCount] as? Int, 3)
            XCTAssertEqual(
                span.attributes[SpanSemantics.Smoothness.keyNormalizedDroppedFrames] as? Double ?? 0,
                3.5,
                accuracy: accuracy
            )
        }

        func test_zeroFramePart_stillEndsSpan() throws {
            startService()
            startPart(.foreground)

            endPart()

            let span = try XCTUnwrap(endedSmoothnessSpans.first)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyFrameCount] as? Int, 0)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyNormalizedDroppedFrames] as? Double, 0)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyHangCount] as? Int, 0)
        }

        // MARK: - Hang count

        func test_partWithoutHangs_hasZeroHangCount() throws {
            startService()
            startPart(.foreground)
            let tracker = try XCTUnwrap(service.tracker)

            tracker.recordFrame(lateBy: 0)
            tracker.recordFrame(lateBy: 2.0 / 60.0)
            tracker.recordFrame(lateBy: tracker.hangThreshold)
            endPart()

            let span = try XCTUnwrap(endedSmoothnessSpans.first)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyHangCount] as? Int, 0)
        }

        func test_hangCount_countsEveryTickPastHangThreshold() throws {
            startService()
            startPart(.foreground)
            let tracker = try XCTUnwrap(service.tracker)

            tracker.recordFrame(lateBy: 0)
            tracker.recordFrame(lateBy: tracker.hangThreshold + 0.001)
            tracker.recordFrame(lateBy: 0)
            tracker.recordFrame(lateBy: 5)
            endPart()

            let span = try XCTUnwrap(endedSmoothnessSpans.first)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyHangCount] as? Int, 2)
        }

        func test_hangCount_isNotLimitedByHangPerSession() throws {
            startService()
            service.onConfigUpdated(MockEmbraceConfigurable(hangLimits: HangLimits(hangPerSession: 1)))
            startPart(.foreground)
            let tracker = try XCTUnwrap(service.tracker)

            for _ in 0..<3 {
                tracker.recordFrame(lateBy: 1)
            }
            endPart()

            let span = try XCTUnwrap(endedSmoothnessSpans.first)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyHangCount] as? Int, 3)
        }

        func test_hangCount_usesUpdatedHangThreshold() throws {
            startService()
            service.onConfigUpdated(MockEmbraceConfigurable(hangLimits: HangLimits(hangThreshold: 0.5)))
            startPart(.foreground)
            let tracker = try XCTUnwrap(service.tracker)

            tracker.recordFrame(lateBy: 0.3)
            tracker.recordFrame(lateBy: 0.6)
            endPart()

            let span = try XCTUnwrap(endedSmoothnessSpans.first)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyHangCount] as? Int, 1)
        }

        func test_hangCount_doesNotCarryIntoNextPart() throws {
            startService()
            startPart(.foreground)
            try XCTUnwrap(service.tracker).recordFrame(lateBy: 1)
            endPart()

            startPart(.foreground)
            try XCTUnwrap(service.tracker).recordFrame(lateBy: 0)
            endPart()

            XCTAssertEqual(endedSmoothnessSpans.count, 2)
            XCTAssertEqual(endedSmoothnessSpans[0].attributes[SpanSemantics.Smoothness.keyHangCount] as? Int, 1)
            XCTAssertEqual(endedSmoothnessSpans[1].attributes[SpanSemantics.Smoothness.keyHangCount] as? Int, 0)
        }

        func test_backgroundPartWillEnd_doesNotEndForegroundSpan() {
            startService()
            startPart(.foreground)

            endPart(MockSession.with(id: .random, state: .background))

            XCTAssertEqual(smoothnessSpans.count, 1)
            XCTAssertTrue(endedSmoothnessSpans.isEmpty)
        }

        func test_eachForegroundPart_getsItsOwnSpan() {
            startService()

            startPart(.foreground)
            endPart()
            startPart(.foreground)
            endPart()

            XCTAssertEqual(smoothnessSpans.count, 2)
            XCTAssertEqual(endedSmoothnessSpans.count, 2)
        }

        func test_stop_endsOpenSpan() {
            startService()
            startPart(.foreground)

            service.stop()

            XCTAssertEqual(endedSmoothnessSpans.count, 1)
        }

        func test_partWillEndOffMain_endsSpanSynchronously() throws {
            startService()
            startPart(.foreground)

            let posted = expectation(description: "posted off main")
            var endedBeforePostReturned = 0
            DispatchQueue.global().async {
                self.endPart()
                endedBeforePostReturned = self.endedSmoothnessSpans.count
                posted.fulfill()
            }
            wait(for: [posted], timeout: 1)

            XCTAssertEqual(endedBeforePostReturned, 1)
        }

        func test_partWillEndOffMain_whileMainTicks_endsSpanOnce() throws {
            startService()
            startPart(.foreground)
            let tracker = try XCTUnwrap(service.tracker)

            let ended = expectation(description: "ended off main")
            DispatchQueue.global().async {
                self.endPart()
                ended.fulfill()
            }
            for _ in 0..<10_000 {
                tracker.recordFrame(lateBy: 0)
            }
            wait(for: [ended], timeout: 5)

            XCTAssertEqual(endedSmoothnessSpans.count, 1)
            XCTAssertFalse(tracker.isSessionOpen)
        }

        // MARK: - Checkpoint

        func test_foregroundPartStart_opensSpanAsIncomplete() throws {
            startService()

            startPart(.foreground)

            let span = try XCTUnwrap(smoothnessSpans.first)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyComplete] as? Bool, false)
            XCTAssertNil(span.attributes[SpanSemantics.Smoothness.keyFrameCount])
        }

        func test_partWillEnd_marksSpanComplete() throws {
            startService()
            startPart(.foreground)

            endPart()

            let span = try XCTUnwrap(endedSmoothnessSpans.first)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyComplete] as? Bool, true)
        }

        func test_willTerminate_marksSpanComplete() throws {
            startService()
            startPart(.foreground)

            postWillTerminate()

            let span = try XCTUnwrap(endedSmoothnessSpans.first)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyComplete] as? Bool, true)
        }

        func test_checkpoint_writesMetricsSoFarToOpenSpan() throws {
            startService()
            startPart(.foreground)
            let tracker = try XCTUnwrap(service.tracker)
            let before = Date()

            tracker.recordFrame(lateBy: 0)
            tracker.recordFrame(lateBy: 1.0 / 60.0)
            tracker.recordFrame(lateBy: 1)
            service.checkpoint()

            let span = try XCTUnwrap(smoothnessSpans.first)
            XCTAssertNil(span.endTime)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyFrameCount] as? Int, 3)
            XCTAssertEqual(
                span.attributes[SpanSemantics.Smoothness.keyNormalizedDroppedFrames] as? Double ?? 0,
                1 + tracker.hangThreshold * 60,
                accuracy: accuracy
            )
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyHangCount] as? Int, 1)
            XCTAssertEqual(peakThermalState(of: span), SpanSemantics.Smoothness.ThermalState.nominal)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyComplete] as? Bool, false)
            let checkpointTime = try XCTUnwrap(span.attributes[SpanSemantics.Smoothness.keyCheckpointTime] as? EMBInt)
            XCTAssertGreaterThanOrEqual(checkpointTime, before.nanosecondsSince1970Truncated)
            XCTAssertLessThanOrEqual(checkpointTime, Date().nanosecondsSince1970Truncated)
        }

        func test_checkpoint_includesThermalStateWithoutNotification() {
            startService()
            startPart(.foreground)

            thermalState = .serious
            service.checkpoint()
            thermalState = .nominal
            endPart()

            XCTAssertEqual(peakThermalState(of: endedSmoothnessSpans.first), SpanSemantics.Smoothness.ThermalState.serious)
        }

        func test_partWillEnd_afterCheckpoint_overwritesWithFinalMetrics() throws {
            startService()
            startPart(.foreground)
            let tracker = try XCTUnwrap(service.tracker)

            tracker.recordFrame(lateBy: 0)
            service.checkpoint()
            tracker.recordFrame(lateBy: 0)
            endPart()

            let span = try XCTUnwrap(endedSmoothnessSpans.first)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyFrameCount] as? Int, 2)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyComplete] as? Bool, true)
        }

        func test_checkpoint_withNoOpenPart_isNoOp() throws {
            startService()
            startPart(.foreground)
            endPart()
            let span = try XCTUnwrap(endedSmoothnessSpans.first as? MockSpan)

            service.checkpoint()

            XCTAssertEqual(span.ignoredMutationCount, 0)
            XCTAssertNil(span.attributes[SpanSemantics.Smoothness.keyCheckpointTime])
        }

        func test_checkpoint_beforeStart_isNoOp() {
            service.install(otel: otel)

            service.checkpoint()

            XCTAssertTrue(smoothnessSpans.isEmpty)
        }

        func test_checkpointsOffMain_racingPartWillEnd_neverOverwriteFinalMetrics() throws {
            startService()
            startPart(.foreground)
            let tracker = try XCTUnwrap(service.tracker)
            for _ in 0..<100 {
                tracker.recordFrame(lateBy: 0)
            }

            let done = expectation(description: "checkpoints done")
            let stop = EmbraceAtomic(false)
            DispatchQueue.global().async {
                while !stop.load() {
                    self.service.checkpoint()
                }
                done.fulfill()
            }
            for _ in 0..<1_000 {
                tracker.recordFrame(lateBy: 0)
            }
            endPart()
            stop.store(true)
            wait(for: [done], timeout: 5)

            let span = try XCTUnwrap(endedSmoothnessSpans.first as? MockSpan)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyFrameCount] as? Int, 1_100)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyComplete] as? Bool, true)
            XCTAssertEqual(span.ignoredMutationCount, 0)
        }

        func test_checkpointTimer_writesMetricsWhileSpanIsOpen() throws {
            service = makeService(checkpointInterval: 0.05)
            startService()
            startPart(.foreground)
            try XCTUnwrap(service.tracker).recordFrame(lateBy: 0)
            let span = try XCTUnwrap(smoothnessSpans.first)

            let waited = expectation(description: "past several intervals")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { waited.fulfill() }
            wait(for: [waited], timeout: 2)
            // Ends the span, which waits for any checkpoint in flight, so the span can be read safely.
            // The end doesn't write a checkpoint time, so one being set means the timer fired.
            service.stop()

            XCTAssertNotNil(span.attributes[SpanSemantics.Smoothness.keyCheckpointTime])
        }

        func test_checkpointTimer_stopsWhenSpanEnds() throws {
            service = makeService(checkpointInterval: 0.05)
            startService()
            startPart(.foreground)

            endPart()
            let ended = expectation(description: "past several intervals")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { ended.fulfill() }
            wait(for: [ended], timeout: 2)

            let span = try XCTUnwrap(endedSmoothnessSpans.first as? MockSpan)
            XCTAssertNil(span.attributes[SpanSemantics.Smoothness.keyCheckpointTime])
            XCTAssertEqual(span.ignoredMutationCount, 0)
        }

        func test_zeroCheckpointInterval_writesNoCheckpoints() throws {
            service = makeService(checkpointInterval: 0)
            startService()
            startPart(.foreground)

            let waited = expectation(description: "waited")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { waited.fulfill() }
            wait(for: [waited], timeout: 2)

            XCTAssertNil(try XCTUnwrap(smoothnessSpans.first).attributes[SpanSemantics.Smoothness.keyCheckpointTime])
        }

        // MARK: - Thermal state

        func test_peakThermalState_isStateAtOpenWhenUnchanged() {
            thermalState = .fair
            startService()
            startPart(.foreground)

            // Drops without a notification, so `fair` can only come from the seed at open.
            thermalState = .nominal
            endPart()

            XCTAssertEqual(peakThermalState(of: endedSmoothnessSpans.first), SpanSemantics.Smoothness.ThermalState.fair)
        }

        func test_peakThermalState_keepsMostSevereStateSeen() {
            startService()
            startPart(.foreground)

            changeThermalState(to: .critical)
            changeThermalState(to: .fair)
            changeThermalState(to: .nominal)
            endPart()

            XCTAssertEqual(peakThermalState(of: endedSmoothnessSpans.first), SpanSemantics.Smoothness.ThermalState.critical)
        }

        func test_peakThermalState_includesStateAtCloseWithoutNotification() {
            startService()
            startPart(.foreground)

            thermalState = .serious
            endPart()

            XCTAssertEqual(peakThermalState(of: endedSmoothnessSpans.first), SpanSemantics.Smoothness.ThermalState.serious)
        }

        func test_peakThermalState_offMainNotification_isApplied() {
            startService()
            startPart(.foreground)

            let posted = expectation(description: "posted off main")
            DispatchQueue.global().async {
                self.changeThermalState(to: .serious)
                self.thermalState = .nominal
                posted.fulfill()
            }
            wait(for: [posted], timeout: 1)
            endPart()

            XCTAssertEqual(peakThermalState(of: endedSmoothnessSpans.first), SpanSemantics.Smoothness.ThermalState.serious)
        }

        func test_peakThermalState_doesNotCarryIntoNextPart() {
            startService()
            startPart(.foreground)
            changeThermalState(to: .critical)
            endPart()

            thermalState = .nominal
            startPart(.foreground)
            endPart()

            XCTAssertEqual(endedSmoothnessSpans.count, 2)
            XCTAssertEqual(peakThermalState(of: endedSmoothnessSpans.last), SpanSemantics.Smoothness.ThermalState.nominal)
        }

        func test_peakThermalState_changeWithNoOpenPart_isIgnored() {
            startService()
            startPart(.background)

            changeThermalState(to: .critical)
            thermalState = .nominal
            startPart(.foreground)
            endPart()

            XCTAssertEqual(peakThermalState(of: endedSmoothnessSpans.first), SpanSemantics.Smoothness.ThermalState.nominal)
        }

        func test_peakThermalState_isSetOnStop() {
            startService()
            startPart(.foreground)
            changeThermalState(to: .serious)

            service.stop()

            XCTAssertEqual(peakThermalState(of: endedSmoothnessSpans.first), SpanSemantics.Smoothness.ThermalState.serious)
        }

        // MARK: - Termination

        func test_willTerminate_endsOpenSpanWithFrameAttributes() throws {
            startService()
            startPart(.foreground)
            let tracker = try XCTUnwrap(service.tracker)

            tracker.recordFrame(lateBy: 0)
            tracker.recordFrame(lateBy: 1.0 / 60.0)
            postWillTerminate()

            let span = try XCTUnwrap(endedSmoothnessSpans.first)
            XCTAssertEqual(endedSmoothnessSpans.count, 1)
            XCTAssertNotNil(span.endTime)
            XCTAssertEqual(span.status, .unset)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyFrameCount] as? Int, 2)
            XCTAssertEqual(
                span.attributes[SpanSemantics.Smoothness.keyNormalizedDroppedFrames] as? Double ?? 0,
                1,
                accuracy: accuracy
            )
            XCTAssertEqual(peakThermalState(of: span), SpanSemantics.Smoothness.ThermalState.nominal)
            XCTAssertFalse(tracker.isSessionOpen)
        }

        func test_willTerminate_flushesStorageAfterEndingSpan() {
            startService()
            startPart(.foreground)

            postWillTerminate()

            XCTAssertEqual(flushes, [1])
        }

        func test_willTerminate_withNoOpenPart_isNoOp() {
            startService()
            startPart(.foreground)
            endPart()

            postWillTerminate()

            XCTAssertEqual(endedSmoothnessSpans.count, 1)
            XCTAssertTrue(flushes.isEmpty)
        }

        func test_willTerminate_inBackgroundPart_isNoOp() {
            startService()
            startPart(.background)

            postWillTerminate()

            XCTAssertTrue(smoothnessSpans.isEmpty)
            XCTAssertTrue(flushes.isEmpty)
        }

        func test_willTerminate_beforeStart_isNoOp() {
            service.install(otel: otel)

            postWillTerminate()

            XCTAssertTrue(flushes.isEmpty)
        }

        func test_willTerminate_thenPartWillEnd_endsSpanOnce() throws {
            startService()
            startPart(.foreground)
            let tracker = try XCTUnwrap(service.tracker)
            tracker.recordFrame(lateBy: 0)

            postWillTerminate()
            tracker.recordFrame(lateBy: 0)
            endPart()

            XCTAssertEqual(smoothnessSpans.count, 1)
            XCTAssertEqual(endedSmoothnessSpans.count, 1)
            XCTAssertEqual(endedSmoothnessSpans.first?.attributes[SpanSemantics.Smoothness.keyFrameCount] as? Int, 1)
        }

        func test_willTerminate_thenDidBecomeActive_doesNotReopenPart() throws {
            startService()
            startPart(.foreground)

            postWillTerminate()
            postDidBecomeActive()
            drainMain()

            XCTAssertEqual(smoothnessSpans.count, 1)
            XCTAssertFalse(try XCTUnwrap(service.tracker).isSessionOpen)
        }

        func test_willTerminate_twice_flushesOnce() {
            startService()
            startPart(.foreground)

            postWillTerminate()
            postWillTerminate()

            XCTAssertEqual(endedSmoothnessSpans.count, 1)
            XCTAssertEqual(flushes, [1])
        }

        // MARK: - Config

        func test_onConfigUpdated_appliesHangThreshold() throws {
            startService()

            service.onConfigUpdated(MockEmbraceConfigurable(hangLimits: HangLimits(hangThreshold: 0.5)))

            XCTAssertEqual(service.hangThreshold, 0.5)
            XCTAssertEqual(try XCTUnwrap(service.tracker).hangThreshold, 0.5)
        }

        func test_onConfigUpdated_beforeStart_isAppliedOnStart() throws {
            service.onConfigUpdated(MockEmbraceConfigurable(hangLimits: HangLimits(hangThreshold: 0.5)))

            startService()

            XCTAssertEqual(try XCTUnwrap(service.tracker).hangThreshold, 0.5)
        }
    }

    // MARK: - SessionController integration

    final class SmoothnessCaptureServiceSessionControllerTests: XCTestCase {

        private var storage: EmbraceStorage!
        private var controller: SessionController!
        private var userSessionController: UserSessionController!
        private var otel: MockOTelSignalsHandler!
        private var service: SmoothnessCaptureService!
        private let sdkStateProvider = MockEmbraceSDKStateProvider()

        override func setUpWithError() throws {
            try super.setUpWithError()
            storage = try EmbraceStorage.createInMemoryDb()
            sdkStateProvider.isEnabled = true
            otel = MockOTelSignalsHandler()

            controller = SessionController(storage: storage, upload: nil, config: nil)
            controller.sdkStateProvider = sdkStateProvider
            controller.otel = otel
            userSessionController = UserSessionController(storage: storage, config: MockEmbraceConfigurable())
            userSessionController.sessionController = controller
            controller.userSessionController = userSessionController

            service = SmoothnessCaptureService(
                currentSession: { [unowned self] in self.controller.currentSession },
                notificationCenter: .default,
                embraceNotificationCenter: Embrace.notificationCenter,
                flushStorage: { [unowned self] in self.storage.coreData.save(allowMainQueue: true) },
                debuggerAttached: { false }
            )
            service.install(otel: otel)
            service.start()
        }

        override func tearDownWithError() throws {
            service?.stop()
            service = nil
            storage?.coreData.destroy()
            storage = nil
            controller = nil
            userSessionController = nil
            otel = nil
            try super.tearDownWithError()
        }

        /// `.embraceSessionPartDidStart` is posted asynchronously on main.
        private func drainMain() {
            let drained = expectation(description: "main drained")
            DispatchQueue.main.async { drained.fulfill() }
            wait(for: [drained], timeout: 1)
        }

        private var smoothnessSpans: [EmbraceSpan] {
            otel.startedSpans.filter { $0.name == SpanSemantics.Smoothness.name }
        }

        func test_foregroundPart_spanIsEndedBeforeEndSessionReturns() throws {
            controller.startSession(state: .foreground)
            drainMain()
            let span = try XCTUnwrap(smoothnessSpans.first)
            XCTAssertNil(span.endTime)

            controller.endSession()

            // No waiting: the span must be closed by the synchronous will-end hook.
            XCTAssertNotNil(span.endTime)
            XCTAssertNotNil(span.attributes[SpanSemantics.Smoothness.keyFrameCount])
            XCTAssertNotNil(span.attributes[SpanSemantics.Smoothness.keyPeakThermalState])
            XCTAssertNotNil(span.attributes[SpanSemantics.Smoothness.keyHangCount])
        }

        func test_foregroundPartEndedOffMain_spanIsEndedBeforeEndSessionReturns() throws {
            controller.startSession(state: .foreground)
            drainMain()
            let span = try XCTUnwrap(smoothnessSpans.first)
            let tracker = try XCTUnwrap(service.tracker)
            let serviceOnSessionClosed = tracker.onSessionClosed
            var closedOnMain: Bool?
            tracker.onSessionClosed = { partId, stats in
                closedOnMain = Thread.isMainThread
                serviceOnSessionClosed?(partId, stats)
            }

            // `async`, not `sync`: a `sync` from main runs the block on main.
            let ended = expectation(description: "ended off main")
            var endedBeforeEndSessionReturned = false
            controller.queue.async {
                _ = self.controller.endSession()
                endedBeforeEndSessionReturned = span.endTime != nil
                ended.fulfill()
            }
            wait(for: [ended], timeout: 1)

            XCTAssertEqual(closedOnMain, false)
            XCTAssertTrue(endedBeforeEndSessionReturned)
        }

        func test_coldStartSwapToForeground_opensAndClosesSpan() throws {
            let session = try XCTUnwrap(controller.startSession(state: .background))
            XCTAssertTrue(session.coldStart)
            drainMain()
            XCTAssertTrue(smoothnessSpans.isEmpty)

            // What `iOSSessionLifecycle.appDidBecomeActive` does inside the launch grace period.
            controller.update(state: .foreground)
            NotificationCenter.default.post(name: Notification.Name("UIApplicationDidBecomeActiveNotification"), object: nil)
            drainMain()

            let span = try XCTUnwrap(smoothnessSpans.first)
            XCTAssertEqual(service.tracker?.openPartId, session.id)

            controller.endSession()

            XCTAssertNotNil(span.endTime)
        }

        func test_backgroundPart_hasNoSpan() throws {
            controller.startSession(state: .foreground)
            drainMain()
            controller.startSession(state: .background)
            drainMain()

            XCTAssertEqual(smoothnessSpans.count, 1)
            XCTAssertNotNil(smoothnessSpans.first?.endTime)
        }

        /// The tracker observes did-become-active before `iOSSessionLifecycle` swaps the part to
        /// foreground. Its hop to the next main turn is what still catches the swap.
        func test_coldStartSwapToForeground_trackerObservesFirst_opensSpan() throws {
            let session = try XCTUnwrap(controller.startSession(state: .background))
            XCTAssertTrue(session.coldStart)
            drainMain()

            NotificationCenter.default.post(name: Notification.Name("UIApplicationDidBecomeActiveNotification"), object: nil)
            controller.update(state: .foreground)
            drainMain()

            let span = try XCTUnwrap(smoothnessSpans.first)
            XCTAssertEqual(service.tracker?.openPartId, session.id)

            controller.endSession()

            XCTAssertNotNil(span.endTime)
        }

        /// EMBR-14228: adding the sync hook doesn't change when the existing end notifications fire.
        /// The foreground-end one is still posted synchronously after the hook, with the end time,
        /// and the public one still arrives later, on main.
        func test_foregroundPartEnd_existingNotificationTimingUnchanged() throws {
            let session = try XCTUnwrap(controller.startSession(state: .foreground))
            drainMain()
            let span = try XCTUnwrap(smoothnessSpans.first)

            var order: [String] = []
            var foregroundEndTime: Date?
            var spanEndedAtForegroundEnd = false
            let syncToken = Embrace.notificationCenter.addObserver(forName: .embraceSessionPartWillEndSync, object: nil, queue: nil) { _ in
                order.append("sync")
            }
            let foregroundToken = Embrace.notificationCenter.addObserver(forName: .embraceForegroundSessionDidEnd, object: nil, queue: nil) {
                notification in
                order.append("foregroundDidEnd")
                foregroundEndTime = notification.object as? Date
                spanEndedAtForegroundEnd = span.endTime != nil
            }
            defer {
                Embrace.notificationCenter.removeObserver(syncToken)
                Embrace.notificationCenter.removeObserver(foregroundToken)
            }
            // Posted async on main, so ignore ones left over from other tests.
            let publicWillEnd = expectation(forNotification: .embraceSessionPartWillEnd, object: nil) { notification in
                guard (notification.object as? EmbraceSession)?.id == session.id else { return false }
                order.append("public")
                return true
            }

            let endTime = controller.endSession()

            XCTAssertEqual(order, ["sync", "foregroundDidEnd"])
            XCTAssertEqual(foregroundEndTime, endTime)
            XCTAssertTrue(spanEndedAtForegroundEnd)

            wait(for: [publicWillEnd], timeout: 1)

            XCTAssertEqual(order, ["sync", "foregroundDidEnd", "public"])
        }

        /// Max-duration expiry rolls the part on the controller's queue, so the service closes the
        /// span off main, at the roll time, and opens a new one for the next part.
        func test_rollPartForUserSessionExpiryOffMain_endsSpanAtRollTimeAndOpensNext() throws {
            controller.startSession(state: .foreground)
            drainMain()
            let span = try XCTUnwrap(smoothnessSpans.first)
            let tracker = try XCTUnwrap(service.tracker)
            let serviceOnSessionClosed = tracker.onSessionClosed
            var closedOnMain: Bool?
            tracker.onSessionClosed = { partId, stats in
                closedOnMain = Thread.isMainThread
                serviceOnSessionClosed?(partId, stats)
            }
            let rollTime = Date()

            let rolled = expectation(description: "rolled off main")
            var endedBeforeRollReturned = false
            controller.queue.async {
                self.controller.rollPartForUserSessionExpiry(reason: .maxDurationReached, at: rollTime)
                endedBeforeRollReturned = span.endTime != nil
                rolled.fulfill()
            }
            wait(for: [rolled], timeout: 1)
            // The next part's start is delivered async on main.
            drainMain()

            XCTAssertEqual(closedOnMain, false)
            XCTAssertTrue(endedBeforeRollReturned)
            XCTAssertEqual(span.endTime, rollTime)
            let next = try XCTUnwrap(controller.currentSession)
            XCTAssertEqual(next.startTime, rollTime)
            XCTAssertEqual(smoothnessSpans.count, 2)
            XCTAssertEqual(service.tracker?.openPartId, next.id)
            XCTAssertNil(smoothnessSpans.last?.endTime)
        }
    }

    // MARK: - Recovery after a kill or crash

    /// Spans are persisted through the real signals handler, then the part is abandoned without ending,
    /// as a watchdog or jetsam kill leaves it, and recovered the way the next launch does it.
    final class SmoothnessCaptureServiceRecoveryTests: XCTestCase {

        private var storage: EmbraceStorage!
        private var sessionController: MockSessionController!
        private var logController: LogController!
        private var handler: DefaultOTelSignalsHandler!
        private var service: SmoothnessCaptureService!
        private var notificationCenter: NotificationCenter!
        private var embraceNotificationCenter: NotificationCenter!

        override func setUpWithError() throws {
            try super.setUpWithError()
            storage = try EmbraceStorage.createInMemoryDb()
            sessionController = MockSessionController()
            sessionController.storage = storage
            logController = LogController(
                storage: storage,
                upload: SpyEmbraceLogUploader(),
                sessionController: sessionController,
                queue: DispatchQueue(label: "io.embrace.tests.smoothnessRecovery.logs")
            )
            handler = DefaultOTelSignalsHandler(
                storage: storage,
                sessionController: sessionController,
                logController: logController,
                limiter: MockOTelSignalsLimiter(),
                sanitizer: MockOTelSignalsSanitizer(),
                bridge: MockOTelSignalBridge()
            )
            sessionController.spanHandler = handler
            notificationCenter = NotificationCenter()
            embraceNotificationCenter = NotificationCenter()

            service = SmoothnessCaptureService(
                currentSession: { [unowned self] in self.sessionController.currentSession },
                notificationCenter: notificationCenter,
                embraceNotificationCenter: embraceNotificationCenter,
                flushStorage: { [unowned self] in self.storage.coreData.save(allowMainQueue: true) },
                thermalState: { .nominal },
                checkpointInterval: 0,
                debuggerAttached: { false }
            )
        }

        override func tearDownWithError() throws {
            service = nil
            handler = nil
            logController = nil
            sessionController = nil
            storage?.coreData.destroy()
            storage = nil
            notificationCenter = nil
            embraceNotificationCenter = nil
            try super.tearDownWithError()
        }

        /// Starts a foreground part with an open smoothness span that has counted `frames` frames.
        private func startPartWithSpan(frames: Int) throws -> EmbraceSession {
            let session = try XCTUnwrap(sessionController.startSession(state: .foreground))
            service.install(otel: handler)
            service.start()
            let tracker = try XCTUnwrap(service.tracker)
            XCTAssertEqual(tracker.openPartId, session.id)
            for _ in 0..<frames {
                tracker.recordFrame(lateBy: 0)
            }
            return session
        }

        /// Recovers `session` as `UnsentDataHandler` does on the next launch, and returns its smoothness
        /// span from the payload.
        private func recoverSmoothnessSpan(of session: EmbraceSession, crashReportId: String? = nil) throws -> SpanPayload {
            let heartbeat = Date()
            let recovered = try XCTUnwrap(
                storage.updateSession(session: session, lastHeartbeatTime: heartbeat, crashReportId: crashReportId)
            )
            // `closeOpenSpans` only closes spans from earlier processes, so relaunch into a new process.
            storage.coreData.fetchAndPerform(withRequest: NSFetchRequest<SpanRecord>(entityName: SpanRecord.entityName)) { records, context in
                for record in records {
                    record.processIdRaw = EmbraceIdentifier.random.stringValue
                }
                try? context.save()
            }
            storage.closeOpenSpans(endTime: heartbeat)

            let (spans, snapshots) = SpansPayloadBuilder.build(for: recovered, storage: storage)
            XCTAssertFalse(snapshots.contains { $0.name == SpanSemantics.Smoothness.name })
            let smoothness = spans.filter { $0.name == SpanSemantics.Smoothness.name }
            XCTAssertEqual(smoothness.count, 1)
            return try XCTUnwrap(smoothness.first)
        }

        private func attribute(_ key: String, of payload: SpanPayload) -> String? {
            payload.attributes.first { $0.key == key }?.value
        }

        func test_killedPart_keepsCheckpointedMetrics_andIsFlaggedIncomplete() throws {
            let session = try startPartWithSpan(frames: 3)
            service.checkpoint()

            // Killed without a crash report: the part never ends and the span is never closed.
            let span = try recoverSmoothnessSpan(of: session)

            XCTAssertEqual(attribute(SpanSemantics.Smoothness.keyFrameCount, of: span), "3")
            XCTAssertNotNil(attribute(SpanSemantics.Smoothness.keyNormalizedDroppedFrames, of: span))
            XCTAssertEqual(attribute(SpanSemantics.Smoothness.keyHangCount, of: span), "0")
            XCTAssertEqual(attribute(SpanSemantics.Smoothness.keyPeakThermalState, of: span), SpanSemantics.Smoothness.ThermalState.nominal)
            XCTAssertNotNil(attribute(SpanSemantics.Smoothness.keyCheckpointTime, of: span))
            XCTAssertEqual(attribute(SpanSemantics.Smoothness.keyComplete, of: span), "false")
            XCTAssertNotEqual(span.status, EmbraceSpanStatus.error.name)
        }

        func test_crashedPart_keepsCheckpointedMetrics_andIsFailed() throws {
            let session = try startPartWithSpan(frames: 2)
            service.checkpoint()

            let span = try recoverSmoothnessSpan(of: session, crashReportId: "crash")

            XCTAssertEqual(attribute(SpanSemantics.Smoothness.keyFrameCount, of: span), "2")
            XCTAssertEqual(attribute(SpanSemantics.Smoothness.keyComplete, of: span), "false")
            XCTAssertEqual(span.status, EmbraceSpanStatus.error.name)
        }

        func test_killedPartBeforeFirstCheckpoint_isFlaggedIncompleteWithoutMetrics() throws {
            let session = try startPartWithSpan(frames: 2)

            let span = try recoverSmoothnessSpan(of: session)

            XCTAssertEqual(attribute(SpanSemantics.Smoothness.keyComplete, of: span), "false")
            XCTAssertNil(attribute(SpanSemantics.Smoothness.keyFrameCount, of: span))
            XCTAssertNil(attribute(SpanSemantics.Smoothness.keyCheckpointTime, of: span))
        }

        func test_cleanlyEndedPart_isStoredComplete_withFinalMetrics() throws {
            let session = try startPartWithSpan(frames: 1)
            service.checkpoint()
            try XCTUnwrap(service.tracker).recordFrame(lateBy: 0)

            embraceNotificationCenter.post(
                name: .embraceSessionPartWillEndSync,
                object: session,
                userInfo: [SessionController.sessionPartWillEndSyncEndTimeKey: Date()]
            )

            let span = try recoverSmoothnessSpan(of: session)
            XCTAssertEqual(attribute(SpanSemantics.Smoothness.keyFrameCount, of: span), "2")
            XCTAssertEqual(attribute(SpanSemantics.Smoothness.keyComplete, of: span), "true")
        }
    }

#endif  // !os(watchOS) && !os(macOS)
