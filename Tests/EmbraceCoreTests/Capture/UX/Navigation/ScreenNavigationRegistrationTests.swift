//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import EmbraceSemantics
    import TestSupport
    import UIKit
    import XCTest

    @testable import EmbraceCore

    /// Covers the step between "the gates say yes" and "a timeline exists": that `onStart` actually
    /// builds the handler, registers the recorder, hooks app state and publishes the handler.
    ///
    /// Every other test in this feature injects `screenTracker` by hand, which means the whole of
    /// `startScreenTrackingIfEnabled` could be deleted without a single failure. These stand up a
    /// real SDK instance so that path runs for real.
    final class ScreenNavigationRegistrationTests: IntegrationTestCase {

        private final class Screen: UIViewController {}

        /// Stands in for the `@State` token the SwiftUI modifier holds.
        private final class Token {}

        /// Every service these tests start, so teardown can stop them.
        ///
        /// `IntegrationTestCase` clears `Embrace.client` but does not stop capture services, and a
        /// service that is still running still has its handler in `ScreenTrackingHandler.current` —
        /// a process-global. Without this, whether the next test sees a stale handler depends on when
        /// ARC happens to release the previous SDK instance.
        private var startedServices: [ViewCaptureService] = []

        override func tearDownWithError() throws {
            startedServices.forEach { $0.stop() }
            startedServices = []
            try super.tearDownWithError()
        }

        private func config(state: Bool, screen: Bool) -> EditableConfig {
            let config = EditableConfig()
            config.isStateCaptureEnabled = state
            config.isScreenTrackingEnabled = screen
            return config
        }

        @discardableResult
        private func startSDK(
            with config: EditableConfig,
            options: ViewCaptureService.Options = ViewCaptureService.Options()
        ) throws -> ViewCaptureService {
            let service = ViewCaptureService(options: options, lock: NSLock())
            try Embrace.setup(
                options: Embrace.Options(
                    captureServices: [service],
                    crashReporter: nil,
                    runtimeConfiguration: config
                )
            ).start()
            startedServices.append(service)
            return service
        }

        // MARK: - The gates decide whether anything is built

        func testBothGatesOnBuildsTheHandler() throws {
            let service = try startSDK(with: config(state: true, screen: true))

            XCTAssertNotNil(service.screenTracker)
        }

        func testEitherGateOffBuildsNothing() throws {
            let stateOff = try startSDK(with: config(state: false, screen: true))
            XCTAssertNil(stateOff.screenTracker)

            Embrace.client = nil

            let screenOff = try startSDK(with: config(state: true, screen: false))
            XCTAssertNil(screenOff.screenTracker)
        }

        func testVisibilityInstrumentationOffBuildsNothing() throws {
            let service = try startSDK(
                with: config(state: true, screen: true),
                options: ViewCaptureService.Options(instrumentVisibility: false)
            )

            XCTAssertNil(service.screenTracker)
        }

        // MARK: - Registration actually happened

        func testTheRecorderIsRegisteredSoScreensReachTheStateSpan() throws {
            try startSDK(with: config(state: true, screen: true))

            let vc = Screen()
            vc.emb_instrumentation_state = .init(identifier: UUID().uuidString)
            vc.viewWillAppear(false)
            vc.viewDidAppear(false)

            // Reads through the state controller, which only knows about the recorder if `register` ran.
            // Deleting that call leaves the handler working and the timeline invisible.
            let stamps = try XCTUnwrap(Embrace.client?.stateController.logAttributes)
            XCTAssertEqual(stamps["emb.state.screen-automatic"]?.description, "Screen")
            XCTAssertNil(
                stamps["emb.state.screen-automatic.value_type"],
                "a screen from the app has no value type")
        }

        func testAppStateIsHookedSoBackgroundingReachesTheTimeline() throws {
            try startSDK(with: config(state: true, screen: true))

            let vc = Screen()
            vc.emb_instrumentation_state = .init(identifier: UUID().uuidString)
            vc.viewWillAppear(false)
            vc.viewDidAppear(false)

            // Drives the real notification the lifecycle observes, so this covers
            // `setAppStateObserver` having been called at all.
            NotificationCenter.default.post(
                name: UIApplication.didEnterBackgroundNotification, object: nil)

            let stamps = try XCTUnwrap(Embrace.client?.stateController.logAttributes)
            XCTAssertEqual(stamps["emb.state.screen-automatic"]?.description, "Backgrounded")
            XCTAssertEqual(
                stamps["emb.state.screen-automatic.value_type"]?.description, "system",
                "so a log emitted here is not read as a screen the app happens to call that")
        }

        // MARK: - Registering twice would duplicate the state span

        func testRestartingTheServiceDoesNotBuildASecondHandler() throws {
            let service = try startSDK(with: config(state: true, screen: true))
            let first = service.screenTracker

            service.stop()
            service.start()

            // `StateController` has no `unregister`, so a second handler would mean a second
            // recorder and two `emb-state-screen-automatic` spans in every subsequent part.
            XCTAssertTrue(first === service.screenTracker)
        }

        /// A restart must re-publish. `onStop` withdraws, and the handler is deliberately *not*
        /// rebuilt, so without re-publishing the service would keep recording UIKit screens while
        /// every SwiftUI one silently vanished.
        func testRestartingTheServiceRepublishesTheHandler() throws {
            let service = try startSDK(with: config(state: true, screen: true))

            service.stop()
            XCTAssertNil(ScreenTrackingHandler.current, "a stopped service must not stay published")

            service.start()
            XCTAssertTrue(ScreenTrackingHandler.current === service.screenTracker)
        }

        // MARK: - The SwiftUI modifier's route into the SDK

        /// The modifier's only route to the timeline is `ScreenTrackingHandler.current`, so a screen
        /// declared in SwiftUI reaching the state span depends on it having been published at start.
        func testADeclaredScreenReachesTheStateSpanThroughTheCurrentHandler() throws {
            try startSDK(with: config(state: true, screen: true))

            let handler = try XCTUnwrap(
                ScreenTrackingHandler.current, "nothing published means the modifier is inert")
            handler.manualScreenAppeared(
                id: ObjectIdentifier(Token()), name: "Settings", attributes: [:], at: Date())

            let stamps = try XCTUnwrap(Embrace.client?.stateController.logAttributes)
            XCTAssertEqual(stamps["emb.state.screen-automatic"]?.description, "Settings")
        }

        /// What makes the modifier a silent no-op rather than something needing its own gate check:
        /// with the feature off there is nothing for it to report to.
        func testNothingIsPublishedWhenTheFeatureIsOff() throws {
            try startSDK(with: config(state: true, screen: false))

            XCTAssertNil(ScreenTrackingHandler.current)
        }

        /// Stopping withdraws the handler, and the modifier looks it up on every call, so a stopped
        /// service does not keep recording declared screens behind the SDK's back.
        func testAStoppedServiceIgnoresDeclaredScreens() throws {
            let service = try startSDK(with: config(state: true, screen: true))

            service.stop()
            ScreenTrackingHandler.current?.manualScreenAppeared(
                id: ObjectIdentifier(Token()), name: "Settings", attributes: [:], at: Date())

            let stamps = try XCTUnwrap(Embrace.client?.stateController.logAttributes)
            XCTAssertNotEqual(stamps["emb.state.screen-automatic"]?.description, "Settings")
        }

        /// Stopping also unhooks app state, so backgrounding after a stop is not recorded either.
        func testAStoppedServiceIgnoresAppStateChanges() throws {
            let service = try startSDK(with: config(state: true, screen: true))

            let vc = Screen()
            vc.emb_instrumentation_state = .init(identifier: UUID().uuidString)
            vc.viewWillAppear(false)
            vc.viewDidAppear(false)

            service.stop()
            NotificationCenter.default.post(
                name: UIApplication.didEnterBackgroundNotification, object: nil)

            let stamps = try XCTUnwrap(Embrace.client?.stateController.logAttributes)
            XCTAssertEqual(stamps["emb.state.screen-automatic"]?.description, "Screen")
        }
    }

#endif
