//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import EmbraceSemantics
    import TestSupport
    import SwiftUI
    import UIKit
    import XCTest

    @testable import EmbraceCore

    /// Covers which controllers reach the timeline and what they are called. The timeline's *shape*
    /// — dedup, backdating, the sentinels — belongs to `NavigationEventBrokerTests`.
    final class ScreenNavigationTrackerTests: XCTestCase {

        private final class PlainViewController: UIViewController {}

        /// A developer-authored host subclass. Names itself; does NOT adopt the customization
        /// protocol, which is the case a type-based exclusion would wrongly drop.
        private final class CheckoutHostingController: UIHostingController<Text> {}
        private final class CustomNavigationController: UINavigationController {}

        private final class NamedViewController: UIViewController, EmbraceViewControllerCustomization {
            var nameForViewControllerInEmbrace: String? = "CustomName"
            var shouldCaptureViewInEmbrace: Bool = true
        }

        /// A host that names itself, which is the developer declaring it a screen.
        private final class NamedHostingController<V: View>: UIHostingController<V>,
            EmbraceViewControllerCustomization
        {
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

        /// The host's class name describes the SwiftUI view tree, not a screen — putting
        /// `UIHostingController<ModifiedContent<…>>` in the timeline is never the right answer.
        /// `makeTracker()` blocks nothing, standing in for the config flag that captures hosts being
        /// turned on: even then the timeline must refuse them.
        func testAnonymousHostingControllersAreSkippedEvenWhenNotBlocked() {
            let tracker = makeTracker()

            appear(tracker, UIHostingController(rootView: Text("hi")), startedAt: 0, resumedAt: 1)

            XCTAssertTrue(recordedScreens.isEmpty)
        }

        /// Naming a host is the developer saying it is a screen, so it is kept.
        func testANamedHostingControllerIsTracked() {
            let tracker = makeTracker()

            appear(tracker, NamedHostingController(rootView: Text("hi")), startedAt: 0, resumedAt: 1)

            XCTAssertEqual(recordedScreens, ["CustomName"])
        }

        /// A developer-authored subclass names itself perfectly well, so the exclusion must not
        /// catch it. `EmbraceIdentifiableHostingController` is conformed by every subclass, so a
        /// type-based test would silently drop this — the name is what the rule is about.
        func testAHostingControllerSubclassWithItsOwnNameIsTracked() {
            let tracker = makeTracker()

            appear(tracker, CheckoutHostingController(rootView: Text("hi")), startedAt: 0, resumedAt: 1)

            XCTAssertEqual(recordedScreens, ["CheckoutHostingController"])
        }

        /// The host is anonymous, not everything inside it.
        ///
        /// Note this is the behaviour *when hosting-controller capture is enabled*: `makeTracker()`
        /// blocks nothing, standing in for that config. Under the default block list the parent walk
        /// in `ViewControllerBlockList` excludes this child before the tracker is ever consulted.
        func testAChildControllerInsideAHostIsStillTracked() {
            let tracker = makeTracker()

            let host = UIHostingController(rootView: Text("hi"))
            let child = PlainViewController()
            host.addChild(child)

            appear(tracker, child, startedAt: 0, resumedAt: 1)

            XCTAssertEqual(recordedScreens, ["PlainViewController"])
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

        // MARK: - Screens declared in SwiftUI

        /// Stands in for the `@State` token the view modifier holds. Only its identity matters.
        private final class Token {}

        private func declareAppearance(
            _ tracker: ScreenNavigationTracker,
            _ token: Token,
            name: String,
            attributes: EmbraceAttributes = [:],
            at offset: TimeInterval
        ) {
            tracker.onManualScreenAppear(
                id: ObjectIdentifier(token),
                name: name,
                attributes: attributes,
                at: time(offset)
            )
        }

        func testADeclaredScreenIsRecorded() {
            let tracker = makeTracker()

            declareAppearance(tracker, Token(), name: "Settings", at: 0)

            XCTAssertEqual(recordedScreens, ["Settings"])
        }

        func testDeclaredAttributesLandOnTheTransitionEvent() throws {
            let tracker = makeTracker()

            declareAppearance(
                tracker, Token(), name: "ProductDetail", attributes: ["product_id": "42"], at: 0)

            let event = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
            XCTAssertEqual(event.attributes["product_id"]?.description, "42")
            XCTAssertEqual(
                event.attributes[SpanSemantics.State.keyNewValue]?.description, "ProductDetail")
        }

        /// The public API cannot forge the framework's own keys, whatever a caller passes.
        ///
        /// Deliberately forges a **counter** key. The counters are omitted from the event when their
        /// count is zero, so nothing overwrites a forged one — they are the keys the reserved-name
        /// filter actually protects. Asserting on `emb.state.new_value` instead would prove nothing,
        /// because that key is written after the merge and wins on ordering alone.
        func testReservedAttributeKeysCannotBeForged() throws {
            let tracker = makeTracker()

            declareAppearance(
                tracker,
                Token(),
                name: "Settings",
                attributes: [
                    SpanSemantics.State.keyNotInSession: "99",
                    SpanSemantics.State.keyNewValue: "forged"
                ],
                at: 0
            )

            let event = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
            XCTAssertNil(
                event.attributes[SpanSemantics.State.keyNotInSession],
                "a forged counter must not reach the payload")
            XCTAssertEqual(event.attributes[SpanSemantics.State.keyNewValue]?.description, "Settings")
        }

        /// One timeline, one span — a declared screen is not a second, parallel stream.
        func testDeclaredAndAutomaticScreensShareOneTimeline() {
            let tracker = makeTracker()

            appear(tracker, PlainViewController(), startedAt: 0, resumedAt: 1)
            declareAppearance(tracker, Token(), name: "Settings", at: 2)

            XCTAssertEqual(recordedScreens, ["PlainViewController", "Settings"])
            XCTAssertEqual(
                mockOTel.startedSpans.filter { $0.name == "emb-state-screen-automatic" }.count, 1)
        }

        /// The reason the modifier reports `onDisappear` at all: a declared screen that never
        /// reported going away would stay counted as visible and silently stop the *next* screen's
        /// load time from being backdated.
        func testADeclaredScreenDisappearingFreesTheVisibleSlot() throws {
            let tracker = makeTracker()
            let token = Token()

            declareAppearance(tracker, token, name: "Settings", at: 0)
            tracker.onManualScreenDisappear(id: ObjectIdentifier(token), name: "Settings", at: time(1))

            appear(tracker, PlainViewController(), startedAt: 2, resumedAt: 9)

            let load = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
            XCTAssertEqual(load.timestamp, time(2), "the next screen must still backdate to its start")
        }

        /// Without a disappearance the overlap rule takes over, which is the behaviour a developer
        /// gets for a sheet presented over a screen that stays visible underneath.
        func testADeclaredScreenLeftVisibleSuppressesBackdating() throws {
            let tracker = makeTracker()

            declareAppearance(tracker, Token(), name: "Settings", at: 0)
            appear(tracker, PlainViewController(), startedAt: 2, resumedAt: 9)

            let load = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
            XCTAssertEqual(load.timestamp, time(9), "two screens visible means no backdating")
        }

        /// A caller must not be able to mint a name the framework gives its own meaning to.
        /// Equality downstream is by name, so without this the real background transition — and the
        /// foreground restore after it — are both swallowed, and the session reports an app that
        /// never backgrounded.
        func testAScreenDeclaredWithAReservedNameIsRefused() {
            let tracker = makeTracker()

            declareAppearance(tracker, Token(), name: Screen.backgrounded.name, at: 0)
            tracker.appWillBackground(at: time(10))
            tracker.appDidForeground(at: time(20))

            XCTAssertEqual(recordedScreens, ["Backgrounded"], "only the real backgrounding, once")
            XCTAssertEqual(
                stateSpan?.events.count, 1,
                "the declared screen must not have produced a transition of its own")
        }

        func testTheInitializingSentinelIsReservedToo() {
            let tracker = makeTracker()

            declareAppearance(tracker, Token(), name: Screen.initializing.name, at: 0)

            XCTAssertTrue(recordedScreens.isEmpty)
        }

        func testAScreenDeclaredWithABlankNameIsRefused() {
            let tracker = makeTracker()

            declareAppearance(tracker, Token(), name: "   ", at: 0)
            declareAppearance(tracker, Token(), name: "", at: 1)

            XCTAssertTrue(recordedScreens.isEmpty)
        }

        // MARK: - Bounding caller attributes

        /// State spans skip the sanitizer (that exemption is what lets a part record far more than
        /// the customer event limit), so the bound has to be applied deliberately — otherwise the
        /// first public API to accept caller attributes ships them unbounded.
        func testCallerAttributesAreCappedInCount() throws {
            let tracker = makeTracker()

            var attributes: EmbraceAttributes = [:]
            for i in 0..<40 {
                attributes[String(format: "key-%02d", i)] = "v"
            }
            declareAppearance(tracker, Token(), name: "Busy", attributes: attributes, at: 0)

            let event = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
            let callerKeys = event.attributes.keys.filter { $0.hasPrefix("key-") }
            XCTAssertEqual(callerKeys.count, 10)
        }

        func testCallerAttributeValuesAreTruncated() throws {
            let tracker = makeTracker()

            declareAppearance(
                tracker, Token(), name: "Long",
                attributes: ["blob": String(repeating: "x", count: 5_000)], at: 0)

            let event = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
            XCTAssertEqual(event.attributes["blob"]?.description.count, 1_024)
        }

        func testCallerAttributeKeysAreTruncated() throws {
            let tracker = makeTracker()

            declareAppearance(
                tracker, Token(), name: "LongKey",
                attributes: [String(repeating: "k", count: 500): "v"], at: 0)

            let event = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
            XCTAssertTrue(event.attributes.keys.contains(String(repeating: "k", count: 128)))
        }

        /// Matches every other public attribute API in the SDK, which drops non-`String` values in
        /// `DefaultOtelSignalsSanitizer.sanitizeAttributes`. `EmbraceAttributeValue` admits
        /// `Int`/`Bool`/`Double` and the payload would serialize them, so this is arguably wrong —
        /// but it is wrong *consistently*, and diverging here would mean the same call recorded on a
        /// breadcrumb and on a screen behaved differently. Fix it in the sanitizer or not at all.
        func testNonStringAttributeValuesAreDropped() throws {
            let tracker = makeTracker()

            declareAppearance(
                tracker, Token(), name: "Cart",
                attributes: ["items": 3, "flag": true, "sku": "abc"], at: 0)

            let event = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
            XCTAssertNil(event.attributes["items"])
            XCTAssertNil(event.attributes["flag"])
            XCTAssertEqual(event.attributes["sku"]?.description, "abc", "strings still get through")
        }

        /// The framework's own keys must never be squeezed out by the caller's cap.
        func testTheContractKeysSurviveAFullCallerBudget() throws {
            let tracker = makeTracker()

            var attributes: EmbraceAttributes = [:]
            for i in 0..<40 {
                attributes["aaa-\(i)"] = "v"
            }
            declareAppearance(tracker, Token(), name: "Busy", attributes: attributes, at: 0)

            let event = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
            XCTAssertEqual(
                event.attributes[SpanSemantics.State.keyNewValue]?.description, "Busy",
                "emb.state.new_value must not compete with caller attributes for the budget")
        }

        // MARK: - Bounding the screen name

        /// The name is the one caller string nothing downstream bounds — it ships as an attribute
        /// value on internal spans, which skip sanitization, and is copied onto every log.
        func testALongScreenNameIsTruncated() throws {
            let tracker = makeTracker()

            declareAppearance(tracker, Token(), name: String(repeating: "N", count: 5_000), at: 0)

            XCTAssertEqual(recordedScreens.first?.count, 128)
        }

        /// Equality downstream is by name, so an untrimmed name invents navigations the user never
        /// made — the exact failure the public doc warns about.
        func testNamesDifferingOnlyByWhitespaceAreOneScreen() {
            let tracker = makeTracker()

            declareAppearance(tracker, Token(), name: "Home", at: 0)
            declareAppearance(tracker, Token(), name: "Home\n", at: 1)
            declareAppearance(tracker, Token(), name: "  Home  ", at: 2)

            XCTAssertEqual(recordedScreens, ["Home"], "one screen, not three")
        }

        /// Normalization runs before the sentinel check, or padding walks straight past it.
        func testAPaddedReservedNameIsStillRefused() {
            let tracker = makeTracker()

            declareAppearance(tracker, Token(), name: "  Backgrounded  ", at: 0)

            XCTAssertTrue(recordedScreens.isEmpty)
        }

        /// The automatic path is exposed to the same unbounded input through the public
        /// `EmbraceViewControllerCustomization`, so it gets the same treatment.
        func testACustomViewControllerNameIsAlsoNormalized() {
            let tracker = makeTracker()
            let vc = NamedViewController()
            vc.nameForViewControllerInEmbrace = "  Checkout\n"

            appear(tracker, vc, startedAt: 0, resumedAt: 1)

            XCTAssertEqual(recordedScreens, ["Checkout"])
        }

    }

#endif
