//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import EmbraceConfiguration
    import TestSupport
    import UIKit
    import XCTest

    @testable import EmbraceCore

    /// Pins the two pieces of wiring the navigation timeline depends on but cannot verify itself:
    /// that the view instrumentation actually taps the seam, and that the gates combine correctly.
    final class ScreenNavigationWiringTests: XCTestCase {

        private final class PlainViewController: UIViewController {}

        // MARK: - The seam

        private var handler: UIViewControllerHandler!
        private var dataSource: MockUIViewControllerHandlerDataSource!

        override func setUpWithError() throws {
            handler = UIViewControllerHandler()
            dataSource = MockUIViewControllerHandlerDataSource()
            handler.dataSource = dataSource
        }

        override func tearDownWithError() throws {
            handler = nil
            dataSource = nil
        }

        func testEveryAppearanceCallbackReachesTheNavigationSeam() throws {
            let vc = PlainViewController()
            let start = Date(timeIntervalSince1970: 1_000)

            handler.onViewWillAppearStart(vc, now: start)
            handler.onViewDidAppearStart(vc, now: start.addingTimeInterval(1))
            handler.onViewDidDisappear(vc, now: start.addingTimeInterval(2))

            XCTAssertEqual(dataSource.appearanceCalls.map(\.phase), [.willAppear, .didAppear, .didDisappear])
        }

        func testTheSeamReceivesTheCallbacksOwnTimestamp() throws {
            let vc = PlainViewController()
            let start = Date(timeIntervalSince1970: 1_000)

            handler.onViewWillAppearStart(vc, now: start)

            // Load times are attributed to when the OS callback fired, so the seam must be handed
            // that timestamp rather than one taken later on the handler's queue.
            let call = try XCTUnwrap(dataSource.appearanceCalls.first)
            XCTAssertEqual(call.time, start)
        }

        func testTheSeamIsTappedSynchronouslyOnTheCallingThread() {
            let vc = PlainViewController()

            handler.onViewWillAppearStart(vc, now: Date())

            // Asserted with no waiting: the broker downstream is serialized on the main queue and
            // asserts it, so the tap must happen before the handler hops to its own queue.
            XCTAssertEqual(dataSource.appearanceCalls.count, 1)
        }

        func testTheSeamIsTappedEvenWithoutInstrumentationState() {
            // `emb_instrumentation_state` is only set when first-render instrumentation runs. The
            // navigation tap sits above that guard so the timeline does not inherit an unrelated
            // feature's configuration.
            let vc = PlainViewController()
            XCTAssertNil(vc.emb_instrumentation_state)

            handler.onViewWillAppearStart(vc, now: Date())

            XCTAssertEqual(dataSource.appearanceCalls.count, 1)
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
                    instrumentVisibility: true,
                    config: config(state: true, screen: true)
                ))
        }

        func testEitherGateOffDisablesTracking() {
            // The epic's headline criterion: either flag at 0 means no screen state at all.
            XCTAssertFalse(
                ViewCaptureService.shouldTrackScreenNavigation(
                    instrumentVisibility: true,
                    config: config(state: false, screen: true)
                ))
            XCTAssertFalse(
                ViewCaptureService.shouldTrackScreenNavigation(
                    instrumentVisibility: true,
                    config: config(state: true, screen: false)
                ))
        }

        func testVisibilityInstrumentationOffDisablesTracking() {
            // Mechanical, not philosophical: `instrumentVisibility` is what installs the
            // `viewDidDisappear` swizzle, and without those pause events the broker never clears
            // its visible set — so load times silently stop being backdated.
            XCTAssertFalse(
                ViewCaptureService.shouldTrackScreenNavigation(
                    instrumentVisibility: false,
                    config: config(state: true, screen: true)
                ))
        }

        func testNoConfigDisablesTracking() {
            XCTAssertFalse(
                ViewCaptureService.shouldTrackScreenNavigation(instrumentVisibility: true, config: nil))
        }
    }

#endif
