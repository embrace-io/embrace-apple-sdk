//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import EmbraceCommonInternal
    import EmbraceConfiguration
    import EmbraceSemantics
    import EmbraceStorageInternal
    import TestSupport
    import XCTest

    @testable import EmbraceCore

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
            try XCTSkipIf(
                isDebuggerAttached() && ProcessInfo.processInfo.environment["EMBAllowWatchdogInDebugger"] != "1",
                "SmoothnessCaptureService disables itself under a debugger"
            )
            otel = MockOTelSignalsHandler()
            notificationCenter = NotificationCenter()
            embraceNotificationCenter = NotificationCenter()
            currentSession = nil
            thermalState = .nominal
            flushes = []
            service = SmoothnessCaptureService(
                currentSession: { [unowned self] in self.currentSession },
                notificationCenter: notificationCenter,
                embraceNotificationCenter: embraceNotificationCenter,
                flushStorage: { [unowned self] in self.flushes.append(self.endedSmoothnessSpans.count) },
                thermalState: { [unowned self] in self.thermalState }
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

        func test_notStarted_createsNoSpans() {
            service.install(otel: otel)

            startPart(.foreground)
            endPart()

            XCTAssertNil(service.tracker)
            XCTAssertTrue(smoothnessSpans.isEmpty)
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

        // MARK: - Thermal state

        func test_peakThermalState_isStateAtOpenWhenUnchanged() {
            thermalState = .fair
            startService()
            startPart(.foreground)

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
            XCTAssertNotEqual(span.status, .error)
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
            try XCTSkipIf(
                isDebuggerAttached() && ProcessInfo.processInfo.environment["EMBAllowWatchdogInDebugger"] != "1",
                "SmoothnessCaptureService disables itself under a debugger"
            )
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
                flushStorage: { [unowned self] in self.storage.coreData.save(allowMainQueue: true) }
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

            controller.queue.sync { _ = self.controller.endSession() }

            XCTAssertNotNil(span.endTime)
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
    }

#endif  // !os(watchOS) && !os(macOS)
