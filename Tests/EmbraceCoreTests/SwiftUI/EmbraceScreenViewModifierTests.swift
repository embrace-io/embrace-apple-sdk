//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import EmbraceSemantics
    import SwiftUI
    import UIKit
    import XCTest

    @testable import EmbraceCore

    /// Drives the public `.embraceScreen` modifier through real SwiftUI, rather than calling the
    /// reporting protocol directly.
    ///
    /// The rest of this feature's tests start one layer below, at `ScreenNavigationTracker`. That
    /// leaves the modifier itself — the only part of this ticket a developer actually writes —
    /// covered by nothing: its entire body could be replaced with `content` and every other test in
    /// the feature would still pass.
    @available(iOS 13, tvOS 13, *)
    final class EmbraceScreenViewModifierTests: XCTestCase {

        // MARK: - Doubles

        private final class SpyReporter: ManualScreenReporting {

            struct Report {
                let id: ObjectIdentifier
                let name: String
                let attributes: EmbraceAttributes
            }

            private(set) var appearances: [Report] = []
            private(set) var disappearances: [Report] = []

            var onAppear: (() -> Void)?
            var onDisappear: (() -> Void)?

            func onManualScreenAppear(
                id: ObjectIdentifier,
                name: String,
                attributes: EmbraceAttributes,
                at time: Date
            ) {
                appearances.append(Report(id: id, name: name, attributes: attributes))
                onAppear?()
            }

            func onManualScreenDisappear(id: ObjectIdentifier, name: String, at time: Date) {
                disappearances.append(Report(id: id, name: name, attributes: [:]))
                onDisappear?()
            }
        }

        /// Lets a test force a re-render, and remove the screen, from outside SwiftUI.
        private final class Model: ObservableObject {
            @Published var isVisible = true
            @Published var tick = 0
        }

        /// Counts real body evaluations, so a test that means to force a re-render can prove one
        /// happened instead of assuming it. SwiftUI coalesces state changes made in the same turn of
        /// the run loop, so "I set a property" is not evidence the view was rebuilt.
        private final class RenderCounter {
            var count = 0
        }

        private struct HostView: View {
            @ObservedObject var model: Model
            let name: String
            let attributes: EmbraceAttributes
            let renders: RenderCounter

            var body: some View {
                renders.count += 1
                return VStack {
                    if model.isVisible {
                        Text("content \(model.tick)")
                            .embraceScreen(name, attributes: attributes)
                    }
                }
            }
        }

        // MARK: - Fixture

        private var spy: SpyReporter!
        private var model: Model!
        private var window: UIWindow!
        private var renders: RenderCounter!
        private var registration: ManualScreenRegistry.Registration!

        override func setUpWithError() throws {
            spy = SpyReporter()
            model = Model()
            renders = RenderCounter()
            // Held strongly here: the registry's reference is weak, so a spy the test does not
            // retain would vanish and every assertion below would pass vacuously.
            registration = ManualScreenRegistry.publish(spy)
        }

        override func tearDownWithError() throws {
            window?.isHidden = true
            window = nil
            model = nil
            renders = nil
            registration = nil
            spy = nil
        }

        /// Puts the view on screen for real. SwiftUI only runs `onAppear` for a view in a window
        /// that is actually being displayed.
        private func present(name: String = "Home", attributes: EmbraceAttributes = [:]) {
            let host = UIHostingController(
                rootView: HostView(
                    model: model, name: name, attributes: attributes, renders: renders))
            window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = host
            window.makeKeyAndVisible()
        }

        private func waitForAppearance() {
            let reported = expectation(description: "screen reported as appeared")
            spy.onAppear = { reported.fulfill() }
            wait(for: [reported], timeout: 5)
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

        private func waitForDisappearance() {
            let reported = expectation(description: "screen reported as disappeared")
            spy.onDisappear = { reported.fulfill() }
            wait(for: [reported], timeout: 5)
        }

        // MARK: - The modifier reports at all

        func testAppearingReportsTheDeclaredNameAndAttributes() throws {
            present(name: "ProductDetail", attributes: ["product_id": "42"])
            waitForAppearance()

            let report = try XCTUnwrap(spy.appearances.first)
            XCTAssertEqual(report.name, "ProductDetail")
            XCTAssertEqual(report.attributes["product_id"]?.description, "42")
        }

        func testOmittedAttributesArriveEmptyRatherThanAsAnOptional() throws {
            present(name: "Home")
            waitForAppearance()

            XCTAssertTrue(try XCTUnwrap(spy.appearances.first).attributes.isEmpty)
        }

        func testDisappearingIsReported() {
            present()
            waitForAppearance()

            model.isVisible = false
            waitForDisappearance()

            XCTAssertEqual(spy.disappearances.count, 1)
        }

        // MARK: - Screen identity

        /// The whole reason the token lives in `@State`.
        ///
        /// A plain `let` would allocate a fresh token every time SwiftUI rebuilds the modifier
        /// struct, so the disappearance would carry a *different* id from the appearance. The
        /// pipeline keys its visible-screen bookkeeping on that id, so the entry would never be
        /// cleared — and one unpaired appearance permanently stops load times being backdated for
        /// every later screen in the session.
        func testTheSameScreenKeepsOneIdentityAcrossReRenders() throws {
            present()
            waitForAppearance()

            // Prove a rebuild actually happened before relying on it. Without this the test passes
            // whether or not the modifier's identity is stable, because SwiftUI would coalesce the
            // change below with the removal into a single pass and never rebuild separately.
            model.tick += 1
            XCTAssertTrue(pumpRenderCycle(), "the view did not re-render; the test proves nothing")

            model.isVisible = false
            waitForDisappearance()

            let appeared = try XCTUnwrap(spy.appearances.first)
            let disappeared = try XCTUnwrap(spy.disappearances.first)
            XCTAssertEqual(
                appeared.id, disappeared.id,
                "a re-render must not change the screen's identity")
        }

        /// Two views declaring the same name are two screens, not one — the id comes from the view
        /// instance, not the name.
        func testTwoViewsWithTheSameNameGetDistinctIdentities() throws {
            let host = UIHostingController(
                rootView: VStack {
                    Text("a").embraceScreen("Duplicate")
                    Text("b").embraceScreen("Duplicate")
                })
            window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = host

            let bothReported = expectation(description: "both screens reported")
            bothReported.expectedFulfillmentCount = 2
            spy.onAppear = { bothReported.fulfill() }
            window.makeKeyAndVisible()
            wait(for: [bothReported], timeout: 5)

            XCTAssertEqual(spy.appearances.count, 2)
            XCTAssertNotEqual(spy.appearances[0].id, spy.appearances[1].id)
        }

        // MARK: - The no-op contract

        /// With no reporter published — the feature off, or the SDK not started — the modifier must
        /// be inert rather than crashing or trapping.
        func testWithNoReporterTheModifierIsInert() {
            registration = nil

            present()
            // Nothing to wait for; pump the run loop so any reporting would have happened.
            let settled = expectation(description: "run loop settled")
            DispatchQueue.main.async { settled.fulfill() }
            wait(for: [settled], timeout: 5)

            XCTAssertTrue(spy.appearances.isEmpty)
        }
    }

#endif
