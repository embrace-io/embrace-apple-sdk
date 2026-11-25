//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import EmbraceSemantics
    import TestSupport
    import UIKit
    import XCTest

    @testable import EmbraceCore

    /// Drives the screen-load vital through `UIViewControllerHandler`'s lifecycle entry points, with a fake
    /// tap source, a fake frame source and explicit timestamps, and asserts only the `screen-load` spans
    /// recorded by the OTel test double.
    final class UIViewControllerHandlerScreenLoadTests: XCTestCase {

        /// Uptime the tests' timestamps are relative to, like a real `systemUptime`.
        private static let origin: TimeInterval = 1_000

        /// Wall-clock time at ``origin``.
        private static let originDate = Date(timeIntervalSince1970: 1_700_000_000)

        private var dataSource: MockUIViewControllerHandlerDataSource!
        private var otel: MockOTelSignalsHandler {
            dataSource.otel as! MockOTelSignalsHandler
        }
        private var tapSource: FakeTapSource!
        private var frameSource: FakeFrameSource!
        private var notificationCenter: NotificationCenter!
        private var applicationState: UIApplication.State = .active
        private var uptime: TimeInterval = origin
        private var handler: UIViewControllerHandler!

        override func setUp() {
            super.setUp()

            dataSource = MockUIViewControllerHandlerDataSource()
            dataSource.instrumentScreenLoad = true
            tapSource = FakeTapSource()
            frameSource = FakeFrameSource()
            notificationCenter = NotificationCenter()
            applicationState = .active
            uptime = Self.origin
        }

        override func tearDown() {
            handler = nil
            dataSource = nil
            super.tearDown()
        }

        /// Builds and starts the handler. Called by each test once the app state is set.
        private func startHandler(usesViewIsAppearing: Bool = true) {
            let screenLoad = ViewControllerScreenLoadHandler(
                frameSource: frameSource,
                usesViewIsAppearing: usesViewIsAppearing,
                applicationState: { [unowned self] in self.applicationState },
                uptimeProvider: { [unowned self] in self.uptime },
                notificationCenter: notificationCenter,
                makeTracker: { [unowned self] emit in
                    ScreenLoadTracker(
                        queue: .main,
                        uptimeProvider: { self.uptime },
                        dateProvider: { Self.originDate.addingTimeInterval(self.uptime - Self.origin) },
                        // the tests never reach the timeout
                        scheduleTimeout: { _, _ in },
                        emit: emit
                    )
                }
            )

            // runs the handler's work inline so every call has finished by the time it returns
            handler = UIViewControllerHandler(queue: MockQueue(), screenLoadHandler: screenLoad)
            handler.dataSource = dataSource
            handler.screenLoadHandler.start(tapSource: tapSource)
        }

        // MARK: - Inputs (times in milliseconds after `origin`)

        private func tap(_ ms: Int) {
            advance(to: ms)
            tapSource.tap(at: time(ms))
        }

        private func navigationStart(_ vc: UIViewController, _ ms: Int) {
            advance(to: ms)
            handler.onViewDidLoadStart(vc)
        }

        /// A whole `viewIsAppearing` callback ending at `ms`, which is navigation end on iOS 17+.
        private func viewIsAppearingEnd(_ vc: UIViewController, _ ms: Int) {
            handler.onViewIsAppearingCallbackStart(vc)
            advance(to: ms)
            handler.onViewIsAppearingCallbackEnd(vc)
        }

        /// The end of `viewWillAppear`, which is navigation end before iOS 17.
        private func viewWillAppearEnd(_ vc: UIViewController, _ ms: Int) {
            advance(to: ms)
            handler.onViewWillAppearEnd(vc)
        }

        private func frame(_ ms: Int) {
            advance(to: ms)
            frameSource.display(at: time(ms))
        }

        private func advance(to ms: Int) {
            uptime = max(uptime, time(ms))
        }

        private func time(_ ms: Int) -> TimeInterval {
            Self.origin + TimeInterval(ms) / 1000
        }

        private func date(_ ms: Int) -> Date {
            Self.originDate.addingTimeInterval(TimeInterval(ms) / 1000)
        }

        private var screenLoadSpans: [EmbraceSpan] {
            otel.startedSpans.filter { $0.name == SpanSemantics.ScreenLoad.name }
        }

        private func attribute(_ key: String, of span: EmbraceSpan) -> String? {
            span.attributes[key] as? String
        }

        // MARK: - Tests

        func test_tapThenPushThenFrame_recordsCompletedSpanFromTap() throws {
            startHandler()
            let vc = ScreenA()

            tap(0)
            navigationStart(vc, 100)
            viewIsAppearingEnd(vc, 300)
            frame(350)

            let span = try XCTUnwrap(screenLoadSpans.first)
            XCTAssertEqual(screenLoadSpans.count, 1)
            XCTAssertEqual(span.type, .screenLoad)
            XCTAssertEqual(span.startTime, date(0))
            XCTAssertEqual(span.endTime, date(350))
            XCTAssertEqual(attribute(SpanSemantics.keyPrivate, of: span), "true")
            XCTAssertEqual(attribute(SpanSemantics.View.keyViewName, of: span), "ScreenA")
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyOutcome, of: span), "timed_out")
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyNavStartDelayMs, of: span), "100")
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyNavDurationMs, of: span), "200")
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyFirstFrameDurationMs, of: span), "50")
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyIdleThresholdMs, of: span), "0")
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyTimeoutMs, of: span), "30000")
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyNavTimeoutMs, of: span), "500")
        }

        func test_viewName_usesCustomizedName() throws {
            startHandler()
            let vc = CustomizedScreen()

            navigationStart(vc, 0)
            viewIsAppearingEnd(vc, 100)
            frame(150)

            let span = try XCTUnwrap(screenLoadSpans.first)
            XCTAssertEqual(attribute(SpanSemantics.View.keyViewName, of: span), "Checkout")
        }

        func test_noTap_startsAtNavigationStart() throws {
            startHandler()
            let vc = ScreenA()

            navigationStart(vc, 100)
            viewIsAppearingEnd(vc, 300)
            frame(350)

            let span = try XCTUnwrap(screenLoadSpans.first)
            XCTAssertEqual(span.startTime, date(100))
            XCTAssertEqual(span.endTime, date(350))
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyNavStartDelayMs, of: span), "0")
        }

        func test_tapOutsideNavigationWindow_startsAtNavigationStart() throws {
            startHandler()
            let vc = ScreenA()

            tap(0)
            navigationStart(vc, 600)
            viewIsAppearingEnd(vc, 700)
            frame(750)

            let span = try XCTUnwrap(screenLoadSpans.first)
            XCTAssertEqual(span.startTime, date(600))
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyNavStartDelayMs, of: span), "0")
        }

        func test_tapAfterNavigationEnd_recordsUserInterrupted() throws {
            startHandler()
            let vc = ScreenA()

            tap(0)
            navigationStart(vc, 100)
            viewIsAppearingEnd(vc, 300)
            tap(320)
            frame(350)

            let span = try XCTUnwrap(screenLoadSpans.first)
            XCTAssertEqual(screenLoadSpans.count, 1)
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyOutcome, of: span), "user_interrupted")
            XCTAssertEqual(span.startTime, date(0))
            XCTAssertEqual(span.endTime, date(300))
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyFirstFrameDurationMs, of: span), "0")
        }

        func test_navigationAfterNavigationEnd_recordsNavigationInterrupted() throws {
            startHandler()
            let first = ScreenA()
            let second = ScreenB()

            tap(0)
            navigationStart(first, 100)
            viewIsAppearingEnd(first, 300)
            navigationStart(second, 320)
            viewIsAppearingEnd(second, 400)
            // answers both frame requests; only the latest one may complete the second load
            frame(450)

            XCTAssertEqual(screenLoadSpans.count, 2)

            let interrupted = screenLoadSpans[0]
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyOutcome, of: interrupted), "navigation_interrupted")
            XCTAssertEqual(attribute(SpanSemantics.View.keyViewName, of: interrupted), "ScreenA")
            XCTAssertEqual(interrupted.startTime, date(0))
            XCTAssertEqual(interrupted.endTime, date(300))

            let completed = screenLoadSpans[1]
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyOutcome, of: completed), "timed_out")
            XCTAssertEqual(attribute(SpanSemantics.View.keyViewName, of: completed), "ScreenB")
            XCTAssertEqual(completed.startTime, date(320))
            XCTAssertEqual(completed.endTime, date(450))
        }

        func test_staleFrameRequest_doesNotCompleteLaterLoad() throws {
            startHandler()
            let first = ScreenA()
            let second = ScreenB()

            navigationStart(first, 0)
            viewIsAppearingEnd(first, 100)
            navigationStart(second, 120)
            viewIsAppearingEnd(second, 200)

            // only the first load's request is answered, as when the second load's request waits for a
            // later commit
            frameSource.displayOldest(at: time(210))
            XCTAssertEqual(screenLoadSpans.count, 1)

            frame(260)
            let completed = try XCTUnwrap(screenLoadSpans.last)
            XCTAssertEqual(screenLoadSpans.count, 2)
            XCTAssertEqual(completed.endTime, date(260))
        }

        func test_background_dropsPendingLoad() {
            startHandler()
            let vc = ScreenA()

            tap(0)
            navigationStart(vc, 100)
            viewIsAppearingEnd(vc, 300)
            notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            frame(350)

            XCTAssertTrue(screenLoadSpans.isEmpty)
        }

        func test_navigationWhileBackgrounded_isSkipped() {
            startHandler()
            let vc = ScreenA()

            applicationState = .background
            navigationStart(vc, 100)
            applicationState = .active
            viewIsAppearingEnd(vc, 300)
            frame(350)

            XCTAssertTrue(screenLoadSpans.isEmpty)
        }

        func test_launch_skipsNavigationsUntilAppBecomesActive() throws {
            applicationState = .inactive
            startHandler()
            let container = ScreenA()
            let root = ScreenB()

            // the launch screen, and everything else loaded during launch, belongs to startup
            navigationStart(container, 0)
            navigationStart(root, 50)
            viewIsAppearingEnd(container, 100)
            viewIsAppearingEnd(root, 120)
            frame(150)
            XCTAssertTrue(screenLoadSpans.isEmpty)

            applicationState = .active
            notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)

            let next = ScreenC()
            tap(1000)
            navigationStart(next, 1100)
            viewIsAppearingEnd(next, 1300)
            frame(1350)

            let span = try XCTUnwrap(screenLoadSpans.first)
            XCTAssertEqual(screenLoadSpans.count, 1)
            XCTAssertEqual(attribute(SpanSemantics.View.keyViewName, of: span), "ScreenC")
        }

        func test_reappearance_isSkipped() {
            startHandler()
            let vc = ScreenA()

            navigationStart(vc, 0)
            viewIsAppearingEnd(vc, 100)
            frame(150)
            XCTAssertEqual(screenLoadSpans.count, 1)

            // back navigation to an existing controller has no navigation start
            viewIsAppearingEnd(vc, 1000)
            frame(1050)

            XCTAssertEqual(screenLoadSpans.count, 1)
        }

        func test_appearanceOfControllerWithoutNavigationStart_isNotNavigationEnd() throws {
            startHandler()
            let presenting = ScreenA()
            let destination = ScreenB()

            navigationStart(destination, 0)
            // e.g. the presenting controller reappearing while the destination is still loading
            viewIsAppearingEnd(presenting, 50)
            frame(60)
            XCTAssertTrue(screenLoadSpans.isEmpty)

            viewIsAppearingEnd(destination, 100)
            frame(150)

            let span = try XCTUnwrap(screenLoadSpans.first)
            XCTAssertEqual(attribute(SpanSemantics.View.keyViewName, of: span), "ScreenB")
            XCTAssertEqual(span.endTime, date(150))
        }

        func test_blocklistedViewController_isSkipped() {
            dataSource.blockList = ViewControllerBlockList(types: [ScreenA.self])
            startHandler()
            let vc = ScreenA()

            navigationStart(vc, 0)
            viewIsAppearingEnd(vc, 100)
            frame(150)

            XCTAssertTrue(screenLoadSpans.isEmpty)
        }

        func test_viewControllerOptedOutOfCapture_isSkipped() {
            startHandler()
            let vc = CustomizedScreen()
            vc.shouldCaptureViewInEmbrace = false

            navigationStart(vc, 0)
            viewIsAppearingEnd(vc, 100)
            frame(150)

            XCTAssertTrue(screenLoadSpans.isEmpty)
        }

        func test_containerViewController_isSkipped() {
            startHandler()
            let container = UINavigationController()

            navigationStart(container, 0)
            viewIsAppearingEnd(container, 100)
            frame(150)

            XCTAssertTrue(screenLoadSpans.isEmpty)
        }

        func test_iOS17_overrideCallingSuper_endsAfterOutermostViewIsAppearing() throws {
            startHandler()
            let vc = ScreenA()

            navigationStart(vc, 0)

            // the subclass's swizzle wraps the base class's, which ends when the override's `super` returns
            advance(to: 50)
            handler.onViewIsAppearingCallbackStart(vc)
            handler.onViewIsAppearingCallbackStart(vc)
            advance(to: 100)
            handler.onViewIsAppearingCallbackEnd(vc)
            frame(120)
            XCTAssertTrue(screenLoadSpans.isEmpty)

            // the rest of the override's body runs before the outermost swizzle ends
            advance(to: 300)
            handler.onViewIsAppearingCallbackEnd(vc)
            frame(350)

            let span = try XCTUnwrap(screenLoadSpans.first)
            XCTAssertEqual(screenLoadSpans.count, 1)
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyNavDurationMs, of: span), "300")
            XCTAssertEqual(span.endTime, date(350))
        }

        func test_repeatedViewDidLoadStart_keepsFirstNavigationStart() throws {
            startHandler()
            let vc = ScreenA()

            // an override of `viewDidLoad` calling `super` reaches the handler once per swizzled class
            navigationStart(vc, 0)
            navigationStart(vc, 40)
            viewIsAppearingEnd(vc, 100)
            frame(150)

            let span = try XCTUnwrap(screenLoadSpans.first)
            XCTAssertEqual(screenLoadSpans.count, 1)
            XCTAssertEqual(span.startTime, date(0))
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyNavDurationMs, of: span), "100")
        }

        func test_preiOS17_navigationEndsAtViewWillAppear() throws {
            startHandler(usesViewIsAppearing: false)
            let vc = ScreenA()

            tap(0)
            navigationStart(vc, 100)
            // `viewIsAppearing` isn't navigation end on this path
            viewIsAppearingEnd(vc, 200)
            frame(220)
            XCTAssertTrue(screenLoadSpans.isEmpty)

            viewWillAppearEnd(vc, 250)
            frame(300)

            let span = try XCTUnwrap(screenLoadSpans.first)
            XCTAssertEqual(span.endTime, date(300))
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyNavDurationMs, of: span), "150")
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyFirstFrameDurationMs, of: span), "50")
        }

        func test_iOS17_viewWillAppearIsNotNavigationEnd() throws {
            startHandler()
            let vc = ScreenA()

            navigationStart(vc, 0)
            viewWillAppearEnd(vc, 100)
            frame(120)
            XCTAssertTrue(screenLoadSpans.isEmpty)

            viewIsAppearingEnd(vc, 150)
            frame(200)

            let span = try XCTUnwrap(screenLoadSpans.first)
            XCTAssertEqual(attribute(SpanSemantics.ScreenLoad.keyNavDurationMs, of: span), "150")
        }

        func test_stop_tearsDownSourcesAndPendingLoad() {
            startHandler()
            let vc = ScreenA()

            tap(0)
            navigationStart(vc, 100)
            viewIsAppearingEnd(vc, 300)

            handler.screenLoadHandler.stop()

            XCTAssertEqual(frameSource.stopCount, 1)
            XCTAssertNil(tapSource.onTapUp)
            frame(350)
            XCTAssertTrue(screenLoadSpans.isEmpty)

            // nothing is measured while stopped
            let next = ScreenB()
            navigationStart(next, 1000)
            viewIsAppearingEnd(next, 1100)
            frame(1150)
            XCTAssertTrue(screenLoadSpans.isEmpty)
        }

        func test_restart_measuresAgain() {
            startHandler()
            handler.screenLoadHandler.stop()
            handler.screenLoadHandler.start(tapSource: tapSource)
            let vc = ScreenA()

            tap(0)
            navigationStart(vc, 100)
            viewIsAppearingEnd(vc, 300)
            frame(350)

            XCTAssertEqual(screenLoadSpans.count, 1)
            XCTAssertEqual(screenLoadSpans.first?.startTime, date(0))
        }

        func test_screenLoadDisabled_recordsNothing() {
            dataSource.instrumentScreenLoad = false
            startHandler()
            let vc = ScreenA()

            tap(0)
            navigationStart(vc, 100)
            viewIsAppearingEnd(vc, 300)
            frame(350)

            XCTAssertTrue(screenLoadSpans.isEmpty)
        }

        func test_firstRenderDisabled_recordsNothing() {
            dataSource.instrumentFirstRender = false
            startHandler()
            let vc = ScreenA()

            navigationStart(vc, 100)
            viewIsAppearingEnd(vc, 300)
            frame(350)

            XCTAssertTrue(screenLoadSpans.isEmpty)
        }

        func test_screenLoad_leavesTimeToFirstRenderUnchanged() {
            startHandler()
            let vc = ScreenA()

            navigationStart(vc, 0)

            let timeToFirstRenderName = SpanSemantics.View.timeToFirstRenderName
                .replacingOccurrences(of: "NAME", with: vc.className)
            let timeToFirstRender = otel.startedSpans.filter { $0.name == timeToFirstRenderName }
            XCTAssertEqual(timeToFirstRender.count, 1)
        }
    }

    // MARK: - Fakes

    private final class FakeTapSource: ScreenLoadTapSource {
        var onTapUp: ((TimeInterval) -> Void)?

        func tap(at uptime: TimeInterval) {
            onTapUp?(uptime)
        }
    }

    /// Answers requests only when the test says a frame was displayed.
    private final class FakeFrameSource: FrameDisplayedSource {
        private var handlers: [FrameDisplayedHandler] = []
        private(set) var stopCount = 0

        func requestNextFrame(_ handler: @escaping FrameDisplayedHandler) {
            handlers.append(handler)
        }

        func stop() {
            stopCount += 1
            handlers.removeAll()
        }

        /// Answers every waiting request with a frame at `uptime`.
        func display(at uptime: TimeInterval) {
            let waiting = handlers
            handlers.removeAll()
            waiting.forEach { $0(uptime) }
        }

        /// Answers only the oldest waiting request.
        func displayOldest(at uptime: TimeInterval) {
            guard !handlers.isEmpty else { return }
            handlers.removeFirst()(uptime)
        }
    }

    private final class ScreenA: UIViewController {}
    private final class ScreenB: UIViewController {}
    private final class ScreenC: UIViewController {}

    private final class CustomizedScreen: UIViewController, EmbraceViewControllerCustomization {
        var nameForViewControllerInEmbrace: String? = "Checkout"
        var shouldCaptureViewInEmbrace = true
    }

#endif
