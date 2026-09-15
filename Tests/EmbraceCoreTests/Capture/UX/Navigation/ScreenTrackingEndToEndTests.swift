//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import EmbraceSemantics
    import EmbraceStorageInternal
    import SwiftUI
    import TestSupport
    import UIKit
    import XCTest

    @testable import EmbraceCore

    /// Drives a whole session through the real SDK and asserts on the payload it would upload.
    ///
    /// Every other suite in this feature tests one layer against doubles. This one exists because the
    /// layers can each be right and still disagree: the state primitive, the config gates, the UIKit
    /// producer and the SwiftUI producer were built as separate tickets, and nothing until now has
    /// checked that a realistic sequence through all four lands correctly on the wire.
    ///
    /// Assertions here are deliberately on the *payload* — what the backend receives — rather than on
    /// spans in memory, because the payload is the contract.
    final class ScreenTrackingEndToEndTests: IntegrationTestCase {

        private final class HomeViewController: UIViewController {}
        private final class SettingsViewController: UIViewController {}
        private final class Token {}

        private var service: ViewCaptureService!

        /// Every service this suite starts, so teardown can stop them all — including one a test
        /// stands up mid-way to swap the config.
        private var startedServices: [ViewCaptureService] = []

        override func setUpWithError() throws {
            try super.setUpWithError()

            let config = EditableConfig()
            config.isStateCaptureEnabled = true
            config.isScreenTrackingEnabled = true

            service = ViewCaptureService(options: ViewCaptureService.Options(), lock: NSLock())
            startedServices.append(service)
            try Embrace.setup(
                options: Embrace.Options(
                    captureServices: [service],
                    crashReporter: nil,
                    runtimeConfiguration: config
                )
            ).start()
        }

        override func tearDownWithError() throws {
            // Stopped explicitly, because releasing it does not withdraw its registry publication:
            // a service that has run `onInstall` is retained for the process lifetime by its own
            // swizzle IMPs, which capture `self`. `IntegrationTestCase` only clears
            // `Embrace.client`, so without this the reporter stays published into every later test
            // in the bundle — and `ManualScreenRegistry` is process-global.
            startedServices.forEach { $0.stop() }
            startedServices = []
            service = nil
            try super.tearDownWithError()
        }

        // MARK: - Helpers

        /// Drives the real swizzled appearance callbacks, the way UIKit would.
        private func visit(_ vc: UIViewController) {
            vc.emb_instrumentation_state = .init(identifier: UUID().uuidString)
            vc.viewWillAppear(false)
            vc.viewDidAppear(false)
        }

        private func leave(_ vc: UIViewController) {
            vc.viewDidDisappear(false)
        }

        /// Stands in for `.embraceScreen` — the modifier's own wiring is covered by
        /// `EmbraceScreenViewModifierTests`; this is about what reaches the payload.
        private func declare(_ token: Token, _ name: String, attributes: EmbraceAttributes = [:]) {
            ManualScreenRegistry.reporter?.onManualScreenAppear(
                id: ObjectIdentifier(token), name: name, attributes: attributes, at: Date())
        }

        private func undeclare(_ token: Token, _ name: String) {
            ManualScreenRegistry.reporter?.onManualScreenDisappear(
                id: ObjectIdentifier(token), name: name, at: Date())
        }

        /// Ends the part and builds the payload the uploader would send.
        private func endSessionAndBuildPayload() throws -> (spans: [SpanPayload], spanSnapshots: [SpanPayload]) {
            let client = try XCTUnwrap(Embrace.client)
            let session = try XCTUnwrap(client.sessionController.currentSession)
            client.sessionController.endSession()

            let stored = try XCTUnwrap(client.storage.fetchSession(id: session.id))
            return SpansPayloadBuilder.build(for: stored, storage: client.storage)
        }

        /// The payload for a specific part, for tests that span more than one.
        private func payload(for id: EmbraceIdentifier) -> [SpanPayload] {
            guard let client = Embrace.client, let stored = client.storage.fetchSession(id: id) else {
                return []
            }
            return SpansPayloadBuilder.build(for: stored, storage: client.storage).spans
        }

        private func stateSpan(in spans: [SpanPayload]) throws -> SpanPayload {
            try XCTUnwrap(
                spans.first { $0.name == SpanSemantics.State.spanName(for: "screen-automatic") },
                "no state span in the payload — the timeline never reached the wire")
        }

        /// Transitions in timestamp order.
        ///
        /// **Sorted deliberately: the payload's event array order is not deterministic.** Events are
        /// persisted into `SpanRecord.events`, which is a CoreData `Set`, and nothing between there
        /// and the JSON sorts them — so the array arrives in whatever order the set happens to
        /// iterate, and it varies run to run. Asserting on the raw array order produces a test that
        /// passes perhaps one time in four.
        ///
        /// The timeline is still recoverable, because every event carries `time_unix_nano` at full
        /// nanosecond resolution, which is what this sorts on. But it means the ordering of this
        /// feature's whole payload depends on the consumer sorting rather than on the SDK emitting
        /// in order — worth confirming with whoever owns the backend.
        private func transitions(of span: SpanPayload) -> [String] {
            span.events
                .filter { $0.name == SpanSemantics.State.transitionEventName }
                .sorted { $0.timestamp < $1.timestamp }
                .compactMap { $0.attributes.first { $0.key == SpanSemantics.State.keyNewValue }?.value }
        }

        private func attribute(_ key: String, of span: SpanPayload) -> String? {
            span.attributes.first { $0.key == key }?.value
        }

        // MARK: - The whole journey

        /// A realistic mixed UIKit/SwiftUI session, asserted on the shipped payload.
        func testAMixedSessionProducesOneCoherentTimeline() throws {
            let home = HomeViewController()
            let settingsToken = Token()

            visit(home)
            leave(home)
            declare(settingsToken, "Settings", attributes: ["source": "menu"])
            undeclare(settingsToken, "Settings")
            visit(SettingsViewController())

            let (spans, _) = try endSessionAndBuildPayload()
            let state = try stateSpan(in: spans)

            XCTAssertEqual(
                transitions(of: state),
                ["HomeViewController", "Settings", "SettingsViewController"],
                "declared and automatic screens must share one ordered timeline")

            // Wire contract, all four layers agreeing.
            XCTAssertEqual(attribute(SpanSemantics.keyEmbraceType, of: state), EmbraceType.state.rawValue)
            XCTAssertEqual(attribute(SpanSemantics.State.keyInitialValue, of: state), "Initializing")
            XCTAssertEqual(attribute(SpanSemantics.State.keyTransitionCount, of: state), "3")
            XCTAssertNil(
                attribute(SpanSemantics.keyPrivate, of: state),
                "state spans are deliberately not private")
        }

        /// The session span must point at the state span, or the backend cannot associate them.
        func testTheSessionSpanLinksTheStateSpan() throws {
            visit(HomeViewController())

            let (spans, _) = try endSessionAndBuildPayload()
            let state = try stateSpan(in: spans)
            let session = try XCTUnwrap(spans.first { $0.name == SpanSemantics.Session.name })

            let stateLinks = session.links.filter { link in
                link.attributes.contains {
                    $0.key == SpanSemantics.keyLinkType && $0.value == SpanSemantics.State.linkType
                }
            }
            XCTAssertEqual(stateLinks.count, 1)
            XCTAssertEqual(stateLinks.first?.spanId, state.spanId)
        }

        /// Backgrounding is what makes the timeline readable as a session, so it has to survive the
        /// whole pipeline rather than only existing in the broker.
        /// Backgrounding ends the session part, so the timeline spans two payloads — and this is
        /// where three separately-built pieces have to agree: the part-end ordering (10838), the
        /// value carry-over that seeds the next part, and the foreground restore (10909).
        ///
        /// Part 1 must contain `Backgrounded`, which only happens if the app-state transition is
        /// recorded *before* `onSessionPartWillEnd` closes the span. Part 2 must open with
        /// `Backgrounded` as its `initial_value` and then restore the screen the user was actually
        /// on — UIKit does not re-fire appearance callbacks for it, so nothing else would.
        func testTheTimelineSurvivesABackgroundRoundTripAcrossTwoParts() throws {
            let client = try XCTUnwrap(Embrace.client)
            visit(HomeViewController())

            let part1 = try XCTUnwrap(client.sessionController.currentSession)
            NotificationCenter.default.post(
                name: UIApplication.didEnterBackgroundNotification, object: nil)

            // Background sessions are off in this config, so no part exists while backgrounded.
            XCTAssertNil(client.sessionController.currentSession)

            NotificationCenter.default.post(
                name: UIApplication.didBecomeActiveNotification, object: nil)
            let part2 = try XCTUnwrap(
                client.sessionController.currentSession, "returning to the foreground starts a part")
            client.sessionController.endSession()

            let firstState = try stateSpan(in: payload(for: part1.id))
            XCTAssertEqual(transitions(of: firstState), ["HomeViewController", "Backgrounded"])
            XCTAssertEqual(attribute(SpanSemantics.State.keyInitialValue, of: firstState), "Initializing")

            let secondState = try stateSpan(in: payload(for: part2.id))
            XCTAssertEqual(
                attribute(SpanSemantics.State.keyInitialValue, of: secondState), "Backgrounded",
                "the next part must open where the last one left off")
            XCTAssertEqual(
                transitions(of: secondState), ["HomeViewController"],
                "the screen the user was on must be restored, not left on the sentinel")
        }

        /// Caller metadata has to survive four hops — modifier, broker, recorder, payload builder.
        func testDeclaredAttributesReachThePayload() throws {
            declare(Token(), "ProductDetail", attributes: ["product_id": "42"])

            let (spans, _) = try endSessionAndBuildPayload()
            let state = try stateSpan(in: spans)

            let transition = try XCTUnwrap(
                state.events.first { $0.name == SpanSemantics.State.transitionEventName })
            XCTAssertEqual(transition.attributes.first { $0.key == "product_id" }?.value, "42")
        }

        // MARK: - The gates really do gate

        func testWithScreenTrackingOffNoStateSpanIsProducedAtAll() throws {
            // The setUp service must be stopped, not just abandoned. It is still `.active` and still
            // the published reporter, so `declare` below would reach *its* tracker and write into
            // the previous SDK's storage — and this test would then pass by inspecting the new
            // client's payload for a screen that never went near it.
            service.stop()

            Embrace.client = nil
            let config = EditableConfig()
            config.isStateCaptureEnabled = true
            config.isScreenTrackingEnabled = false

            let gatedService = ViewCaptureService(options: ViewCaptureService.Options(), lock: NSLock())
            startedServices.append(gatedService)
            try Embrace.setup(
                options: Embrace.Options(
                    captureServices: [gatedService],
                    crashReporter: nil,
                    runtimeConfiguration: config
                )
            ).start()

            // The actual precondition: the gate left nothing published, so a declared screen has
            // nowhere to go. Without this the assertion below cannot distinguish a working gate
            // from a screen that was quietly delivered somewhere else.
            XCTAssertNil(ManualScreenRegistry.reporter)

            visit(HomeViewController())
            declare(Token(), "Settings")

            let (spans, snapshots) = try endSessionAndBuildPayload()
            let all = spans + snapshots
            XCTAssertNil(all.first { $0.name == SpanSemantics.State.spanName(for: "screen-automatic") })
        }
    }

#endif
