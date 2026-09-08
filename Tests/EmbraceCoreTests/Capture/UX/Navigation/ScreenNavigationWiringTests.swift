//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import EmbraceConfiguration
    import EmbraceSemantics
    import TestSupport
    import UIKit
    import XCTest

    @testable import EmbraceCore

    /// Pins the wiring the timeline depends on but cannot verify itself: that a real swizzled
    /// appearance callback actually reaches the tracker, and that the gates combine correctly.
    ///
    /// These drive `vc.viewWillAppear(_:)` and friends so the **swizzle** runs. Calling the handler
    /// directly would prove nothing — the swizzle is where the decision to record is made, and it
    /// applies gates of its own that the handler never sees.
    final class ScreenNavigationWiringTests: SwizzlerTestCase {

        private final class ScreenA: UIViewController {}

        private var mockOTel: MockOTelSignalsHandler!
        private var service: ViewCaptureService!

        private let origin = Date(timeIntervalSince1970: 1_000)

        override func setUpWithError() throws {
            try super.setUpWithError()

            mockOTel = MockOTelSignalsHandler()
            service = ViewCaptureService(options: ViewCaptureService.Options(), lock: NSLock())
            service.install(otel: mockOTel)
            service.start()

            // The gate needs an SDK instance, so the tracker is injected directly. Everything the
            // tests exercise below — the swizzles, the filter, the broker — is the real thing.
            let sessionSpan = try mockOTel.createInternalSpan(
                name: SpanSemantics.Session.name, type: .session, startTime: origin)
            let reporter = ScreenStateReporter(otel: mockOTel)
            reporter.recorder.onSessionPartStart(sessionSpan: sessionSpan, at: origin)
            reporter.recorder.activate(at: origin)

            service.navigationTracker = ScreenNavigationTracker(reporter: reporter) { [weak service] vc in
                service?.isViewControllerBlocked(vc) ?? true
            }
        }

        override func tearDownWithError() throws {
            restoreSwizzleCacheAdditions()
            mockOTel = nil
            service = nil
            try super.tearDownWithError()
        }

        private var recordedScreens: [String] {
            let span = mockOTel.startedSpans.first { $0.name == "emb-state-screen-automatic" }
            return span?.events.compactMap {
                $0.attributes[SpanSemantics.State.keyNewValue]?.description
            } ?? []
        }

        /// Production always carries an identifier here — assigned in `onViewDidLoadStart` or
        /// `onViewDidAppearEnd`. Without one the handler returns before latching its
        /// `…SpanCreated` flags, which is exactly the gate these tests exist to get past.
        private func appearInstrumented(_ vc: UIViewController) {
            vc.emb_instrumentation_state = .init(identifier: UUID().uuidString)
            vc.viewWillAppear(false)
            vc.viewDidAppear(false)
        }

        // MARK: - The swizzle actually reaches the timeline

        func testAnAppearanceRecordsAScreen() {
            appearInstrumented(ScreenA())

            XCTAssertEqual(recordedScreens, ["ScreenA"])
        }

        func testReturningToTheSameControllerRecordsAgain() {
            let home = ScreenA()
            let detail = UIViewController()

            appearInstrumented(home)
            appearInstrumented(detail)
            home.viewDidDisappear(false)
            detail.viewDidDisappear(false)

            // The second visit to `home` is the case that matters. The span-creation path latches
            // `viewWillAppearSpanCreated` on first appearance and never resets it, so a tap placed
            // inside the handler would go silent here and the timeline would claim the user never
            // left `detail`.
            home.viewWillAppear(false)
            home.viewDidAppear(false)

            XCTAssertEqual(recordedScreens, ["ScreenA", "UIViewController", "ScreenA"])
        }

        func testAppearanceIsRecordedWithoutFirstRenderInstrumentation() {
            // No `emb_instrumentation_state`: the span-creating branch is skipped entirely, which is
            // what happens whenever first-render instrumentation is off. The timeline must not
            // inherit that feature's configuration.
            let vc = ScreenA()
            vc.viewWillAppear(false)
            vc.viewDidAppear(false)

            XCTAssertEqual(recordedScreens, ["ScreenA"])
        }

        func testAStoppedServiceRecordsNothing() {
            service.stop()

            appearInstrumented(ScreenA())

            XCTAssertTrue(recordedScreens.isEmpty)
        }

        // MARK: - The gates

        private func config(state: Bool, screen: Bool) -> EmbraceConfigurable {
            let config = EditableConfig()
            config.isStateCaptureEnabled = state
            config.isScreenTrackingEnabled = screen
            return config
        }

        func testBothGatesOnAndVisibilityOnEnablesTracking() {
            XCTAssertTrue(
                ViewCaptureService.shouldTrackScreenNavigation(
                    instrumentVisibility: true, config: config(state: true, screen: true)))
        }

        func testEitherGateOffDisablesTracking() {
            XCTAssertFalse(
                ViewCaptureService.shouldTrackScreenNavigation(
                    instrumentVisibility: true, config: config(state: false, screen: true)))
            XCTAssertFalse(
                ViewCaptureService.shouldTrackScreenNavigation(
                    instrumentVisibility: true, config: config(state: true, screen: false)))
        }

        func testVisibilityInstrumentationOffDisablesTracking() {
            // `instrumentVisibility` is what installs the `viewDidDisappear` swizzle; without those
            // pause events the broker never clears its visible set and stops backdating load times.
            XCTAssertFalse(
                ViewCaptureService.shouldTrackScreenNavigation(
                    instrumentVisibility: false, config: config(state: true, screen: true)))
        }

        func testNoConfigDisablesTracking() {
            XCTAssertFalse(
                ViewCaptureService.shouldTrackScreenNavigation(instrumentVisibility: true, config: nil))
        }
    }

#endif
