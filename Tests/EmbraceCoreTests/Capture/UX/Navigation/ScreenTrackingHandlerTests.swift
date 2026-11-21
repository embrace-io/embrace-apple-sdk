//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

/// The specification for how screen lifecycle callbacks become a screen timeline. Each test is an
/// edge case the handler exists to get right, so a change that breaks one is a behavioural change
/// to the feature and needs to be deliberate.
///
/// The handler takes plain values, so none of this needs UIKit or a running app. Assertions read
/// the transitions its recorder writes to the state span.
final class ScreenTrackingHandlerTests: XCTestCase {

    /// Stands in for a view controller. Only its identity matters.
    private final class Container {}

    private var mockOTel: MockOTelSignalsHandler!
    private var handler: ScreenTrackingHandler!

    private let origin = Date(timeIntervalSince1970: 1_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockOTel = MockOTelSignalsHandler()
        handler = ScreenTrackingHandler(otel: mockOTel)

        let sessionSpan = try mockOTel.createInternalSpan(
            name: SpanSemantics.Session.name,
            type: .session,
            startTime: origin
        )
        handler.recorder.onSessionPartStart(sessionSpan: sessionSpan, at: origin)
    }

    override func tearDownWithError() throws {
        handler = nil
        mockOTel = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func time(_ offset: TimeInterval) -> Date {
        origin.addingTimeInterval(offset)
    }

    private func id(_ container: Container) -> ObjectIdentifier {
        ObjectIdentifier(container)
    }

    private var stateSpan: EmbraceSpan? {
        mockOTel.startedSpans.first { $0.name == SpanSemantics.State.spanName(for: ScreenTrackingHandler.stateName) }
    }

    /// The transitions recorded, in the order they were recorded — not sorted by time, since a
    /// backdated load can be earlier than the one before it. Attributes are only the caller's own.
    private var loads: [(time: Date, name: String, isSystemValue: Bool, attributes: EmbraceAttributes)] {
        (stateSpan?.events ?? []).map { event in
            (
                event.timestamp,
                event.attributes[SpanSemantics.State.keyNewValue]?.description ?? "",
                event.attributes[SpanSemantics.State.keyValueType]?.description == SpanSemantics.State.valueTypeSystem,
                event.attributes.filter { !SpanSemantics.State.isReserved($0.key) }
            )
        }
    }

    private var names: [String] {
        loads.map(\.name)
    }

    /// Whether each emission is one of the SDK's own values rather than an app screen.
    private var systemValues: [Bool] {
        loads.map(\.isSystemValue)
    }

    /// Drives a full appear cycle for one container.
    private func appear(_ container: Container, named name: String, startedAt: TimeInterval, resumedAt: TimeInterval) {
        handler.screenWillAppear(id(container), name: name, at: time(startedAt))
        handler.screenDidAppear(id(container), name: name, at: time(resumedAt))
    }

    // MARK: - Emission basics

    func testResumeEmitsTheScreen() {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)

        XCTAssertEqual(names, ["Home"])
    }

    func testStartAloneEmitsNothing() {
        let vc = Container()

        handler.screenWillAppear(id(vc), name: "Home", at: time(0))

        // A container that begins appearing but never finishes has no load to attribute.
        XCTAssertTrue(loads.isEmpty)
    }

    func testResumeWithoutAMatchingStartIsIgnored() {
        let vc = Container()

        handler.screenDidAppear(id(vc), name: "Home", at: time(1))

        // A resume is only meaningful relative to a start; without one there is no load to attribute.
        XCTAssertTrue(loads.isEmpty)
    }

    // MARK: - Load-time attribution

    func testLoadTimeIsBackdatedToTheStartTime() throws {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 5)

        // Navigation began when the window started becoming visible, not when it finished.
        let load = try XCTUnwrap(loads.first)
        XCTAssertEqual(load.time, time(0))
    }

    func testLoadTimeFallsBackToEventTimeWhenMoreThanOneScreenIsVisible() throws {
        let first = Container()
        let second = Container()

        appear(first, named: "Home", startedAt: 0, resumedAt: 1)
        // `first` is still visible — never paused — so this resume sees two visible screens.
        appear(second, named: "Detail", startedAt: 2, resumedAt: 6)

        XCTAssertEqual(names, ["Home", "Detail"])
        XCTAssertEqual(loads[0].time, time(0), "single visible screen backdates")
        XCTAssertEqual(loads[1].time, time(6), "overlapping transition uses the event time")
    }

    func testLoadTimeBackdatesAgainOnceTheOverlapResolves() throws {
        let first = Container()
        let second = Container()

        appear(first, named: "Home", startedAt: 0, resumedAt: 1)
        handler.screenDidDisappear(id(first), at: time(2))
        appear(second, named: "Detail", startedAt: 3, resumedAt: 8)

        XCTAssertEqual(loads[1].time, time(3))
    }

    func testARepeatedStartKeepsTheEarliestTime() throws {
        let vc = Container()

        // One appearance, reported twice: a swizzled subclass reports, runs its own
        // `viewWillAppear` body, then calls `super`, which reports again later.
        handler.screenWillAppear(id(vc), name: "Home", at: time(0))
        handler.screenWillAppear(id(vc), name: "Home", at: time(4))
        handler.screenDidAppear(id(vc), name: "Home", at: time(5))

        // Backdating must reach the first report. Taking the later one would silently exclude the
        // subclass's own work — precisely what the load time exists to measure.
        let load = try XCTUnwrap(loads.first)
        XCTAssertEqual(load.time, time(0))
    }

    func testAPauseLetsTheNextAppearanceStartFresh() throws {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        handler.screenDidDisappear(id(vc), at: time(2))

        // Keeping the earliest start must not mean keeping a *stale* one across visits.
        handler.screenWillAppear(id(vc), name: "Detail", at: time(10))
        handler.screenDidAppear(id(vc), name: "Detail", at: time(11))

        XCTAssertEqual(loads.last?.time, time(10))
    }

    // MARK: - The dedup gate

    func testDuplicateEventsForTheSameContainerAndNameAreDropped() {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        appear(vc, named: "Home", startedAt: 2, resumedAt: 3)

        // Same container, same name: a replayed callback, not a navigation.
        XCTAssertEqual(names, ["Home"])
    }

    func testSameContainerWithADifferentNamePassesTheGate() {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        appear(vc, named: "Detail", startedAt: 2, resumedAt: 3)

        XCTAssertEqual(names, ["Home", "Detail"])
    }

    func testDifferentContainersWithTheSameNamePassTheGate() throws {
        let first = Container()
        let second = Container()

        appear(first, named: "Home", startedAt: 0, resumedAt: 1)
        handler.screenDidDisappear(id(first), at: time(2))
        appear(second, named: "Home", startedAt: 3, resumedAt: 4)
        handler.recorder.onSessionPartWillEnd(at: time(60))

        // The gate fires because the container differs; the recorder's *value* dedup is what then
        // collapses it into a dropped transition. Stopped at the gate, nothing would be counted.
        XCTAssertEqual(names, ["Home"])
        let span = try XCTUnwrap(stateSpan)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyDroppedByInstrumentation]?.description, "1")
    }

    func testReturningToAPreviousScreenEmitsAgain() {
        let home = Container()
        let detail = Container()

        appear(home, named: "Home", startedAt: 0, resumedAt: 1)
        appear(detail, named: "Detail", startedAt: 2, resumedAt: 3)
        handler.screenDidDisappear(id(detail), at: time(4))
        appear(home, named: "Home", startedAt: 5, resumedAt: 6)

        XCTAssertEqual(names, ["Home", "Detail", "Home"])
    }

    // MARK: - Pause bookkeeping

    func testPauseEmitsNothing() {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        handler.screenDidDisappear(id(vc), at: time(2))

        XCTAssertEqual(names, ["Home"])
    }

    func testPauseClearsAPendingStartTime() {
        let vc = Container()

        handler.screenWillAppear(id(vc), name: "Home", at: time(0))
        handler.screenDidDisappear(id(vc), at: time(1))
        handler.screenDidAppear(id(vc), name: "Home", at: time(2))

        // Deliberate: `ObjectIdentifier` is an address, so a start time left behind by a
        // deallocated controller could be picked up by an unrelated one allocated at the same
        // address and silently backdate its load.
        XCTAssertTrue(loads.isEmpty)
    }

    // MARK: - Backgrounding

    func testBackgroundEmitsTheSentinelAtTheEventTime() throws {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        handler.appWillBackground(at: time(10))

        XCTAssertEqual(names, ["Home", "Backgrounded"])
        // Backgrounding bypasses the load-time calculation entirely.
        XCTAssertEqual(loads[1].time, time(10))
    }

    func testBackgroundIsNotBackdatedEvenWithAPendingStart() {
        let vc = Container()
        let other = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        handler.screenWillAppear(id(other), name: "Detail", at: time(2))
        handler.appWillBackground(at: time(10))

        XCTAssertEqual(loads[1].time, time(10))
    }

    // MARK: - Foregrounding

    func testForegroundRestoresTheScreenThatWasVisibleBeforeBackgrounding() throws {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        handler.appWillBackground(at: time(10))
        handler.appDidForeground(at: time(20))

        // UIKit does not re-fire appearance callbacks for the still-visible controller, so without
        // this the state would sit on "Backgrounded" until the user navigated.
        XCTAssertEqual(names, ["Home", "Backgrounded", "Home"])
        XCTAssertEqual(loads[2].time, time(20), "no new start time exists to backdate to")
    }

    func testForegroundWithoutAPriorBackgroundEmitsNothing() {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        handler.appDidForeground(at: time(5))

        XCTAssertEqual(names, ["Home"])
    }

    func testForegroundBeforeAnyScreenEmitsNothing() {
        handler.appWillBackground(at: time(1))
        handler.appDidForeground(at: time(2))

        // Nothing was ever on screen, so there is nothing to restore.
        XCTAssertEqual(names, ["Backgrounded"])
    }

    func testRepeatedBackgroundDoesNotMakeTheSentinelRestorable() {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        handler.appWillBackground(at: time(10))
        // The gate drops this one, but it must not overwrite what we remembered either.
        handler.appWillBackground(at: time(11))
        handler.appDidForeground(at: time(20))

        XCTAssertEqual(names, ["Home", "Backgrounded", "Home"])
    }

    func testForegroundIsConsumedOnce() {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        handler.appWillBackground(at: time(10))
        handler.appDidForeground(at: time(20))
        handler.appDidForeground(at: time(21))

        XCTAssertEqual(names, ["Home", "Backgrounded", "Home"])
    }

    func testNavigatingAfterAForegroundRestoreStillEmits() {
        let home = Container()
        let detail = Container()

        appear(home, named: "Home", startedAt: 0, resumedAt: 1)
        handler.appWillBackground(at: time(10))
        handler.appDidForeground(at: time(20))
        handler.screenDidDisappear(id(home), at: time(21))
        appear(detail, named: "Detail", startedAt: 22, resumedAt: 23)

        XCTAssertEqual(names, ["Home", "Backgrounded", "Home", "Detail"])
    }

    func testAScreenPausedWhileBackgroundedIsNotRestored() {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        handler.appWillBackground(at: time(10))

        // The controller is torn down while the app is in the background.
        handler.screenDidDisappear(id(vc), at: time(11))
        handler.appDidForeground(at: time(20))

        // Restoring it would claim the user is on a screen that no longer exists, and would hold a
        // dead `ObjectIdentifier` that a later controller can be allocated into.
        XCTAssertEqual(names, ["Home", "Backgrounded"])
    }

    // MARK: - Threading

    func testAnEventArrivingOffTheMainThreadIsDroppedRatherThanTrapping() {
        let vc = Container()
        let done = expectation(description: "off-main handle returns")

        DispatchQueue.global().async { [self] in
            // The handler's state is unsynchronized, so this must not be processed — but it must
            // also not terminate the host app. A `dispatchPrecondition` here would trap in every
            // optimisation level, including `-Ounchecked`, on a swizzle attached to every
            // UIViewController in the customer's app.
            handler.screenWillAppear(id(vc), name: "Home", at: time(0))
            done.fulfill()
        }

        wait(for: [done], timeout: 5)

        // Dropped, so the matching resume on main has no start time and emits nothing.
        handler.screenDidAppear(id(vc), name: "Home", at: time(1))
        XCTAssertTrue(loads.isEmpty)
    }

    /// Runs `call` on a background queue and checks it recorded nothing. Each caller first sets up a
    /// state in which the call *would* record a transition if it were processed.
    private func assertDroppedOffMain(_ call: @escaping () -> Void, line: UInt = #line) {
        let before = names
        let done = expectation(description: "off-main call returns")
        DispatchQueue.global().async {
            call()
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(names, before, line: line)
    }

    func testAnOffMainResumeIsDropped() {
        let vc = Container()
        handler.screenWillAppear(id(vc), name: "Home", at: time(0))

        assertDroppedOffMain { [self] in handler.screenDidAppear(id(vc), name: "Home", at: time(1)) }
    }

    func testAnOffMainPauseIsDropped() {
        let home = Container()
        let sheet = Container()
        appear(home, named: "Home", startedAt: 0, resumedAt: 1)
        appear(sheet, named: "Sheet", startedAt: 2, resumedAt: 3)

        // Processed, this would reveal Home.
        assertDroppedOffMain { [self] in handler.screenDidDisappear(id(sheet), at: time(4)) }
    }

    func testAnOffMainDeclaredScreenIsDropped() {
        let token = Container()
        assertDroppedOffMain { [self] in
            handler.manualScreenAppeared(id: id(token), name: "Settings", attributes: [:], at: time(0))
        }
    }

    func testAnOffMainBackgroundingIsDropped() {
        appear(Container(), named: "Home", startedAt: 0, resumedAt: 1)

        assertDroppedOffMain { [self] in handler.appWillBackground(at: time(2)) }
    }

    func testAnOffMainForegroundingIsDropped() {
        appear(Container(), named: "Home", startedAt: 0, resumedAt: 1)
        handler.appWillBackground(at: time(2))

        // Processed, this would restore Home.
        assertDroppedOffMain { [self] in handler.appDidForeground(at: time(3)) }
    }

    // MARK: - Interleaving

    func testInterleavedStartsAndResumesAttributeToTheRightContainer() {
        let first = Container()
        let second = Container()

        handler.screenWillAppear(id(first), name: "Home", at: time(0))
        handler.screenWillAppear(id(second), name: "Detail", at: time(1))
        handler.screenDidAppear(id(second), name: "Detail", at: time(2))
        handler.screenDidDisappear(id(second), at: time(3))
        handler.screenDidAppear(id(first), name: "Home", at: time(4))

        XCTAssertEqual(names, ["Detail", "Home"])
        XCTAssertEqual(loads[0].time, time(1), "Detail backdates to its own start")
        XCTAssertEqual(loads[1].time, time(0), "Home backdates to its own start")
    }

    // MARK: - Caller attributes

    /// Attributes travel with the screen they were declared on, and only that one.
    func testAttributesAreCarriedThroughToTheEmission() throws {
        let vc = Container()

        handler.screenWillAppear(id(vc), name: "ProductDetail", at: time(0))
        handler.screenDidAppear(id(vc), name: "ProductDetail", attributes: ["product_id": "42"], at: time(1))

        let emitted = try XCTUnwrap(loads.first)
        XCTAssertEqual(emitted.attributes["product_id"]?.description, "42")
    }

    func testAutomaticScreensCarryNoAttributes() throws {
        let vc = Container()

        handler.screenWillAppear(id(vc), name: "Home", at: time(0))
        handler.screenDidAppear(id(vc), name: "Home", at: time(1))

        XCTAssertTrue(try XCTUnwrap(loads.first).attributes.isEmpty)
    }

    /// The dedup gate is `(container, screen)`. A view re-appearing with changed metadata is still
    /// the screen the user is already on, so it must not record a second transition — otherwise any
    /// screen whose attributes track live data would emit on every re-appearance.
    func testAChangedAttributeAloneDoesNotPassTheDedupGate() {
        let vc = Container()

        handler.screenWillAppear(id(vc), name: "Cart", at: time(0))
        handler.screenDidAppear(id(vc), name: "Cart", attributes: ["total": "10"], at: time(1))
        handler.screenWillAppear(id(vc), name: "Cart", at: time(2))
        handler.screenDidAppear(id(vc), name: "Cart", attributes: ["total": "20"], at: time(3))

        XCTAssertEqual(names, ["Cart"], "an attribute change is not a navigation")
    }

    /// A restore replays the screen the user was on, so it has to replay what that screen was
    /// declared with too — a restored transition stripped of its metadata would not match the
    /// original one it is standing in for.
    func testForegroundRestoreReplaysTheAttributes() throws {
        let vc = Container()

        handler.screenWillAppear(id(vc), name: "ProductDetail", at: time(0))
        handler.screenDidAppear(id(vc), name: "ProductDetail", attributes: ["product_id": "42"], at: time(1))
        handler.appWillBackground(at: time(2))
        handler.appDidForeground(at: time(3))

        XCTAssertEqual(names, ["ProductDetail", "Backgrounded", "ProductDetail"])
        XCTAssertEqual(loads[2].attributes["product_id"]?.description, "42")
    }

    /// Pins the choice documented on `Emission.attributes`: a re-declaration the dedup gate
    /// suppressed still updates what a later restore replays. Without this, the `defer` in `emit`
    /// looks like an accident and someone will "fix" it.
    func testRestoreReplaysTheMostRecentDeclarationEvenIfItWasSuppressed() throws {
        let vc = Container()

        handler.screenWillAppear(id(vc), name: "Cart", at: time(0))
        handler.screenDidAppear(id(vc), name: "Cart", attributes: ["total": "10"], at: time(1))
        // Same screen, fresher metadata — suppressed by the gate, emits nothing.
        handler.screenWillAppear(id(vc), name: "Cart", at: time(2))
        handler.screenDidAppear(id(vc), name: "Cart", attributes: ["total": "20"], at: time(3))
        handler.appWillBackground(at: time(4))
        handler.appDidForeground(at: time(5))

        XCTAssertEqual(names, ["Cart", "Backgrounded", "Cart"])
        XCTAssertEqual(
            loads[2].attributes["total"]?.description, "20",
            "the restore describes the screen as it stands now, not as it last shipped")
    }

    func testTheBackgroundedSentinelCarriesNoAttributes() throws {
        let vc = Container()

        handler.screenWillAppear(id(vc), name: "ProductDetail", at: time(0))
        handler.screenDidAppear(id(vc), name: "ProductDetail", attributes: ["product_id": "42"], at: time(1))
        handler.appWillBackground(at: time(2))

        XCTAssertEqual(loads[1].name, "Backgrounded")
        XCTAssertTrue(loads[1].attributes.isEmpty, "the sentinel is not the declared screen")
    }

    /// The handler records whole screens, not names, so a screen the app calls
    /// "Backgrounded" and the sentinel of that name arrive as the two different values they are.
    /// Without the type the state primitive would dedupe the second against the first.
    func testTheSentinelIsTypedAndAppScreensAreNot() {
        let vc = Container()

        appear(vc, named: "Backgrounded", startedAt: 0, resumedAt: 1)
        handler.appWillBackground(at: time(2))

        XCTAssertEqual(names, ["Backgrounded", "Backgrounded"])
        XCTAssertEqual(systemValues, [false, true])
    }

    // MARK: - The background boundary

    /// Backgrounding clears pending start times, so an address reused by a later object cannot
    /// inherit a dead screen's timestamp.
    func testBackgroundingClearsAPendingStartTime() throws {
        let vc = Container()
        handler.screenWillAppear(id(vc), name: "Pending", at: time(0))

        handler.appWillBackground(at: time(5))
        handler.appDidForeground(at: time(6))

        // Same id, appearing for real now: it must not backdate to the pre-background start.
        handler.screenWillAppear(id(vc), name: "Pending", at: time(10))
        handler.screenDidAppear(id(vc), name: "Pending", at: time(11))

        XCTAssertEqual(try XCTUnwrap(loads.last).time, time(10))
    }

    // MARK: - Uncovering a screen underneath

    /// A sheet does not cover what it sits on, so the screen beneath stays visible and is never
    /// re-declared on dismissal. Without this the timeline sits on the dismissed sheet.
    func testDismissingASheetReturnsToTheScreenBeneathIt() throws {
        let home = Container()
        let sheet = Container()

        handler.screenWillAppear(id(home), name: "Home", at: time(0))
        handler.screenDidAppear(id(home), name: "Home", at: time(1))
        handler.screenWillAppear(id(sheet), name: "Sheet", at: time(5))
        handler.screenDidAppear(id(sheet), name: "Sheet", at: time(6))
        handler.screenDidDisappear(id(sheet), at: time(10))

        XCTAssertEqual(names, ["Home", "Sheet", "Home"])
        XCTAssertEqual(loads.last?.time, time(10), "the reveal is timed at the dismissal")
    }

    /// Backgrounding empties the visible set and nothing re-reports the restored screen, so the
    /// restore itself has to put it back — or a sheet dismissed over it has nothing to reveal.
    func testDismissingASheetAfterAForegroundReturnsToTheRestoredScreen() throws {
        let home = Container()
        let sheet = Container()

        handler.screenWillAppear(id(home), name: "Home", at: time(0))
        handler.screenDidAppear(id(home), name: "Home", attributes: ["tier": "gold"], at: time(1))
        handler.appWillBackground(at: time(10))
        handler.appDidForeground(at: time(20))
        handler.screenWillAppear(id(sheet), name: "Sheet", at: time(25))
        handler.screenDidAppear(id(sheet), name: "Sheet", at: time(26))
        handler.screenDidDisappear(id(sheet), at: time(30))

        XCTAssertEqual(names, ["Home", "Backgrounded", "Home", "Sheet", "Home"])
        XCTAssertEqual(loads.last?.time, time(30), "the reveal is timed at the dismissal")
        XCTAssertEqual(loads.last?.attributes["tier"]?.description, "gold")
    }

    /// Two screens stacked over a third go away together. Whichever disappearance arrives last, the
    /// timeline ends on the screen left underneath.
    private func assertUnwindingRevealsTheBase(topFirst: Bool, line: UInt = #line) {
        let base = Container()
        let middle = Container()
        let top = Container()

        appear(base, named: "Base", startedAt: 0, resumedAt: 1)
        appear(middle, named: "Middle", startedAt: 2, resumedAt: 3)
        appear(top, named: "Top", startedAt: 4, resumedAt: 5)

        let order = topFirst ? [top, middle] : [middle, top]
        handler.screenDidDisappear(id(order[0]), at: time(10))
        handler.screenDidDisappear(id(order[1]), at: time(11))

        XCTAssertEqual(names, ["Base", "Middle", "Top", "Base"], line: line)
        XCTAssertEqual(loads.last?.time, time(11), line: line)
    }

    func testUnwindingAStackTopFirstRevealsTheScreenLeft() {
        assertUnwindingRevealsTheBase(topFirst: true)
    }

    func testUnwindingAStackBottomFirstRevealsTheScreenLeft() {
        assertUnwindingRevealsTheBase(topFirst: false)
    }

    /// A sheet still open when the app backgrounds: after the foreground, dismissing it must hand the
    /// timeline back to the screen that was underneath it the whole time.
    func testDismissingASheetOpenAcrossABackgroundReturnsToTheScreenUnderIt() throws {
        let home = Container()
        let sheet = Container()

        handler.screenWillAppear(id(home), name: "Home", at: time(0))
        handler.screenDidAppear(id(home), name: "Home", attributes: ["tier": "gold"], at: time(1))
        handler.screenWillAppear(id(sheet), name: "Sheet", at: time(2))
        handler.screenDidAppear(id(sheet), name: "Sheet", at: time(3))
        handler.appWillBackground(at: time(10))
        handler.appDidForeground(at: time(20))
        handler.screenDidDisappear(id(sheet), at: time(30))

        XCTAssertEqual(names, ["Home", "Sheet", "Backgrounded", "Sheet", "Home"])
        XCTAssertEqual(loads.last?.time, time(30))
        XCTAssertEqual(loads.last?.attributes["tier"]?.description, "gold")
    }

    /// A screen that goes away while the app is backgrounded is not brought back with the rest.
    func testAScreenGoneWhileBackgroundedIsNotRestored() throws {
        let home = Container()
        let sheet = Container()

        handler.screenWillAppear(id(home), name: "Home", at: time(0))
        handler.screenDidAppear(id(home), name: "Home", at: time(1))
        handler.screenWillAppear(id(sheet), name: "Sheet", at: time(2))
        handler.screenDidAppear(id(sheet), name: "Sheet", at: time(3))
        handler.appWillBackground(at: time(10))
        handler.screenDidDisappear(id(home), at: time(11))
        handler.appDidForeground(at: time(20))

        // Only the sheet came back, so its dismissal has nothing to reveal.
        handler.screenDidDisappear(id(sheet), at: time(30))

        XCTAssertEqual(names, ["Home", "Sheet", "Backgrounded", "Sheet"])
    }

    /// The revealed screen keeps the metadata it was declared with.
    func testARevealedScreenKeepsItsAttributes() throws {
        let home = Container()
        let sheet = Container()

        handler.screenWillAppear(id(home), name: "Home", at: time(0))
        handler.screenDidAppear(id(home), name: "Home", attributes: ["tier": "gold"], at: time(1))
        handler.screenWillAppear(id(sheet), name: "Sheet", at: time(5))
        handler.screenDidAppear(id(sheet), name: "Sheet", at: time(6))
        handler.screenDidDisappear(id(sheet), at: time(10))

        XCTAssertEqual(loads.last?.attributes["tier"]?.description, "gold")
    }

    /// A full-screen presentation *does* pause the presenter, so it leaves the visible set and its
    /// own resume emits it. The reveal must not also fire, or the screen appears twice.
    func testDismissingAFullScreenPresentationDoesNotDoubleEmit() {
        let home = Container()
        let modal = Container()

        handler.screenWillAppear(id(home), name: "Home", at: time(0))
        handler.screenDidAppear(id(home), name: "Home", at: time(1))
        handler.screenWillAppear(id(modal), name: "Modal", at: time(5))
        handler.screenDidAppear(id(modal), name: "Modal", at: time(6))
        handler.screenDidDisappear(id(home), at: time(7))

        // Dismissal: the modal pauses and Home re-appears for real.
        handler.screenWillAppear(id(home), name: "Home", at: time(10))
        handler.screenDidAppear(id(home), name: "Home", at: time(11))
        handler.screenDidDisappear(id(modal), at: time(12))

        XCTAssertEqual(names, ["Home", "Modal", "Home"], "Home must appear once on the way back")
    }

    func testPausingWithNothingUnderneathEmitsNothing() {
        let only = Container()
        handler.screenWillAppear(id(only), name: "Only", at: time(0))
        handler.screenDidAppear(id(only), name: "Only", at: time(1))
        handler.screenDidDisappear(id(only), at: time(2))

        XCTAssertEqual(names, ["Only"])
    }

    /// More than one still visible means a transition is in flight and which is frontmost is
    /// ambiguous — the resume that follows will say.
    func testPausingDuringATransitionLeavesTheResumeToEmit() {
        let a = Container()
        let b = Container()
        let c = Container()
        for (vc, name) in [(a, "A"), (b, "B"), (c, "C")] {
            handler.screenWillAppear(id(vc), name: name, at: time(0))
            handler.screenDidAppear(id(vc), name: name, at: time(1))
        }
        handler.screenDidDisappear(id(c), at: time(5))

        XCTAssertEqual(names, ["A", "B", "C"], "no guess while two remain visible")
    }

    /// A pause arriving after the app backgrounded must not hand the timeline back to a screen —
    /// the user is not looking at anything.
    func testAPauseAfterBackgroundingDoesNotReveal() {
        let home = Container()
        let sheet = Container()

        handler.screenWillAppear(id(home), name: "Home", at: time(0))
        handler.screenDidAppear(id(home), name: "Home", at: time(1))
        handler.screenWillAppear(id(sheet), name: "Sheet", at: time(5))
        handler.screenDidAppear(id(sheet), name: "Sheet", at: time(6))

        handler.appWillBackground(at: time(10))
        handler.screenDidDisappear(id(sheet), at: time(11))

        XCTAssertEqual(names, ["Home", "Sheet", "Backgrounded"], "nothing is revealed while backgrounded")
    }

    // MARK: - Recording

    func testStateNameAndCapAreTheContractValues() {
        XCTAssertEqual(ScreenTrackingHandler.stateName, "screen-automatic")
        XCTAssertEqual(ScreenTrackingHandler.maxTransitions, 1000)
        XCTAssertEqual(handler.recorder.maxTransitions, 1000)
    }

    func testTheSpanOpensWithInitializingAsASystemValue() throws {
        // A session in which the user never navigates still reports a screen state.
        let span = try XCTUnwrap(stateSpan)
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyInitialValue]?.description, "Initializing")
        XCTAssertEqual(span.attributes[SpanSemantics.State.keyValueType]?.description, "system")
        XCTAssertEqual(span.type.rawValue, "state")
    }

    func testSentinelsAreTheContractStrings() {
        XCTAssertEqual(Screen.initializing.stateDescription, "Initializing")
        XCTAssertEqual(Screen.backgrounded.stateDescription, "Backgrounded")
    }

    /// Only the SDK's own values are system values. A screen that came from the app is identified by
    /// its name alone, whatever that name happens to be.
    func testOnlyTheSentinelsAreSystemValues() {
        XCTAssertTrue(Screen.initializing.isSystemValue)
        XCTAssertTrue(Screen.backgrounded.isSystemValue)
        XCTAssertFalse(Screen("Home").isSystemValue)
        XCTAssertFalse(Screen("Backgrounded").isSystemValue)
    }

    func testTheCurrentScreenIsExposedForLogStamping() {
        appear(Container(), named: "Home", startedAt: 0, resumedAt: 1)

        XCTAssertEqual(handler.recorder.currentValue?.stateDescription, "Home")
    }

    // MARK: - Screens declared in SwiftUI

    /// Stands in for the `@State` token the view modifier holds. Only its identity matters.
    private final class Token {}

    private func declare(
        _ token: Token,
        name: String,
        attributes: EmbraceAttributes = [:],
        at offset: TimeInterval
    ) {
        handler.manualScreenAppeared(id: ObjectIdentifier(token), name: name, attributes: attributes, at: time(offset))
    }

    func testADeclaredScreenIsRecorded() {
        declare(Token(), name: "Settings", at: 0)

        XCTAssertEqual(names, ["Settings"])
    }

    func testDeclaredAttributesLandOnTheTransitionEvent() throws {
        declare(
            Token(), name: "ProductDetail", attributes: ["product_id": "42"], at: 0)

        let event = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
        XCTAssertEqual(event.attributes["product_id"]?.description, "42")
        XCTAssertEqual(
            event.attributes[SpanSemantics.State.keyNewValue]?.description, "ProductDetail")
    }

    /// The public API cannot forge the framework's own keys, whatever a caller passes.
    ///
    /// Deliberately forges a **counter** key. The counters are omitted from the event when their
    /// count is zero, so nothing overwrites a forged one — they are the keys the
    /// reserved-namespace filter actually protects. Asserting on `emb.state.new_value` instead
    /// would prove nothing, because that key is written after the merge and wins on ordering
    /// alone.
    func testReservedAttributeKeysCannotBeForged() throws {
        declare(
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

    /// Normalization trims first, so a name that is only whitespace arrives here empty. A blank
    /// name is indistinguishable from an absent one downstream and still spends a transition.
    func testAScreenDeclaredWithABlankNameIsRefused() {
        declare(Token(), name: "   ", at: 0)
        declare(Token(), name: "", at: 1)

        XCTAssertTrue(names.isEmpty)
    }

    /// State spans skip the sanitizer (that exemption is what lets a part record far more than
    /// the customer event limit), so the bound has to be applied deliberately — otherwise the
    /// first public API to accept caller attributes ships them unbounded.
    func testCallerAttributesAreCappedInCount() throws {
        var attributes: EmbraceAttributes = [:]
        for i in 0..<40 {
            attributes[String(format: "key-%02d", i)] = "v"
        }
        declare(Token(), name: "Busy", attributes: attributes, at: 0)

        let event = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
        let callerKeys = event.attributes.keys.filter { $0.hasPrefix("key-") }
        XCTAssertEqual(callerKeys.count, 10)
    }

    func testCallerAttributeValuesAreTruncated() throws {
        declare(
            Token(), name: "Long",
            attributes: ["blob": String(repeating: "x", count: 5_000)], at: 0)

        let event = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
        XCTAssertEqual(event.attributes["blob"]?.description.count, 1_024)
    }

    func testCallerAttributeKeysAreTruncated() throws {
        declare(
            Token(), name: "LongKey",
            attributes: [String(repeating: "k", count: 500): "v"], at: 0)

        let event = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
        XCTAssertTrue(event.attributes.keys.contains(String(repeating: "k", count: 128)))
    }

    /// Matches every other public attribute API in the SDK: `DefaultOtelSignalsSanitizer`
    /// preserves the non-`String` cases of `EmbraceAttributeValue`, so the same call recorded on
    /// a breadcrumb and on a screen behaves identically.
    func testNonStringAttributeValuesArePreserved() throws {
        declare(
            Token(), name: "Cart",
            attributes: ["items": 3, "flag": true, "sku": "abc"], at: 0)

        let event = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
        XCTAssertEqual(event.attributes["items"]?.description, "3")
        XCTAssertEqual(event.attributes["flag"]?.description, "true")
        XCTAssertEqual(event.attributes["sku"]?.description, "abc", "strings still get through")
    }

    /// The framework's own keys must never be squeezed out by the caller's cap.
    func testTheContractKeysSurviveAFullCallerBudget() throws {
        var attributes: EmbraceAttributes = [:]
        for i in 0..<40 {
            attributes["aaa-\(i)"] = "v"
        }
        declare(Token(), name: "Busy", attributes: attributes, at: 0)

        let event = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
        XCTAssertEqual(
            event.attributes[SpanSemantics.State.keyNewValue]?.description, "Busy",
            "emb.state.new_value must not compete with caller attributes for the budget")
    }

    /// The name is the one caller string nothing downstream bounds — it ships as an attribute
    /// value on internal spans, which skip sanitization, and is copied onto every log.
    func testALongScreenNameIsTruncated() throws {
        declare(Token(), name: String(repeating: "N", count: 5_000), at: 0)

        XCTAssertEqual(names.first?.count, 128)
    }

    /// Equality downstream is by name, so an untrimmed name invents navigations the user never
    /// made — the exact failure the public doc warns about.
    func testNamesDifferingOnlyByWhitespaceAreOneScreen() {
        declare(Token(), name: "Home", at: 0)
        declare(Token(), name: "Home\n", at: 1)
        declare(Token(), name: "  Home  ", at: 2)

        XCTAssertEqual(names, ["Home"], "one screen, not three")
    }

    /// The public doc promises that past the count limit the survivors are "chosen in sorted key
    /// order". Asserting only how many survive leaves that promise unpinned — the same call
    /// could ship a different subset run to run and nothing would notice.
    func testWhichAttributesSurviveTheCapIsSortedByKey() throws {
        var attributes: EmbraceAttributes = [:]
        for i in 0..<20 {
            attributes[String(format: "k%02d", i)] = "v"
        }
        declare(Token(), name: "Busy", attributes: attributes, at: 0)

        let event = try XCTUnwrap(try XCTUnwrap(stateSpan).events.last)
        let survivors = event.attributes.keys.filter { $0.hasPrefix("k") }.sorted()

        XCTAssertEqual(survivors, (0..<10).map { String(format: "k%02d", $0) })
    }

    // MARK: - Current handler

    /// `current` is process-global, so each test withdraws what it set before returning.
    func testMakingAHandlerCurrentPublishesIt() {
        let current = ScreenTrackingHandler(otel: mockOTel)
        defer { ScreenTrackingHandler.resignCurrent(current) }

        ScreenTrackingHandler.makeCurrent(current)

        XCTAssertTrue(ScreenTrackingHandler.current === current)
    }

    func testResigningWithdrawsTheCurrentHandler() {
        let current = ScreenTrackingHandler(otel: mockOTel)
        ScreenTrackingHandler.makeCurrent(current)

        ScreenTrackingHandler.resignCurrent(current)

        XCTAssertNil(ScreenTrackingHandler.current)
    }

    /// Without the identity check, an owner stopping after another has taken over would leave the
    /// newer handler silently unreachable from the SwiftUI modifier.
    func testAStaleHandlerResigningDoesNotWithdrawANewerOne() {
        let stale = ScreenTrackingHandler(otel: mockOTel)
        let newer = ScreenTrackingHandler(otel: mockOTel)
        defer { ScreenTrackingHandler.resignCurrent(newer) }

        ScreenTrackingHandler.makeCurrent(stale)
        ScreenTrackingHandler.makeCurrent(newer)
        ScreenTrackingHandler.resignCurrent(stale)

        XCTAssertTrue(ScreenTrackingHandler.current === newer)
    }

    /// `current` must never be why a handler stays alive.
    func testTheCurrentHandlerIsNotRetained() {
        weak var weakHandler: ScreenTrackingHandler?

        autoreleasepool {
            let current = ScreenTrackingHandler(otel: mockOTel)
            weakHandler = current
            ScreenTrackingHandler.makeCurrent(current)
        }

        XCTAssertNil(weakHandler)
        XCTAssertNil(ScreenTrackingHandler.current)
    }
}
