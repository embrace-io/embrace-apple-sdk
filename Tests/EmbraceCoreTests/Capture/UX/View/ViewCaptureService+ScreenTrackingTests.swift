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
    /// — dedup, backdating, the sentinels — belongs to `ScreenTrackingHandlerTests`.
    ///
    /// Drives `onViewControllerAppearance` directly; `ScreenNavigationWiringTests` covers the
    /// swizzles that call it.
    final class ViewCaptureServiceScreenTrackingTests: XCTestCase {

        private final class PlainViewController: UIViewController {}

        /// A splash screen a developer would plausibly name this — the realistic collision.
        private final class Initializing: UIViewController {}

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

        /// A generic host subclass, whose *class* name carries type parameters even though it is
        /// developer-authored.
        private final class GenericHostingController<V: View>: UIHostingController<V> {}

        private var mockOTel: MockOTelSignalsHandler!
        private var service: ViewCaptureService!
        private var handler: ScreenTrackingHandler!

        private let partStart = Date(timeIntervalSince1970: 1_000)

        override func setUpWithError() throws {
            mockOTel = MockOTelSignalsHandler()

            handler = ScreenTrackingHandler(otel: mockOTel)
            let sessionSpan = try mockOTel.createInternalSpan(
                name: SpanSemantics.Session.name,
                type: .session,
                startTime: partStart
            )
            handler.recorder.onSessionPartStart(sessionSpan: sessionSpan, at: partStart)

            // Active without installing, so no swizzle runs: these tests call the tap directly.
            service = ViewCaptureService(options: ViewCaptureService.Options(), lock: NSLock())
            service.state.store(.active)
            service.screenTracker = handler
            block()
        }

        override func tearDownWithError() throws {
            mockOTel = nil
            service = nil
            handler = nil
        }

        // MARK: - Helpers

        /// Replaces the service's block list. Blocks nothing by default — hosting controllers
        /// included, standing in for the config flag that captures hosts being turned on.
        private func block(types: [AnyClass] = [], names: [String] = []) {
            service.blockList.safeValue = ViewControllerBlockList(
                types: types,
                names: names,
                blockHostingControllers: false
            )
        }

        private func time(_ offset: TimeInterval) -> Date {
            partStart.addingTimeInterval(offset)
        }

        /// Drives a full appear cycle, which is what produces a transition.
        private func appear(
            _ vc: UIViewController,
            startedAt: TimeInterval,
            resumedAt: TimeInterval
        ) {
            service.onViewControllerAppearance(vc, phase: .willAppear, at: time(startedAt))
            service.onViewControllerAppearance(vc, phase: .didAppear, at: time(resumedAt))
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

        /// The value type of each recorded transition, in the same order, `nil` where the attribute
        /// is absent — which is every screen that came from the app.
        private var recordedValueTypes: [String?] {
            stateSpan?.events.map {
                $0.attributes[SpanSemantics.State.keyValueType]?.description
            } ?? []
        }

        // MARK: - What counts as a screen

        func testAPlainViewControllerIsTracked() {
            appear(PlainViewController(), startedAt: 0, resumedAt: 1)

            XCTAssertEqual(recordedScreens, ["PlainViewController"])
        }

        func testContainerControllersAreSkipped() {
            appear(UINavigationController(), startedAt: 0, resumedAt: 1)
            appear(UITabBarController(), startedAt: 2, resumedAt: 3)
            appear(UISplitViewController(), startedAt: 4, resumedAt: 5)
            appear(UIPageViewController(), startedAt: 6, resumedAt: 7)

            // Containers appear alongside the content they present. Letting them through would both
            // put "UINavigationController" in the timeline and keep two screens visible at once,
            // which suppresses load-time backdating for the real screen.
            XCTAssertTrue(recordedScreens.isEmpty)
        }

        func testContainerSubclassesAreAlsoSkipped() {
            appear(CustomNavigationController(), startedAt: 0, resumedAt: 1)

            // `isKind(of:)`, not `isMember(of:)` — custom container subclasses are common.
            XCTAssertTrue(recordedScreens.isEmpty)
        }

        func testBlockedControllersAreSkipped() {
            block(types: [PlainViewController.self])

            appear(PlainViewController(), startedAt: 0, resumedAt: 1)

            XCTAssertTrue(recordedScreens.isEmpty)
        }

        /// The host's class name describes the SwiftUI view tree, not a screen — putting
        /// `UIHostingController<ModifiedContent<…>>` in the timeline is never the right answer.
        /// The fixture blocks nothing, standing in for the config flag that captures hosts being
        /// turned on: even then the timeline must refuse them.
        func testAnonymousHostingControllersAreSkippedEvenWhenNotBlocked() {
            appear(UIHostingController(rootView: Text("hi")), startedAt: 0, resumedAt: 1)

            XCTAssertTrue(recordedScreens.isEmpty)
        }

        /// Naming a host is the developer saying it is a screen, so it is kept.
        func testANamedHostingControllerIsTracked() {
            appear(NamedHostingController(rootView: Text("hi")), startedAt: 0, resumedAt: 1)

            XCTAssertEqual(recordedScreens, ["CustomName"])
        }

        /// A developer-authored subclass names itself perfectly well, so the exclusion must not
        /// catch it. `EmbraceIdentifiableHostingController` is conformed by every subclass, so a
        /// type-based test would silently drop this — the name is what the rule is about.
        func testAHostingControllerSubclassWithItsOwnNameIsTracked() {
            appear(CheckoutHostingController(rootView: Text("hi")), startedAt: 0, resumedAt: 1)

            XCTAssertEqual(recordedScreens, ["CheckoutHostingController"])
        }

        /// Naming a host is an unconditional opt-in. The generic test must not be applied to the
        /// developer's own string — `<` in a chosen name means nothing to us.
        func testANamedHostIsKeptEvenWhenItsNameContainsAngleBrackets() {
            let vc = NamedHostingController(rootView: Text("hi"))
            vc.nameForViewControllerInEmbrace = "Cart <checkout v2>"

            appear(vc, startedAt: 0, resumedAt: 1)

            XCTAssertEqual(recordedScreens, ["Cart <checkout v2>"])
        }

        /// A generic subclass still produces a name carrying type parameters, so it stays excluded —
        /// the customization protocol is its way in.
        func testAGenericHostSubclassIsStillAnonymous() {
            appear(GenericHostingController(rootView: Text("hi")), startedAt: 0, resumedAt: 1)

            XCTAssertTrue(recordedScreens.isEmpty)
        }

        /// The host is anonymous, not everything inside it.
        ///
        /// Note this is the behaviour *when hosting-controller capture is enabled*: the fixture
        /// blocks nothing, standing in for that config. Under the default block list the parent walk
        /// in `ViewControllerBlockList` excludes this child before the filter here is ever consulted.
        func testAChildControllerInsideAHostIsStillTracked() {
            let host = UIHostingController(rootView: Text("hi"))
            let child = PlainViewController()
            host.addChild(child)

            appear(child, startedAt: 0, resumedAt: 1)

            XCTAssertEqual(recordedScreens, ["PlainViewController"])
        }

        func testControllersOptedOutOfCaptureAreSkipped() {
            let vc = NamedViewController()
            vc.shouldCaptureViewInEmbrace = false

            appear(vc, startedAt: 0, resumedAt: 1)

            // The same opt-out the view instrumentation honours, so a controller a customer has
            // already excluded stays out of both streams.
            XCTAssertTrue(recordedScreens.isEmpty)
        }

        func testADisappearanceIsForwardedEvenWhenTheControllerBecomesBlocked() throws {

            let first = PlainViewController()
            appear(first, startedAt: 0, resumedAt: 1)

            // A remote-config refresh lands mid-visit and blocks this controller's class.
            block(names: ["PlainViewController"])
            service.onViewControllerAppearance(first, phase: .didDisappear, at: time(2))
            block()

            // If the disappearance had been filtered out, `first` would still be counted visible and
            // this load would not be backdated to its start.
            let second = NamedViewController()
            appear(second, startedAt: 3, resumedAt: 8)

            let span = try XCTUnwrap(stateSpan)
            let load = try XCTUnwrap(span.events.last)
            XCTAssertEqual(load.timestamp, time(3), "backdating must survive a mid-visit filter change")
        }

        // MARK: - Naming

        func testTheCustomisedNameWins() {
            appear(NamedViewController(), startedAt: 0, resumedAt: 1)

            XCTAssertEqual(recordedScreens, ["CustomName"])
        }

        // MARK: - App state

        func testBackgroundAndForegroundBookendTheTimeline() {
            let vc = PlainViewController()

            appear(vc, startedAt: 0, resumedAt: 1)
            handler.appWillBackground(at: time(10))
            handler.appDidForeground(at: time(20))

            // UIKit does not re-fire appearance callbacks for the controller that stayed visible,
            // so without the foreground restore the state would sit on "Backgrounded".
            XCTAssertEqual(recordedScreens, ["PlainViewController", "Backgrounded", "PlainViewController"])
        }

        func testTheBackgroundedSentinelIsTheContractString() {
            appear(PlainViewController(), startedAt: 0, resumedAt: 1)
            handler.appWillBackground(at: time(10))

            XCTAssertEqual(recordedScreens.last, Screen.backgrounded.name)
        }

        // MARK: - Screens declared in SwiftUI

        /// Stands in for the `@State` token the view modifier holds. Only its identity matters.
        private final class Token {}

        private func declare(_ token: Token, name: String, at offset: TimeInterval) {
            handler.manualScreenAppeared(id: ObjectIdentifier(token), name: name, attributes: [:], at: time(offset))
        }

        /// One timeline, one span — a declared screen is not a second, parallel stream.
        func testDeclaredAndAutomaticScreensShareOneTimeline() {
            appear(PlainViewController(), startedAt: 0, resumedAt: 1)
            declare(Token(), name: "Settings", at: 2)

            XCTAssertEqual(recordedScreens, ["PlainViewController", "Settings"])
            XCTAssertEqual(
                mockOTel.startedSpans.filter { $0.name == "emb-state-screen-automatic" }.count, 1)
        }

        /// The reason the modifier reports `onDisappear` at all: a declared screen that never
        /// reported going away would stay counted as visible and silently stop the *next* screen's
        /// load time from being backdated.
        func testADeclaredScreenDisappearingFreesTheVisibleSlot() throws {
            let token = Token()

            declare(token, name: "Settings", at: 0)
            handler.manualScreenDisappeared(id: ObjectIdentifier(token), at: time(1))

            appear(PlainViewController(), startedAt: 2, resumedAt: 9)

            let load = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
            XCTAssertEqual(load.timestamp, time(2), "the next screen must still backdate to its start")
        }

        /// Without a disappearance the overlap rule takes over, which is the behaviour a developer
        /// gets for a sheet presented over a screen that stays visible underneath.
        func testADeclaredScreenLeftVisibleSuppressesBackdating() throws {
            declare(Token(), name: "Settings", at: 0)
            appear(PlainViewController(), startedAt: 2, resumedAt: 9)

            let load = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
            XCTAssertEqual(load.timestamp, time(9), "two screens visible means no backdating")
        }

        /// A screen may be called whatever the app calls it, and the value type is what tells it
        /// apart from the SDK's own. Driven through a full background cycle because that is where
        /// the collision bites: three transitions that all spell "Backgrounded".
        func testAScreenDeclaredWithASentinelsNameIsRecordedAndKeptDistinct() throws {
            appear(PlainViewController(), startedAt: 0, resumedAt: 1)
            declare(Token(), name: Screen.backgrounded.name, at: 5)
            handler.appWillBackground(at: time(10))
            handler.appDidForeground(at: time(20))

            XCTAssertEqual(
                recordedScreens,
                ["PlainViewController", "Backgrounded", "Backgrounded", "Backgrounded"],
                "the declaration, the real backgrounding and the user's return all survive")
            XCTAssertEqual(
                recordedValueTypes, [nil, nil, "system", nil],
                "only the SDK's own backgrounding is a system value")

            let sentinel = try XCTUnwrap(
                stateSpan?.events.first {
                    $0.attributes[SpanSemantics.State.keyValueType]?.description == "system"
                })
            XCTAssertEqual(
                sentinel.timestamp, time(10),
                "the system value is the real backgrounding, not the screen it shares a name with")
        }

        /// The same collision against the state's default value, which is on the span as
        /// `initial_value` before any screen appears.
        func testAScreenDeclaredAsInitializingIsRecordedAlongsideTheDefault() throws {
            declare(Token(), name: Screen.initializing.name, at: 0)
            appear(PlainViewController(), startedAt: 1, resumedAt: 2)

            XCTAssertEqual(recordedScreens, ["Initializing", "PlainViewController"])
            XCTAssertEqual(recordedValueTypes, [nil, nil])
            XCTAssertEqual(
                stateSpan?.attributes[SpanSemantics.State.keyValueType]?.description, "system",
                "the span's initial value is the SDK's, so it is typed even though the screen is not")
        }

        // MARK: - Bounding caller attributes

        // MARK: - Bounding the screen name

        /// The automatic path is exposed to the same unbounded input through the public
        /// `EmbraceViewControllerCustomization`, so it gets the same treatment.
        func testACustomViewControllerNameIsAlsoNormalized() {
            let vc = NamedViewController()
            vc.nameForViewControllerInEmbrace = "  Checkout\n"

            appear(vc, startedAt: 0, resumedAt: 1)

            XCTAssertEqual(recordedScreens, ["Checkout"])
        }

        /// `nameForViewControllerInEmbrace` returning `""` is not "no name": it is non-nil, so the
        /// class-name fallback never runs and a blank would otherwise be stamped on every log until
        /// the user navigated away.
        func testAViewControllerResolvingToABlankNameIsRefused() {
            let blank = NamedViewController()
            blank.nameForViewControllerInEmbrace = "   "

            appear(blank, startedAt: 0, resumedAt: 1)
            appear(PlainViewController(), startedAt: 2, resumedAt: 3)

            XCTAssertEqual(recordedScreens, ["PlainViewController"])
        }

        /// The automatic path meets the same collision: a view controller class can be named after
        /// a sentinel, and `nameForViewControllerInEmbrace` is public API that can return one.
        func testAViewControllerNamedAfterASentinelIsRecorded() {
            appear(Initializing(), startedAt: 0, resumedAt: 1)
            appear(PlainViewController(), startedAt: 2, resumedAt: 3)

            XCTAssertEqual(recordedScreens, ["Initializing", "PlainViewController"])
            XCTAssertEqual(recordedValueTypes, [nil, nil], "a class name is never a system value")
        }

        /// The severe case: this screen shares its name with the real backgrounding, and the whole
        /// background/foreground cycle has to survive beside it.
        func testACustomNameMatchingTheSentinelIsKeptDistinctFromIt() {
            let vc = NamedViewController()
            vc.nameForViewControllerInEmbrace = "Backgrounded"

            appear(PlainViewController(), startedAt: 0, resumedAt: 1)
            appear(vc, startedAt: 2, resumedAt: 3)
            handler.appWillBackground(at: time(10))
            handler.appDidForeground(at: time(20))

            XCTAssertEqual(
                recordedScreens,
                ["PlainViewController", "Backgrounded", "Backgrounded", "Backgrounded"],
                "the real background/foreground cycle survives beside the colliding screen name")
            XCTAssertEqual(recordedValueTypes, [nil, nil, "system", nil])
        }

    }

#endif
