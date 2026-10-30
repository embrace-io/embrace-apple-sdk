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

    @_spi(Private) @testable import EmbraceCore
    @testable import EmbraceUploadInternal

    final class SmoothnessCaptureServiceTests: XCTestCase {

        private let willEnterForegroundNotification = Notification.Name("UIApplicationWillEnterForegroundNotification")
        private let willResignActiveNotification = Notification.Name("UIApplicationWillResignActiveNotification")
        /// Shared so the suite installs one `sendEvent` swizzle.
        private static let windowEventObserver = WindowEventObserver()
        private let frameDuration = 1.0 / 60.0

        private var otel: MockOTelSignalsHandler!
        private var notificationCenter: NotificationCenter!
        private var embraceNotificationCenter: NotificationCenter!
        private var currentSession: EmbraceSession?
        /// Session span of each part started with `startPart`.
        private var sessionSpans: [String: MockSpan] = [:]
        private var thermalState: ProcessInfo.ThermalState = .nominal
        private var service: SmoothnessCaptureService!

        override func setUpWithError() throws {
            try super.setUpWithError()
            otel = MockOTelSignalsHandler()
            notificationCenter = NotificationCenter()
            embraceNotificationCenter = NotificationCenter()
            currentSession = nil
            sessionSpans = [:]
            thermalState = .nominal
            service = makeService()
        }

        /// The debugger check defaults to detached, so the suite also runs from Xcode. The remote config gate
        /// is bypassed by default; the remote config tests turn it back on. There's no display link by
        /// default, so no real frame lands while a test waits with a part open; frames are recorded
        /// through the accumulator.
        private func makeService(
            debuggerAttached: @escaping () -> Bool = { false },
            environment: [String: String] = [:],
            ignoresRemoteConfig: Bool = true,
            attachesDisplayLink: Bool = false
        ) -> SmoothnessCaptureService {
            SmoothnessCaptureService(
                currentSession: { [unowned self] in self.currentSession },
                sessionSpan: { [unowned self] partId in
                    self.currentSession?.id == partId ? self.sessionSpans[partId.stringValue] : nil
                },
                notificationCenter: notificationCenter,
                embraceNotificationCenter: embraceNotificationCenter,
                thermalState: { [unowned self] in self.thermalState },
                debuggerAttached: debuggerAttached,
                environment: environment,
                ignoresRemoteConfig: ignoresRemoteConfig,
                attachesDisplayLink: attachesDisplayLink,
                makeActivityMonitor: { ActivityMonitor(windowEventObserver: Self.windowEventObserver, runLoop: nil) }
            )
        }

        override func tearDown() {
            service?.stop()
            service = nil
            otel = nil
            notificationCenter = nil
            embraceNotificationCenter = nil
            currentSession = nil
            sessionSpans = [:]
            super.tearDown()
        }

        // MARK: - Helpers

        private func startService() {
            service.install(otel: otel)
            service.start()
        }

        /// Makes a new part current, with its own session span, without posting its start.
        @discardableResult
        private func makeCurrentPart(_ state: SessionState) -> EmbraceSession {
            let session = MockSession.with(id: .random, state: state)
            currentSession = session
            sessionSpans[session.id.stringValue] = MockSpan(name: SpanSemantics.Session.name)
            return session
        }

        @discardableResult
        private func startPart(_ state: SessionState) -> EmbraceSession {
            let session = makeCurrentPart(state)
            notificationCenter.post(name: .embraceSessionPartDidStart, object: session)
            return session
        }

        private func endPart(_ session: EmbraceSession? = nil) {
            embraceNotificationCenter.post(name: .embraceSessionPartWillEndSync, object: session ?? currentSession)
        }

        private func record(delayInFrames: Double) throws {
            try XCTUnwrap(service.accumulator).record(
                MeasuredTick(FrameTimingSource.Tick(timestamp: 0, delay: frameDuration * delayInFrames, frameInterval: frameDuration, previousFrameInterval: frameDuration))
            )
        }

        private func changeThermalState(to state: ProcessInfo.ThermalState) {
            thermalState = state
            notificationCenter.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        }

        private func span(of session: EmbraceSession) -> MockSpan? {
            sessionSpans[session.id.stringValue]
        }

        private func droppedFrames(of session: EmbraceSession) -> Int? {
            span(of: session)?.attributes[SpanSemantics.Smoothness.keyDroppedFrames] as? Int
        }

        private func expectedFrames(of session: EmbraceSession) -> Int? {
            span(of: session)?.attributes[SpanSemantics.Smoothness.keyExpectedFrames] as? Int
        }

        private func hangCount(of session: EmbraceSession) -> Int? {
            span(of: session)?.attributes[SpanSemantics.Smoothness.keyHangCount] as? Int
        }

        private func peakThermalState(of session: EmbraceSession) -> String? {
            span(of: session)?.attributes[SpanSemantics.Smoothness.keyPeakThermalState] as? String
        }

        private func hasSmoothnessAttributes(_ session: EmbraceSession) -> Bool {
            let keys = [
                SpanSemantics.Smoothness.keyDroppedFrames,
                SpanSemantics.Smoothness.keyExpectedFrames,
                SpanSemantics.Smoothness.keyHangCount,
                SpanSemantics.Smoothness.keyPeakThermalState
            ]
            return keys.contains { span(of: session)?.attributes[$0] != nil }
        }

        // MARK: - Lifecycle

        func test_stop_releasesFrameTimingSource() {
            service = makeService(attachesDisplayLink: true)
            startService()
            weak var source = service.frameTimingSource
            XCTAssertNotNil(source)

            service.stop()

            // The source owns the CADisplayLink and invalidates it on deinit.
            XCTAssertNil(source)
        }

        func test_frameTimingSource_observesServiceNotificationCenter() throws {
            startService()
            startPart(.foreground)
            let source = try XCTUnwrap(service.frameTimingSource)
            source.handleTick(timestamp: 1_000, targetTimestamp: 1_000 + frameDuration)

            notificationCenter.post(name: willEnterForegroundNotification, object: nil)
            // Only arms, since the reset dropped the previous target.
            source.handleTick(timestamp: 1_030, targetTimestamp: 1_030 + frameDuration)

            XCTAssertEqual(service.openPartFrameCount, 0)
        }

        func test_frameTimingSource_feedsAccumulator() throws {
            startService()
            let source = try XCTUnwrap(service.frameTimingSource)

            source.handleTick(timestamp: 1_000, targetTimestamp: 1_000 + frameDuration)
            source.handleTick(timestamp: 1_000 + 3 * frameDuration, targetTimestamp: 1_000 + 4 * frameDuration)

            XCTAssertEqual(service.frameCountTotals, SmoothnessFrameCounts(droppedFrames: 2, expectedFrames: 3, hangCount: 0))
        }

        func test_debuggerAttached_disablesService() {
            service = makeService(debuggerAttached: { true })
            let logger = MockLogger()
            service.install(otel: otel, logger: logger)
            service.start()
            let session = startPart(.foreground)
            endPart()

            XCTAssertNil(service.tracker)
            XCTAssertNil(service.frameCountTotals)
            XCTAssertFalse(hasSmoothnessAttributes(session))
            XCTAssertTrue(logger.loggedMessages.contains { $0.level == .warning && $0.message.contains("debugger") })
        }

        func test_debuggerAttached_withAllowWatchdogInDebugger_keepsServiceEnabled() {
            service = makeService(debuggerAttached: { true }, environment: ["EMBAllowWatchdogInDebugger": "1"])
            startService()
            let session = startPart(.foreground)
            endPart()

            XCTAssertNotNil(service.tracker)
            XCTAssertEqual(expectedFrames(of: session), 0)
        }

        func test_startOffMain_buildsCaptureOnMain() {
            service.install(otel: otel)
            let session = makeCurrentPart(.foreground)

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

            // The part was already current, so activation opens it.
            XCTAssertNotNil(service.tracker?.openPartCounts)
            endPart()
            XCTAssertEqual(expectedFrames(of: session), 0)
        }

        func test_stopBeforeActivateRuns_leavesNoCapture() {
            service.install(otel: otel)
            let session = makeCurrentPart(.foreground)

            let started = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                self.service.start()
                started.signal()
            }
            started.wait()
            // `activate()` is still queued on main.
            service.stop()
            drainMain()
            endPart()

            XCTAssertNil(service.tracker)
            XCTAssertFalse(hasSmoothnessAttributes(session))
        }

        func test_notStarted_writesNothing() {
            service.install(otel: otel)

            let session = startPart(.foreground)
            XCTAssertEqual(service.openPartFrameCount, 0)
            endPart()

            XCTAssertNil(service.tracker)
            XCTAssertNil(service.frameCountTotals)
            XCTAssertFalse(hasSmoothnessAttributes(session))
        }

        func test_openPartFrameCount_countsExpectedFramesInOpenPartOnly() throws {
            startService()
            startPart(.foreground)

            try record(delayInFrames: 0)
            try record(delayInFrames: 1)
            XCTAssertEqual(service.openPartFrameCount, 3)

            endPart()
            XCTAssertEqual(service.openPartFrameCount, 0)
        }

        func test_start_opensAlreadyForegroundPart() throws {
            let session = makeCurrentPart(.foreground)

            startService()
            try record(delayInFrames: 0)
            endPart()

            XCTAssertEqual(expectedFrames(of: session), 1)
        }

        // MARK: - Session part attributes

        func test_partWillEnd_writesFrameCountsOntoSessionSpan() throws {
            startService()
            let session = startPart(.foreground)

            try record(delayInFrames: 0)
            try record(delayInFrames: 1)
            try record(delayInFrames: 2.5)
            endPart()

            XCTAssertEqual(droppedFrames(of: session), 4)
            XCTAssertEqual(expectedFrames(of: session), 7)
            XCTAssertEqual(hangCount(of: session), 0)
            XCTAssertEqual(peakThermalState(of: session), SpanSemantics.Smoothness.ThermalState.nominal)
        }

        func test_partWillEnd_withNoTicks_writesZeros() {
            startService()
            let session = startPart(.foreground)

            endPart()

            XCTAssertEqual(droppedFrames(of: session), 0)
            XCTAssertEqual(expectedFrames(of: session), 0)
            XCTAssertEqual(hangCount(of: session), 0)
        }

        func test_noSmoothnessSpanIsCreated() {
            startService()
            startPart(.foreground)
            endPart()

            XCTAssertTrue(otel.startedSpans.isEmpty)
        }

        func test_framesBeforePartOpens_areNotCounted() throws {
            startService()
            try record(delayInFrames: 5)

            let session = startPart(.foreground)
            try record(delayInFrames: 1)
            endPart()

            XCTAssertEqual(droppedFrames(of: session), 1)
            XCTAssertEqual(expectedFrames(of: session), 2)
        }

        func test_backgroundPart_getsNoAttributes() throws {
            startService()
            let session = startPart(.background)

            try record(delayInFrames: 1)
            endPart()

            XCTAssertFalse(hasSmoothnessAttributes(session))
        }

        func test_backgroundPartWillEnd_doesNotCloseForegroundPart() {
            startService()
            let session = startPart(.foreground)

            endPart(MockSession.with(id: .random, state: .background))

            XCTAssertFalse(hasSmoothnessAttributes(session))
            XCTAssertNotNil(service.tracker?.openPartCounts)
        }

        func test_eachPartCountsItsOwnFrames() throws {
            startService()
            let first = startPart(.foreground)
            try record(delayInFrames: 3)
            endPart()

            let second = startPart(.foreground)
            try record(delayInFrames: 0)
            endPart()

            XCTAssertEqual(droppedFrames(of: first), 3)
            XCTAssertEqual(droppedFrames(of: second), 0)
            XCTAssertEqual(expectedFrames(of: second), 1)
        }

        func test_partWillEndOffMain_whileMainTicks_writesOnce() throws {
            startService()
            let session = startPart(.foreground)
            let accumulator = try XCTUnwrap(service.accumulator)
            let tick = FrameTimingSource.Tick(timestamp: 0, delay: 0, frameInterval: frameDuration, previousFrameInterval: frameDuration)

            let ended = expectation(description: "ended off main")
            DispatchQueue.global().async {
                self.endPart()
                ended.fulfill()
            }
            for _ in 0..<10_000 {
                accumulator.record(MeasuredTick(tick))
            }
            wait(for: [ended], timeout: 5)

            let expected = try XCTUnwrap(expectedFrames(of: session))
            XCTAssertLessThanOrEqual(expected, 10_000)
            XCTAssertNil(service.tracker?.openPartCounts)
        }

        // MARK: - Hang count

        func test_hangCount_countsEveryTickPastHangThreshold() throws {
            startService()
            let session = startPart(.foreground)
            let accumulator = try XCTUnwrap(service.accumulator)

            try record(delayInFrames: 0)
            accumulator.record(MeasuredTick(FrameTimingSource.Tick(timestamp: 0, delay: service.hangThreshold + 0.001, frameInterval: frameDuration, previousFrameInterval: frameDuration)))
            try record(delayInFrames: 0)
            accumulator.record(MeasuredTick(FrameTimingSource.Tick(timestamp: 0, delay: 5, frameInterval: frameDuration, previousFrameInterval: frameDuration)))
            endPart()

            XCTAssertEqual(hangCount(of: session), 2)
            // No per-tick cap: the 5s hang counts all 300 frames.
            XCTAssertGreaterThanOrEqual(droppedFrames(of: session) ?? 0, 300)
        }

        // MARK: - Thermal state

        func test_peakThermalState_isStateAtOpenWhenUnchanged() {
            thermalState = .fair
            startService()
            let session = startPart(.foreground)

            // Drops without a notification, so `fair` can only come from the seed at open.
            thermalState = .nominal
            endPart()

            XCTAssertEqual(peakThermalState(of: session), SpanSemantics.Smoothness.ThermalState.fair)
        }

        func test_peakThermalState_keepsMostSevereStateSeen() {
            startService()
            let session = startPart(.foreground)

            changeThermalState(to: .critical)
            changeThermalState(to: .fair)
            changeThermalState(to: .nominal)
            endPart()

            XCTAssertEqual(peakThermalState(of: session), SpanSemantics.Smoothness.ThermalState.critical)
        }

        func test_peakThermalState_includesStateAtCloseWithoutNotification() {
            startService()
            let session = startPart(.foreground)

            thermalState = .serious
            endPart()

            XCTAssertEqual(peakThermalState(of: session), SpanSemantics.Smoothness.ThermalState.serious)
        }

        func test_peakThermalState_offMainNotification_isApplied() {
            startService()
            let session = startPart(.foreground)

            let posted = expectation(description: "posted off main")
            DispatchQueue.global().async {
                self.changeThermalState(to: .serious)
                self.thermalState = .nominal
                posted.fulfill()
            }
            wait(for: [posted], timeout: 5)
            endPart()

            XCTAssertEqual(peakThermalState(of: session), SpanSemantics.Smoothness.ThermalState.serious)
        }

        func test_peakThermalState_doesNotCarryIntoNextPart() {
            startService()
            startPart(.foreground)
            changeThermalState(to: .critical)
            endPart()

            thermalState = .nominal
            let next = startPart(.foreground)
            endPart()

            XCTAssertEqual(peakThermalState(of: next), SpanSemantics.Smoothness.ThermalState.nominal)
        }

        func test_stop_writesFramesCountedSoFar() throws {
            startService()
            let session = startPart(.foreground)
            try record(delayInFrames: 1)
            changeThermalState(to: .serious)

            service.stop()

            XCTAssertEqual(droppedFrames(of: session), 1)
            XCTAssertEqual(peakThermalState(of: session), SpanSemantics.Smoothness.ThermalState.serious)
        }

        // MARK: - Termination

        func test_willTerminate_writesNothing() throws {
            startService()
            let session = startPart(.foreground)
            try record(delayInFrames: 1)

            notificationCenter.post(name: Notification.Name("UIApplicationWillTerminateNotification"), object: nil)

            XCTAssertFalse(hasSmoothnessAttributes(session))
            XCTAssertNotNil(service.tracker?.openPartCounts)
        }

        // MARK: - Config

        func test_onConfigUpdated_appliesHangThreshold() throws {
            startService()

            service.onConfigUpdated(MockEmbraceConfigurable(hangLimits: HangLimits(hangThreshold: 0.5)))

            try assertHangThreshold(0.5)
        }

        func test_onConfigUpdated_beforeStart_isAppliedOnStart() throws {
            service.onConfigUpdated(MockEmbraceConfigurable(hangLimits: HangLimits(hangThreshold: 0.5)))

            startService()

            try assertHangThreshold(0.5)
        }

        func test_onConfigUpdated_beforeStart_appliesSmoothnessLimitsOnStart() throws {
            service.onConfigUpdated(MockEmbraceConfigurable(smoothnessLimits: SmoothnessLimits(idleThreshold: 0.2, heldIdleThreshold: 0.8)))

            startService()

            let tracker = try XCTUnwrap(service.focalMomentTracker)
            XCTAssertEqual(tracker.idleThreshold, 0.2)
            XCTAssertEqual(tracker.heldIdleThreshold, 0.8)
        }

        func test_onConfigUpdated_beforeStart_appliesSpanLimitOnStart() throws {
            service.onConfigUpdated(MockEmbraceConfigurable(smoothnessLimits: SmoothnessLimits(spanLimit: 0)))
            startPart(.foreground)
            startService()
            try recordTouchDown()

            endPart()

            XCTAssertTrue(focalMomentSpans.isEmpty)
        }

        /// Records one tick just under and one just over `threshold` in a new part and checks only the
        /// second counts as a hang.
        private func assertHangThreshold(_ threshold: TimeInterval, file: StaticString = #filePath, line: UInt = #line) throws {
            let session = startPart(.foreground)
            let accumulator = try XCTUnwrap(service.accumulator, file: file, line: line)
            accumulator.record(MeasuredTick(FrameTimingSource.Tick(timestamp: 0, delay: threshold - 0.01, frameInterval: frameDuration, previousFrameInterval: frameDuration)))
            accumulator.record(MeasuredTick(FrameTimingSource.Tick(timestamp: 0, delay: threshold + 0.01, frameInterval: frameDuration, previousFrameInterval: frameDuration)))
            endPart()

            XCTAssertEqual(hangCount(of: session), 1, file: file, line: line)
        }

        // MARK: - Remote config

        private func makeRemoteGatedService(debuggerAttached: @escaping () -> Bool = { false }) {
            service = makeService(debuggerAttached: debuggerAttached, ignoresRemoteConfig: false)
        }

        private func setRemotelyEnabled(_ enabled: Bool) {
            service.onConfigUpdated(MockEmbraceConfigurable(isSmoothnessEnabled: enabled))
        }

        /// Runs `block` on a background queue and waits for it without running main, so anything it
        /// hops to main is still queued when this returns.
        private func runOffMain(_ block: @escaping () -> Void) {
            let done = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                block()
                done.signal()
            }
            done.wait()
        }

        func test_remote_offByDefault_staysDormant() {
            makeRemoteGatedService()
            makeCurrentPart(.foreground)

            startService()
            let session = startPart(.foreground)
            endPart()

            XCTAssertNil(service.tracker)
            XCTAssertNil(service.frameTimingSource)
            XCTAssertFalse(hasSmoothnessAttributes(session))

            // The same service counts once the gate is on.
            // Enabling opens the still-current part; once it ends, the next one is counted too.
            setRemotelyEnabled(true)
            endPart()
            XCTAssertEqual(expectedFrames(of: session), 0)
            let next = startPart(.foreground)
            endPart()

            XCTAssertEqual(expectedFrames(of: next), 0)
        }

        func test_remote_enabledBeforeStart_opensCurrentPart() {
            makeRemoteGatedService()
            makeCurrentPart(.foreground)
            setRemotelyEnabled(true)

            startService()

            XCTAssertNotNil(service.tracker?.openPartCounts)
        }

        func test_remote_enabledWhileRunning_opensCurrentPart() throws {
            makeRemoteGatedService()
            startService()
            let session = startPart(.foreground)

            setRemotelyEnabled(true)

            XCTAssertNotNil(service.tracker?.openPartCounts)
            endPart()
            XCTAssertEqual(expectedFrames(of: session), 0)
        }

        func test_remote_enabledWhileDebuggerAttached_staysDormant() {
            makeRemoteGatedService(debuggerAttached: { true })
            startService()

            setRemotelyEnabled(true)
            drainMain()

            XCTAssertNil(service.tracker)
        }

        func test_remote_disabledWhileRunning_writesFramesSoFarAndReleasesCapture() throws {
            makeRemoteGatedService()
            setRemotelyEnabled(true)
            startService()
            let session = startPart(.foreground)
            try record(delayInFrames: 0)
            weak var source = service.frameTimingSource
            XCTAssertNotNil(source)

            setRemotelyEnabled(false)

            XCTAssertNil(service.tracker)
            XCTAssertNil(service.frameCountTotals)
            XCTAssertNil(source)
            XCTAssertEqual(expectedFrames(of: session), 1)
        }

        func test_remote_disabledOffMain_releasesCaptureOnMain() throws {
            makeRemoteGatedService()
            setRemotelyEnabled(true)
            startService()
            let session = startPart(.foreground)
            weak var source = service.frameTimingSource

            runOffMain { self.setRemotelyEnabled(false) }

            // The part has been written and the service has let go, but the display link's owner is
            // only released once main runs.
            XCTAssertNil(service.tracker)
            XCTAssertEqual(expectedFrames(of: session), 0)
            XCTAssertNotNil(source)

            drainMain()

            XCTAssertNil(source)
        }

        func test_remote_disabledOffMain_partStartBeforeRelease_opensNoPart() {
            makeRemoteGatedService()
            setRemotelyEnabled(true)
            startService()
            startPart(.foreground)

            runOffMain { self.setRemotelyEnabled(false) }
            // The retired tracker is still registered for part starts until main releases it.
            let next = startPart(.foreground)
            drainMain()
            endPart()

            XCTAssertFalse(hasSmoothnessAttributes(next))
        }

        func test_remote_reenabled_opensCurrentPart() {
            makeRemoteGatedService()
            setRemotelyEnabled(true)
            startService()
            startPart(.foreground)

            setRemotelyEnabled(false)
            setRemotelyEnabled(true)

            XCTAssertNotNil(service.tracker?.openPartCounts)
        }

        func test_remote_unchangedConfig_keepsCapture() {
            makeRemoteGatedService()
            setRemotelyEnabled(true)
            startService()
            let tracker = service.tracker

            setRemotelyEnabled(true)
            drainMain()

            XCTAssertTrue(service.tracker === tracker)
        }

        func test_remote_ignored_keepsRunningWhenDisabled() {
            startService()
            let session = startPart(.foreground)

            setRemotelyEnabled(false)

            XCTAssertNotNil(service.tracker)
            XCTAssertFalse(hasSmoothnessAttributes(session))
        }

        // MARK: - Activation races

        func test_restartWhileActivateQueued_buildsOneCapture() throws {
            service.install(otel: otel)
            let session = makeCurrentPart(.foreground)

            // Two activations queued on main: start, stop, start.
            runOffMain {
                self.service.start()
                self.service.stop()
                self.service.start()
            }
            drainMain()

            // The second finds the first's capture and no-ops.
            let tracker = try XCTUnwrap(service.tracker)
            XCTAssertNotNil(tracker.openPartCounts)
            XCTAssertFalse(hasSmoothnessAttributes(session))

            endPart()
            XCTAssertEqual(expectedFrames(of: session), 0)
        }

        // MARK: - Focal moment interrupts

        /// Opens a focal moment that saw main-thread work, and collects what the tracker reports.
        private func openFocalMoment() throws -> () -> [FocalMoment] {
            let tracker = try XCTUnwrap(service.focalMomentTracker)
            var moments: [FocalMoment] = []
            tracker.onMoment = { moments.append($0) }
            tracker.record(
                MeasuredTick(FrameTimingSource.Tick(timestamp: 1, delay: 0, frameInterval: frameDuration, previousFrameInterval: frameDuration)),
                activity: ActivityMonitor.Snapshot(touchBegan: true, touchChanged: true, activeTouchCount: 1, didWork: true)
            )
            return { moments }
        }

        func test_resignActive_interruptsOpenFocalMoment() throws {
            startService()
            let moments = try openFocalMoment()

            notificationCenter.post(name: willResignActiveNotification, object: nil)

            XCTAssertEqual(moments().map(\.outcome), [.interrupted])
        }

        func test_screenDidNavigate_interruptsOpenFocalMoment() throws {
            startService()
            let moments = try openFocalMoment()

            service.screenDidNavigate()

            XCTAssertEqual(moments().map(\.outcome), [.interrupted])
        }

        func test_stop_releasesFocalMomentTracker() throws {
            startService()
            weak var tracker = try XCTUnwrap(service.focalMomentTracker)

            service.stop()

            XCTAssertNil(service.focalMomentTracker)
            XCTAssertNil(tracker)
        }

        // MARK: - Focal moment spans

        private func recordTouchDown() throws {
            try XCTUnwrap(service.focalMomentTracker).record(
                MeasuredTick(FrameTimingSource.Tick(timestamp: 1, delay: 0, frameInterval: frameDuration, previousFrameInterval: frameDuration)),
                activity: ActivityMonitor.Snapshot(touchBegan: true, touchChanged: true, activeTouchCount: 1, didWork: true)
            )
        }

        private var focalMomentSpans: [EmbraceSpan] {
            otel.startedSpans.filter { $0.name == SpanSemantics.Smoothness.focalMomentName }
        }

        func test_partEnd_emitsOpenFocalMomentAsInterruptedSpan() throws {
            startPart(.foreground)
            startService()
            try recordTouchDown()

            endPart()

            let span = try XCTUnwrap(focalMomentSpans.first)
            XCTAssertEqual(focalMomentSpans.count, 1)
            XCTAssertEqual(span.type, .smoothness)
            XCTAssertEqual(span.attributes[SpanSemantics.Smoothness.keyOutcome] as? String, SpanSemantics.Smoothness.Outcome.interrupted)
        }

        // MARK: - Tick fan-out

        func test_tickHandler_feedsFocalMomentTracker() {
            let tracker = RecordingFocalMomentTracker()
            let monitor = ActivityMonitor(windowEventObserver: WindowEventObserver(), runLoop: nil, currentMode: { .tracking })
            let handler = SmoothnessCaptureService.makeTickHandler(
                accumulator: FrameAccumulator(hangThreshold: 0.249),
                focalMoments: (tracker, monitor),
                environment: [:]
            )

            handler(FrameTimingSource.Tick(timestamp: 0, delay: 0, frameInterval: frameDuration, previousFrameInterval: frameDuration))
            handler(FrameTimingSource.Tick(timestamp: 0, delay: 0, frameInterval: frameDuration, previousFrameInterval: frameDuration))

            XCTAssertEqual(tracker.activities.count, 2)
            XCTAssertTrue(tracker.activities.allSatisfy(\.isTracking))
            withExtendedLifetime(monitor) {}
        }
    }

    private final class RecordingFocalMomentTracker: FocalMomentTracker {

        private(set) var activities: [ActivityMonitor.Snapshot] = []

        override func record(_ tick: MeasuredTick, activity: ActivityMonitor.Snapshot) {
            activities.append(activity)
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
                sessionSpan: { [unowned self] partId in
                    self.controller.currentSession?.id == partId ? self.controller.currentSessionSpan : nil
                },
                notificationCenter: .default,
                embraceNotificationCenter: Embrace.notificationCenter,
                debuggerAttached: { false },
                ignoresRemoteConfig: true,
                attachesDisplayLink: false
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

        private var sessionSpans: [EmbraceSpan] {
            otel.startedSpans.filter { $0.name == SpanSemantics.Session.name }
        }

        private func expectedFrames(of span: EmbraceSpan?) -> Int? {
            span?.attributes[SpanSemantics.Smoothness.keyExpectedFrames] as? Int
        }

        func test_foregroundPart_attributesAreWrittenBeforeSessionSpanEnds() throws {
            controller.startSession(state: .foreground)
            drainMain()
            let span = try XCTUnwrap(sessionSpans.first)
            var expectedFramesAtEnd: Int?
            otel.onSpanEndedCallback = { [unowned self] ended in
                if ended.context.spanId == span.context.spanId { expectedFramesAtEnd = self.expectedFrames(of: ended) }
            }

            controller.endSession()

            // No waiting: the attributes must be written by the synchronous will-end hook.
            XCTAssertEqual(expectedFramesAtEnd, 0)
            XCTAssertNotNil(span.attributes[SpanSemantics.Smoothness.keyDroppedFrames])
            XCTAssertNotNil(span.attributes[SpanSemantics.Smoothness.keyPeakThermalState])
            XCTAssertNotNil(span.attributes[SpanSemantics.Smoothness.keyHangCount])
        }

        func test_foregroundPartEndedOffMain_attributesAreWrittenBeforeEndSessionReturns() throws {
            controller.startSession(state: .foreground)
            drainMain()
            let span = try XCTUnwrap(sessionSpans.first)

            // `async`, not `sync`: a `sync` from main runs the block on main.
            let ended = expectation(description: "ended off main")
            var writtenBeforeEndSessionReturned = false
            controller.queue.async {
                _ = self.controller.endSession()
                writtenBeforeEndSessionReturned = self.expectedFrames(of: span) != nil
                ended.fulfill()
            }
            wait(for: [ended], timeout: 5)

            XCTAssertTrue(writtenBeforeEndSessionReturned)
        }

        func test_backgroundPart_getsNoAttributes() throws {
            controller.startSession(state: .background)
            drainMain()
            let span = try XCTUnwrap(sessionSpans.first)

            controller.endSession()

            XCTAssertNil(expectedFrames(of: span))
        }

        /// The tracker observes did-become-active before `iOSSessionLifecycle` swaps the part to
        /// foreground. Its hop to the next main turn is what still catches the swap.
        func test_coldStartSwapToForeground_trackerObservesFirst_opensPart() throws {
            let session = try XCTUnwrap(controller.startSession(state: .background))
            XCTAssertTrue(session.coldStart)
            drainMain()

            NotificationCenter.default.post(name: Notification.Name("UIApplicationDidBecomeActiveNotification"), object: nil)
            controller.update(state: .foreground)
            drainMain()

            let span = try XCTUnwrap(sessionSpans.first)
            controller.endSession()

            XCTAssertEqual(expectedFrames(of: span), 0)
        }

        /// Max-duration expiry rolls the part on the controller's queue, so the service writes the
        /// ending part off main and opens the next one.
        func test_rollPartForUserSessionExpiryOffMain_writesEndingPartAndOpensNext() throws {
            controller.startSession(state: .foreground)
            drainMain()
            let span = try XCTUnwrap(sessionSpans.first)

            let rolled = expectation(description: "rolled off main")
            var writtenBeforeRollReturned = false
            controller.queue.async {
                self.controller.rollPartForUserSessionExpiry(reason: .maxDurationReached, at: Date())
                writtenBeforeRollReturned = self.expectedFrames(of: span) != nil
                rolled.fulfill()
            }
            wait(for: [rolled], timeout: 5)
            // The next part's start is delivered async on main.
            drainMain()

            XCTAssertTrue(writtenBeforeRollReturned)
            XCTAssertNotNil(service.tracker?.openPartCounts)
        }
    }

    // MARK: - End to end

    /// The real `SessionController`, `DefaultOTelSignalsHandler`, storage and upload, with only the
    /// network mocked. Each part's payload is decoded from the request that was sent.
    final class SmoothnessCaptureServiceEndToEndTests: XCTestCase {

        private let sessionsUrl = URL(string: "https://embrace.smoothness-end-to-end.test/sessions")!

        private var storage: EmbraceStorage!
        private var upload: EmbraceUpload!
        private var controller: SessionController!
        private var userSessionController: UserSessionController!
        private var logController: LogController!
        private var handler: DefaultOTelSignalsHandler!
        private var service: SmoothnessCaptureService!
        private let sdkStateProvider = MockEmbraceSDKStateProvider()

        override func setUpWithError() throws {
            try super.setUpWithError()
            EmbraceHTTPMock.clearRequests()
            EmbraceHTTPMock.mock(url: sessionsUrl)

            let urlSessionConfiguration = URLSessionConfiguration.ephemeral
            urlSessionConfiguration.protocolClasses = [EmbraceHTTPMock.self]
            upload = try EmbraceUpload(
                options: EmbraceUpload.Options(
                    endpoints: EmbraceUpload.EndpointOptions(
                        spansURL: sessionsUrl,
                        logsURL: URL(string: "https://embrace.smoothness-end-to-end.test/logs")!,
                        attachmentsURL: URL(string: "https://embrace.smoothness-end-to-end.test/attachments")!
                    ),
                    cache: EmbraceUpload.CacheOptions(storageMechanism: .inMemory(name: name), enableBackgroundTasks: false),
                    metadata: EmbraceUpload.MetadataOptions(apiKey: "apiKey", userAgent: "userAgent", deviceId: "12345678"),
                    redundancy: EmbraceUpload.RedundancyOptions(automaticRetryCount: -1),
                    urlSessionConfiguration: urlSessionConfiguration
                ),
                logger: MockLogger(),
                queue: DispatchQueue(label: "io.embrace.tests.smoothnessEndToEnd.upload")
            )
            storage = try EmbraceStorage.createInMemoryDb()
            sdkStateProvider.isEnabled = true

            // A synchronous controller queue builds each part's payload inside the part's end, right
            // after the hook: the least time for the attribute writes to land before the payload fetch.
            controller = SessionController(storage: storage, upload: upload, config: nil, queue: MockQueue())
            controller.sdkStateProvider = sdkStateProvider
            userSessionController = UserSessionController(storage: storage, config: MockEmbraceConfigurable())
            userSessionController.sessionController = controller
            controller.userSessionController = userSessionController

            logController = LogController(
                storage: storage,
                upload: SpyEmbraceLogUploader(),
                sessionController: controller,
                queue: DispatchQueue(label: "io.embrace.tests.smoothnessEndToEnd.logs")
            )
            handler = DefaultOTelSignalsHandler(
                storage: storage,
                sessionController: controller,
                logController: logController,
                limiter: MockOTelSignalsLimiter(),
                sanitizer: MockOTelSignalsSanitizer(),
                bridge: MockOTelSignalBridge()
            )
            controller.otel = handler

            service = SmoothnessCaptureService(
                currentSession: { [unowned self] in self.controller.currentSession },
                sessionSpan: { [unowned self] partId in
                    self.controller.currentSession?.id == partId ? self.controller.currentSessionSpan : nil
                },
                notificationCenter: .default,
                embraceNotificationCenter: Embrace.notificationCenter,
                thermalState: { .nominal },
                debuggerAttached: { false },
                ignoresRemoteConfig: true,
                attachesDisplayLink: false
            )
            service.install(otel: handler)
            service.start()
        }

        override func tearDownWithError() throws {
            service?.stop()
            service = nil
            // Stop in-flight uploads so they don't outlive the test. `upload` is released first, as in
            // `SessionControllerTests`, so a cancelled operation doesn't refill the queue.
            let uploadQueues = [upload?.spansQueue, upload?.logsQueue, upload?.attachmentsQueue].compactMap { $0 }
            let uploadCache = upload?.cache
            upload = nil
            uploadQueues.forEach { $0.cancelAllOperations() }
            uploadCache?.coreData.destroy()
            controller = nil
            userSessionController = nil
            handler = nil
            logController = nil
            storage?.coreData.destroy()
            storage = nil
            EmbraceHTTPMock.clearRequests()
            try super.tearDownWithError()
        }

        /// The uploaded `emb-session` span of each part, keyed by part id. (`session.id` is the user
        /// session's id, shared by its parts.)
        private func uploadedSessionSpans() throws -> [String: [String: Any]] {
            try EmbraceHTTPMock.requestBodiesForUrl(sessionsUrl).reduce(into: [:]) { result, body in
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try body.gunzipped()) as? [String: Any])
                let data = try XCTUnwrap(json["data"] as? [String: Any])
                let spans = data["spans"] as? [[String: Any]] ?? []
                let sessionSpan = try XCTUnwrap(spans.first { $0["name"] as? String == SpanSemantics.Session.name })
                let partId = try XCTUnwrap(attribute(CommonSemantics.keyPartId, of: sessionSpan))
                result[partId] = sessionSpan
            }
        }

        private func attribute(_ key: String, of span: [String: Any]) -> String? {
            let attributes = span["attributes"] as? [[String: Any]] ?? []
            return attributes.first { $0["key"] as? String == key }?["value"] as? String
        }

        /// The counts are written by the sync hook before the ending part's payload is built, so each
        /// part is sent with its own counts.
        func test_foregroundToForeground_eachPartIsSentWithItsOwnCounts() throws {
            let part = try XCTUnwrap(controller.startSession(state: .foreground))
            drainMain()
            let accumulator = try XCTUnwrap(service.accumulator)
            let frame = 1.0 / 60.0
            accumulator.record(MeasuredTick(FrameTimingSource.Tick(timestamp: 0, delay: 0, frameInterval: frame, previousFrameInterval: frame)))
            accumulator.record(MeasuredTick(FrameTimingSource.Tick(timestamp: 0, delay: 0, frameInterval: frame, previousFrameInterval: frame)))
            accumulator.record(MeasuredTick(FrameTimingSource.Tick(timestamp: 0, delay: frame, frameInterval: frame, previousFrameInterval: frame)))

            let next = try XCTUnwrap(controller.startSession(state: .foreground))
            drainMain()
            controller.endSession()
            upload.waitForAllWork()

            let sessionSpans = try uploadedSessionSpans()
            XCTAssertEqual(sessionSpans.count, 2)

            let partSpan = try XCTUnwrap(sessionSpans[part.id.stringValue])
            XCTAssertEqual(attribute(SpanSemantics.Smoothness.keyDroppedFrames, of: partSpan), "1")
            XCTAssertEqual(attribute(SpanSemantics.Smoothness.keyExpectedFrames, of: partSpan), "4")
            XCTAssertEqual(attribute(SpanSemantics.Smoothness.keyHangCount, of: partSpan), "0")
            XCTAssertEqual(attribute(SpanSemantics.Smoothness.keyPeakThermalState, of: partSpan), SpanSemantics.Smoothness.ThermalState.nominal)

            let nextSpan = try XCTUnwrap(sessionSpans[next.id.stringValue])
            XCTAssertEqual(attribute(SpanSemantics.Smoothness.keyDroppedFrames, of: nextSpan), "0")
            XCTAssertEqual(attribute(SpanSemantics.Smoothness.keyExpectedFrames, of: nextSpan), "0")
        }
    }

    extension XCTestCase {
        /// Runs the main queue past anything already enqueued on it, such as the async
        /// `.embraceSessionPartDidStart` post.
        fileprivate func drainMain() {
            let drained = expectation(description: "main drained")
            DispatchQueue.main.async { drained.fulfill() }
            wait(for: [drained], timeout: 5)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
