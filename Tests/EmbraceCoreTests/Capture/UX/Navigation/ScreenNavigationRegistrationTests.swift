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
    /// builds the tracker, registers the recorder, and hooks app state.
    ///
    /// Every other test in this feature injects `navigationTracker` by hand, which means the whole
    /// of `startScreenNavigationTrackingIfEnabled` could be deleted without a single failure. These
    /// stand up a real SDK instance so that path runs for real.
    final class ScreenNavigationRegistrationTests: IntegrationTestCase {

        private final class Screen: UIViewController {}

        /// Stands in for the `@State` token the SwiftUI modifier holds.
        private final class Token {}

        override func tearDownWithError() throws {
            // Process-global, and the modifier reads it with no other setup — so a value left behind
            // here would make an unrelated test look like it had a live timeline.
            ManualScreenRegistry.reporter = nil
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
            return service
        }

        // MARK: - The gates decide whether anything is built

        func testBothGatesOnBuildsTheTracker() throws {
            let service = try startSDK(with: config(state: true, screen: true))

            XCTAssertNotNil(service.navigationTracker)
        }

        func testEitherGateOffBuildsNothing() throws {
            let stateOff = try startSDK(with: config(state: false, screen: true))
            XCTAssertNil(stateOff.navigationTracker)

            Embrace.client = nil

            let screenOff = try startSDK(with: config(state: true, screen: false))
            XCTAssertNil(screenOff.navigationTracker)
        }

        func testVisibilityInstrumentationOffBuildsNothing() throws {
            let service = try startSDK(
                with: config(state: true, screen: true),
                options: ViewCaptureService.Options(instrumentVisibility: false)
            )

            XCTAssertNil(service.navigationTracker)
        }

        // MARK: - Registration actually happened

        func testTheRecorderIsRegisteredSoScreensReachTheStateSpan() throws {
            try startSDK(with: config(state: true, screen: true))

            let vc = Screen()
            vc.emb_instrumentation_state = .init(identifier: UUID().uuidString)
            vc.viewWillAppear(false)
            vc.viewDidAppear(false)

            // Reads through the coordinator, which only knows about the recorder if `register` ran.
            // Deleting that call leaves the tracker working and the timeline invisible.
            let stamps = try XCTUnwrap(Embrace.client?.stateCoordinator.logAttributes)
            XCTAssertEqual(stamps["emb.state.screen-automatic"]?.description, "Screen")
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

            let stamps = try XCTUnwrap(Embrace.client?.stateCoordinator.logAttributes)
            XCTAssertEqual(stamps["emb.state.screen-automatic"]?.description, "Backgrounded")
        }

        // MARK: - Registering twice would duplicate the state span

        func testRestartingTheServiceDoesNotBuildASecondTracker() throws {
            let service = try startSDK(with: config(state: true, screen: true))
            let first = service.navigationTracker

            service.stop()
            service.start()

            // `StateCaptureCoordinator` has no `unregister`, so a second tracker would mean a second
            // recorder and two `emb-state-screen-automatic` spans in every subsequent part.
            XCTAssertTrue(first === service.navigationTracker)
        }

        // MARK: - The SwiftUI modifier's route into the SDK

        /// The modifier's only route to the pipeline is this registry, so a screen declared in
        /// SwiftUI reaching the state span depends on it having been published at start.
        func testADeclaredScreenReachesTheStateSpanThroughTheRegistry() throws {
            try startSDK(with: config(state: true, screen: true))

            let reporter = try XCTUnwrap(
                ManualScreenRegistry.reporter, "nothing published means the modifier is inert")
            reporter.onManualScreenAppear(
                id: ObjectIdentifier(Token()), name: "Settings", attributes: [:], at: Date())

            let stamps = try XCTUnwrap(Embrace.client?.stateCoordinator.logAttributes)
            XCTAssertEqual(stamps["emb.state.screen-automatic"]?.description, "Settings")
        }

        /// What makes the modifier a silent no-op rather than something needing its own gate check:
        /// with the feature off there is nothing for it to report to.
        func testNothingIsPublishedWhenTheFeatureIsOff() throws {
            try startSDK(with: config(state: true, screen: false))

            XCTAssertNil(ManualScreenRegistry.reporter)
        }

        /// Declared screens go through the same `serviceState` check as appearance callbacks, so a
        /// stopped service does not keep recording a timeline behind the SDK's back.
        func testAStoppedServiceIgnoresDeclaredScreens() throws {
            let service = try startSDK(with: config(state: true, screen: true))

            let reporter = try XCTUnwrap(ManualScreenRegistry.reporter)
            service.stop()
            reporter.onManualScreenAppear(
                id: ObjectIdentifier(Token()), name: "Settings", attributes: [:], at: Date())

            let stamps = try XCTUnwrap(Embrace.client?.stateCoordinator.logAttributes)
            XCTAssertNotEqual(stamps["emb.state.screen-automatic"]?.description, "Settings")
        }
    }

#endif
