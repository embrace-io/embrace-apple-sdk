//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import EmbraceSemantics
    import SwiftUI
    import TestSupport
    import UIKit
    import XCTest

    @testable import EmbraceCore

    /// Drives the public `.embraceScreen` modifier through real SwiftUI into a real
    /// ``ScreenTrackingHandler``, asserting on the transitions it records.
    ///
    /// The rest of this feature's tests start one layer below, at the handler. That leaves the
    /// modifier itself — the only part of this feature a developer actually writes — covered by
    /// nothing: its entire body could be replaced with `content` and every other test in the
    /// feature would still pass.
    @available(iOS 13, tvOS 13, *)
    final class EmbraceScreenViewModifierTests: XCTestCase {

        // MARK: - Doubles

        /// Lets a test force a re-render, and add or remove a screen, from outside SwiftUI.
        private final class Model: ObservableObject {
            @Published var showsDetail = false
            @Published var tick = 0
        }

        /// Counts real body evaluations, so a test that means to force a re-render can prove one
        /// happened instead of assuming it. SwiftUI coalesces state changes made in the same turn of
        /// the run loop, so "I set a property" is not evidence the view was rebuilt.
        private final class RenderCounter {
            var count = 0
        }

        /// A base screen, with a second one that can be shown over it — the shape of a sheet.
        private struct HostView: View {
            @ObservedObject var model: Model
            let name: String
            let attributes: EmbraceAttributes
            let renders: RenderCounter

            var body: some View {
                renders.count += 1
                return VStack {
                    Text("base").embraceScreen(name, attributes: attributes)
                    if model.showsDetail {
                        Text("detail \(model.tick)").embraceScreen("Detail")
                    }
                }
            }
        }

        // MARK: - Fixture

        private var mockOTel: MockOTelSignalsHandler!
        private var handler: ScreenTrackingHandler!
        private var model: Model!
        private var window: UIWindow!
        private var renders: RenderCounter!

        override func setUpWithError() throws {
            mockOTel = MockOTelSignalsHandler()
            handler = ScreenTrackingHandler(otel: mockOTel)
            let sessionSpan = try mockOTel.createInternalSpan(
                name: SpanSemantics.Session.name,
                type: .session,
                startTime: Date()
            )
            handler.recorder.onSessionPartStart(sessionSpan: sessionSpan, at: Date())
            ScreenTrackingHandler.makeCurrent(handler)

            model = Model()
            renders = RenderCounter()
        }

        override func tearDownWithError() throws {
            window?.isHidden = true
            window = nil
            // Process-global; a handler left here would follow the next test into an unrelated suite.
            ScreenTrackingHandler.resignCurrent(handler)
            handler = nil
            mockOTel = nil
            model = nil
            renders = nil
        }

        private var stateSpan: EmbraceSpan? {
            mockOTel.startedSpans.first { $0.name == "emb-state-screen-automatic" }
        }

        private var transitions: [EmbraceSpanEvent] {
            stateSpan?.events.filter { $0.name == SpanSemantics.State.transitionEventName } ?? []
        }

        private var recordedScreens: [String] {
            transitions.compactMap { $0.attributes[SpanSemantics.State.keyNewValue]?.description }
        }

        /// Puts the view on screen for real. SwiftUI only runs `onAppear` for a view in a window
        /// that is actually being displayed.
        private func present(name: String = "Home", attributes: EmbraceAttributes = [:]) {
            present(HostView(model: model, name: name, attributes: attributes, renders: renders))
        }

        private func present<V: View>(_ view: V) {
            window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = UIHostingController(rootView: view)
            window.makeKeyAndVisible()
        }

        private func waitForTransitions(_ count: Int) {
            let recorded = expectation(
                for: NSPredicate { [unowned self] _, _ in self.transitions.count >= count },
                evaluatedWith: nil
            )
            wait(for: [recorded], timeout: 10)
        }

        /// Lets SwiftUI actually run an update pass, and returns whether the body was rebuilt.
        @discardableResult
        private func pumpRenderCycle() -> Bool {
            let before = renders.count
            for _ in 0..<10 {
                let turn = expectation(description: "run loop turn")
                DispatchQueue.main.async { turn.fulfill() }
                wait(for: [turn], timeout: 5)
                RunLoop.current.run(until: Date().addingTimeInterval(0.02))
                if renders.count > before { return true }
            }
            return false
        }

        // MARK: - The modifier reports at all

        func testAppearingRecordsTheDeclaredNameAndAttributes() throws {
            present(name: "ProductDetail", attributes: ["product_id": "42"])
            waitForTransitions(1)

            let transition = try XCTUnwrap(transitions.first)
            XCTAssertEqual(transition.attributes[SpanSemantics.State.keyNewValue]?.description, "ProductDetail")
            XCTAssertEqual(transition.attributes["product_id"]?.description, "42")
        }

        func testOmittedAttributesArriveEmptyRatherThanAsAnOptional() throws {
            present(name: "Home")
            waitForTransitions(1)

            let transition = try XCTUnwrap(transitions.first)
            XCTAssertTrue(transition.attributes.keys.allSatisfy { SpanSemantics.State.isReserved($0) })
        }

        // MARK: - Screen identity

        /// Covers both that a disappearance is reported and the reason the token lives in `@State`.
        ///
        /// Dismissing the screen on top hands the timeline back to the one underneath, which the
        /// handler only does when the disappearance carries the *same* id as the appearance. A plain
        /// `let` would allocate a fresh token every time SwiftUI rebuilds the modifier struct, so after
        /// a re-render the ids would differ, nothing would be revealed, and the dismissed screen would
        /// also stay counted as visible — permanently stopping load times being backdated for every
        /// later screen in the session.
        func testDismissingAScreenAfterAReRenderHandsTheTimelineBack() {
            present(name: "Home")
            waitForTransitions(1)

            model.showsDetail = true
            waitForTransitions(2)

            // Prove a rebuild actually happened before relying on it. Without this the test passes
            // whether or not the modifier's identity is stable, because SwiftUI would coalesce the
            // change below with the removal into a single pass and never rebuild separately.
            model.tick += 1
            XCTAssertTrue(pumpRenderCycle(), "the view did not re-render; the test proves nothing")

            model.showsDetail = false
            waitForTransitions(3)

            XCTAssertEqual(recordedScreens, ["Home", "Detail", "Home"])
        }

        /// Two views declaring the same name are two screens, not one — the id comes from the view
        /// instance, not the name. Both pass the handler's gate, and the recorder then drops the second
        /// as a repeat of the same value, which is what the count below records. Keyed by name, the
        /// gate would have swallowed it and nothing would be counted.
        func testTwoViewsWithTheSameNameGetDistinctIdentities() throws {
            present(
                VStack {
                    Text("a").embraceScreen("Duplicate")
                    Text("b").embraceScreen("Duplicate")
                })
            waitForTransitions(1)
            pumpRenderCycle()

            handler.recorder.onSessionPartWillEnd(at: Date())

            let span = try XCTUnwrap(stateSpan)
            XCTAssertEqual(recordedScreens, ["Duplicate"])
            XCTAssertEqual(span.attributes[SpanSemantics.State.keyDroppedByInstrumentation]?.description, "1")
        }

        // MARK: - The no-op contract

        /// With no handler published — the feature off, or the SDK not started — the modifier must be
        /// inert rather than crashing or trapping.
        func testWithNoHandlerTheModifierIsInert() {
            ScreenTrackingHandler.resignCurrent(handler)

            present()
            // Nothing to wait for; pump the run loop so any reporting would have happened.
            let settled = expectation(description: "run loop settled")
            DispatchQueue.main.async { settled.fulfill() }
            wait(for: [settled], timeout: 5)

            XCTAssertTrue(transitions.isEmpty)
        }
    }

#endif
