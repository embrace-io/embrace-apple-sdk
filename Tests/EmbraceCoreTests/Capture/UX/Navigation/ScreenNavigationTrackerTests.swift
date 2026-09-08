//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import EmbraceSemantics
    import TestSupport
    import UIKit
    import XCTest

    @testable import EmbraceCore

    /// Covers which controllers reach the timeline and what they are called. The timeline's *shape*
    /// — dedup, backdating, the sentinels — belongs to `NavigationEventBrokerTests`.
    final class ScreenNavigationTrackerTests: XCTestCase {

        private final class PlainViewController: UIViewController {}
        private final class CustomNavigationController: UINavigationController {}

        private final class NamedViewController: UIViewController, EmbraceViewControllerCustomization {
            var nameForViewControllerInEmbrace: String? = "CustomName"
            var shouldCaptureViewInEmbrace: Bool = true
        }

        private var mockOTel: MockOTelSignalsHandler!
        private var sessionSpan: EmbraceSpan!
        private var reporter: ScreenStateReporter!

        private let partStart = Date(timeIntervalSince1970: 1_000)

        override func setUpWithError() throws {
            mockOTel = MockOTelSignalsHandler()
            sessionSpan = try mockOTel.createInternalSpan(
                name: SpanSemantics.Session.name,
                type: .session,
                startTime: partStart
            )
            reporter = ScreenStateReporter(otel: mockOTel)
            reporter.recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)
            reporter.recorder.activate(at: partStart)
        }

        override func tearDownWithError() throws {
            mockOTel = nil
            sessionSpan = nil
            reporter = nil
        }

        // MARK: - Helpers

        private func makeTracker(blocked: @escaping (UIViewController) -> Bool = { _ in false })
            -> ScreenNavigationTracker
        {
            ScreenNavigationTracker(reporter: reporter, isBlocked: blocked)
        }

        private func time(_ offset: TimeInterval) -> Date {
            partStart.addingTimeInterval(offset)
        }

        /// Drives a full appear cycle, which is what produces a transition.
        private func appear(
            _ tracker: ScreenNavigationTracker,
            _ vc: UIViewController,
            startedAt: TimeInterval,
            resumedAt: TimeInterval
        ) {
            tracker.onAppearance(vc, phase: .willAppear, at: time(startedAt))
            tracker.onAppearance(vc, phase: .didAppear, at: time(resumedAt))
        }

        private var stateSpan: EmbraceSpan? {
            mockOTel.startedSpans.first { $0.name == "emb-state-screen-automatic" }
        }

        /// Asserts the span exists rather than defaulting to `[]`, so the "nothing was recorded"
        /// tests below cannot pass by the pipeline being dead instead of the filter working.
        private var recordedScreens: [String] {
            guard let stateSpan else {
                XCTFail("no state span — the pipeline is not running, so filtering proves nothing")
                return []
            }
            return stateSpan.events.compactMap {
                $0.attributes[SpanSemantics.State.keyNewValue]?.description
            }
        }

        // MARK: - What counts as a screen

        func testAPlainViewControllerIsTracked() {
            let tracker = makeTracker()

            appear(tracker, PlainViewController(), startedAt: 0, resumedAt: 1)

            XCTAssertEqual(recordedScreens, ["PlainViewController"])
        }

        func testContainerControllersAreSkipped() {
            let tracker = makeTracker()

            appear(tracker, UINavigationController(), startedAt: 0, resumedAt: 1)
            appear(tracker, UITabBarController(), startedAt: 2, resumedAt: 3)
            appear(tracker, UISplitViewController(), startedAt: 4, resumedAt: 5)
            appear(tracker, UIPageViewController(), startedAt: 6, resumedAt: 7)

            // Containers appear alongside the content they present. Letting them through would both
            // put "UINavigationController" in the timeline and keep two screens visible at once,
            // which suppresses load-time backdating for the real screen.
            XCTAssertTrue(recordedScreens.isEmpty)
        }

        func testContainerSubclassesAreAlsoSkipped() {
            let tracker = makeTracker()

            appear(tracker, CustomNavigationController(), startedAt: 0, resumedAt: 1)

            // `isKind(of:)`, not `isMember(of:)` — custom container subclasses are common.
            XCTAssertTrue(recordedScreens.isEmpty)
        }

        func testBlockedControllersAreSkipped() {
            let tracker = makeTracker { $0 is PlainViewController }

            appear(tracker, PlainViewController(), startedAt: 0, resumedAt: 1)

            XCTAssertTrue(recordedScreens.isEmpty)
        }

        func testControllersOptedOutOfCaptureAreSkipped() {
            let tracker = makeTracker()
            let vc = NamedViewController()
            vc.shouldCaptureViewInEmbrace = false

            appear(tracker, vc, startedAt: 0, resumedAt: 1)

            // The same opt-out the view instrumentation honours, so a controller a customer has
            // already excluded stays out of both streams.
            XCTAssertTrue(recordedScreens.isEmpty)
        }

        func testADisappearanceIsForwardedEvenWhenTheControllerBecomesBlocked() throws {
            var blocked: Set<String> = []
            let tracker = makeTracker { blocked.contains(String(describing: type(of: $0))) }

            let first = PlainViewController()
            appear(tracker, first, startedAt: 0, resumedAt: 1)

            // A remote-config refresh lands mid-visit and blocks this controller's class.
            blocked.insert("PlainViewController")
            tracker.onAppearance(first, phase: .didDisappear, at: time(2))
            blocked.removeAll()

            // If the disappearance had been filtered out, `first` would still be counted visible and
            // this load would not be backdated to its start.
            let second = NamedViewController()
            appear(tracker, second, startedAt: 3, resumedAt: 8)

            let span = try XCTUnwrap(stateSpan)
            let load = try XCTUnwrap(span.events.last)
            XCTAssertEqual(load.timestamp, time(3), "backdating must survive a mid-visit filter change")
        }

        // MARK: - Naming

        func testTheCustomisedNameWins() {
            let tracker = makeTracker()

            appear(tracker, NamedViewController(), startedAt: 0, resumedAt: 1)

            XCTAssertEqual(recordedScreens, ["CustomName"])
        }

        // MARK: - App state

        func testBackgroundAndForegroundBookendTheTimeline() {
            let tracker = makeTracker()
            let vc = PlainViewController()

            appear(tracker, vc, startedAt: 0, resumedAt: 1)
            tracker.appWillBackground(at: time(10))
            tracker.appDidForeground(at: time(20))

            // UIKit does not re-fire appearance callbacks for the controller that stayed visible,
            // so without the foreground restore the state would sit on "Backgrounded".
            XCTAssertEqual(recordedScreens, ["PlainViewController", "Backgrounded", "PlainViewController"])
        }

        func testTheBackgroundedSentinelIsTheContractString() {
            let tracker = makeTracker()

            appear(tracker, PlainViewController(), startedAt: 0, resumedAt: 1)
            tracker.appWillBackground(at: time(10))

            XCTAssertEqual(recordedScreens.last, Screen.backgrounded.name)
        }
    }

#endif
