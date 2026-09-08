//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

/// The specification for how raw lifecycle events become a screen timeline. Each test is an edge
/// case the broker exists to get right, so a change that breaks one is a behavioural change to the
/// feature and needs to be deliberate.
///
/// The broker takes plain values, so none of this needs UIKit or a running app.
final class NavigationEventBrokerTests: XCTestCase {

    /// Stands in for a view controller. Only its identity matters.
    private final class Container {}

    private var broker: NavigationEventBroker!
    private var loads: [(time: Date, name: String)] = []

    private let origin = Date(timeIntervalSince1970: 1_000)

    override func setUp() {
        super.setUp()
        loads = []
        broker = NavigationEventBroker { [weak self] time, name in
            self?.loads.append((time, name))
        }
    }

    override func tearDown() {
        broker = nil
        loads = []
        super.tearDown()
    }

    // MARK: - Helpers

    private func time(_ offset: TimeInterval) -> Date {
        origin.addingTimeInterval(offset)
    }

    private func id(_ container: Container) -> ObjectIdentifier {
        ObjectIdentifier(container)
    }

    private var names: [String] {
        loads.map(\.name)
    }

    /// Drives a full appear cycle for one container.
    private func appear(_ container: Container, named name: String, startedAt: TimeInterval, resumedAt: TimeInterval) {
        broker.handle(.started(id(container), name: name, at: time(startedAt)))
        broker.handle(.resumed(id(container), name: name, at: time(resumedAt)))
    }

    // MARK: - Emission basics

    func testResumeEmitsTheScreen() {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)

        XCTAssertEqual(names, ["Home"])
    }

    func testStartAloneEmitsNothing() {
        let vc = Container()

        broker.handle(.started(id(vc), name: "Home", at: time(0)))

        // A container that begins appearing but never finishes has no load to attribute.
        XCTAssertTrue(loads.isEmpty)
    }

    func testResumeWithoutAMatchingStartIsIgnored() {
        let vc = Container()

        broker.handle(.resumed(id(vc), name: "Home", at: time(1)))

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
        broker.handle(.paused(id(first), name: "Home", at: time(2)))
        appear(second, named: "Detail", startedAt: 3, resumedAt: 8)

        XCTAssertEqual(loads[1].time, time(3))
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

    func testDifferentContainersWithTheSameNamePassTheGate() {
        let first = Container()
        let second = Container()

        appear(first, named: "Home", startedAt: 0, resumedAt: 1)
        broker.handle(.paused(id(first), name: "Home", at: time(2)))
        appear(second, named: "Home", startedAt: 3, resumedAt: 4)

        // The gate fires because the container differs. The *value* dedup downstream is what
        // collapses this into a dropped transition — see ScreenStateReporterTests.
        XCTAssertEqual(names, ["Home", "Home"])
    }

    func testReturningToAPreviousScreenEmitsAgain() {
        let home = Container()
        let detail = Container()

        appear(home, named: "Home", startedAt: 0, resumedAt: 1)
        appear(detail, named: "Detail", startedAt: 2, resumedAt: 3)
        broker.handle(.paused(id(detail), name: "Detail", at: time(4)))
        appear(home, named: "Home", startedAt: 5, resumedAt: 6)

        XCTAssertEqual(names, ["Home", "Detail", "Home"])
    }

    // MARK: - Pause bookkeeping

    func testPauseEmitsNothing() {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        broker.handle(.paused(id(vc), name: "Home", at: time(2)))

        XCTAssertEqual(names, ["Home"])
    }

    func testPauseClearsAPendingStartTime() {
        let vc = Container()

        broker.handle(.started(id(vc), name: "Home", at: time(0)))
        broker.handle(.paused(id(vc), name: "Home", at: time(1)))
        broker.handle(.resumed(id(vc), name: "Home", at: time(2)))

        // Deliberate: `ObjectIdentifier` is an address, so a start time left behind by a
        // deallocated controller could be picked up by an unrelated one allocated at the same
        // address and silently backdate its load.
        XCTAssertTrue(loads.isEmpty)
    }

    // MARK: - Uncovering a screen underneath

    func testDismissingASheetReturnsToTheScreenBeneathIt() throws {
        let home = Container()
        let sheet = Container()

        appear(home, named: "Home", startedAt: 0, resumedAt: 1)

        // A sheet does not cover what it sits on, so `home` gets no disappear callback and stays
        // visible underneath.
        appear(sheet, named: "Sheet", startedAt: 2, resumedAt: 3)
        broker.handle(.paused(id(sheet), name: "Sheet", at: time(10)))

        XCTAssertEqual(names, ["Home", "Sheet", "Home"])
        XCTAssertEqual(loads.last?.time, time(10), "the revealed screen became current at the dismissal")
    }

    func testDismissingAFullScreenModalDoesNotDoubleEmit() {
        let home = Container()
        let modal = Container()

        appear(home, named: "Home", startedAt: 0, resumedAt: 1)

        // A full-screen presentation *does* pause the presenter, so it leaves the visible set.
        broker.handle(.paused(id(home), name: "Home", at: time(2)))
        appear(modal, named: "Modal", startedAt: 3, resumedAt: 4)

        // Dismissal: the modal pauses, and `home` re-appears for real.
        broker.handle(.paused(id(modal), name: "Modal", at: time(10)))
        appear(home, named: "Home", startedAt: 11, resumedAt: 12)

        // `Home` must appear once here, from its own resume — not once from the reveal and again
        // from the resume.
        XCTAssertEqual(names, ["Home", "Modal", "Home"])
    }

    func testPausingWithNothingUnderneathEmitsNothing() {
        let only = Container()

        appear(only, named: "Only", startedAt: 0, resumedAt: 1)
        broker.handle(.paused(id(only), name: "Only", at: time(2)))

        XCTAssertEqual(names, ["Only"])
    }

    func testPausingDuringATransitionLeavesTheResumeToEmit() {
        let first = Container()
        let second = Container()
        let third = Container()

        appear(first, named: "First", startedAt: 0, resumedAt: 1)
        appear(second, named: "Second", startedAt: 2, resumedAt: 3)

        // Three visible: ambiguous which is frontmost, so a pause must not guess.
        appear(third, named: "Third", startedAt: 4, resumedAt: 5)
        broker.handle(.paused(id(third), name: "Third", at: time(6)))

        XCTAssertEqual(names, ["First", "Second", "Third"])
    }

    // MARK: - Backgrounding

    func testBackgroundEmitsTheSentinelAtTheEventTime() throws {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        broker.handle(.backgrounded(at: time(10)))

        XCTAssertEqual(names, ["Home", "Backgrounded"])
        // Backgrounding bypasses the load-time calculation entirely.
        XCTAssertEqual(loads[1].time, time(10))
    }

    func testBackgroundIsNotBackdatedEvenWithAPendingStart() {
        let vc = Container()
        let other = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        broker.handle(.started(id(other), name: "Detail", at: time(2)))
        broker.handle(.backgrounded(at: time(10)))

        XCTAssertEqual(loads[1].time, time(10))
    }

    // MARK: - Foregrounding

    func testForegroundRestoresTheScreenThatWasVisibleBeforeBackgrounding() throws {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        broker.handle(.backgrounded(at: time(10)))
        broker.handle(.foregrounded(at: time(20)))

        // UIKit does not re-fire appearance callbacks for the still-visible controller, so without
        // this the state would sit on "Backgrounded" until the user navigated.
        XCTAssertEqual(names, ["Home", "Backgrounded", "Home"])
        XCTAssertEqual(loads[2].time, time(20), "no new start time exists to backdate to")
    }

    func testForegroundWithoutAPriorBackgroundEmitsNothing() {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        broker.handle(.foregrounded(at: time(5)))

        XCTAssertEqual(names, ["Home"])
    }

    func testForegroundBeforeAnyScreenEmitsNothing() {
        broker.handle(.backgrounded(at: time(1)))
        broker.handle(.foregrounded(at: time(2)))

        // Nothing was ever on screen, so there is nothing to restore.
        XCTAssertEqual(names, ["Backgrounded"])
    }

    func testRepeatedBackgroundDoesNotMakeTheSentinelRestorable() {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        broker.handle(.backgrounded(at: time(10)))
        // The gate drops this one, but it must not overwrite what we remembered either.
        broker.handle(.backgrounded(at: time(11)))
        broker.handle(.foregrounded(at: time(20)))

        XCTAssertEqual(names, ["Home", "Backgrounded", "Home"])
    }

    func testForegroundIsConsumedOnce() {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        broker.handle(.backgrounded(at: time(10)))
        broker.handle(.foregrounded(at: time(20)))
        broker.handle(.foregrounded(at: time(21)))

        XCTAssertEqual(names, ["Home", "Backgrounded", "Home"])
    }

    func testNavigatingAfterAForegroundRestoreStillEmits() {
        let home = Container()
        let detail = Container()

        appear(home, named: "Home", startedAt: 0, resumedAt: 1)
        broker.handle(.backgrounded(at: time(10)))
        broker.handle(.foregrounded(at: time(20)))
        broker.handle(.paused(id(home), name: "Home", at: time(21)))
        appear(detail, named: "Detail", startedAt: 22, resumedAt: 23)

        XCTAssertEqual(names, ["Home", "Backgrounded", "Home", "Detail"])
    }

    func testAScreenPausedWhileBackgroundedIsNotRestored() {
        let vc = Container()

        appear(vc, named: "Home", startedAt: 0, resumedAt: 1)
        broker.handle(.backgrounded(at: time(10)))

        // The controller is torn down while the app is in the background.
        broker.handle(.paused(id(vc), name: "Home", at: time(11)))
        broker.handle(.foregrounded(at: time(20)))

        // Restoring it would claim the user is on a screen that no longer exists, and would hold a
        // dead `ObjectIdentifier` that a later controller can be allocated into.
        XCTAssertEqual(names, ["Home", "Backgrounded"])
    }

    // MARK: - Threading

    func testAnEventArrivingOffTheMainThreadIsDroppedRatherThanTrapping() {
        let vc = Container()
        let done = expectation(description: "off-main handle returns")

        DispatchQueue.global().async { [self] in
            // The broker's state is unsynchronized, so this must not be processed — but it must
            // also not terminate the host app. A `dispatchPrecondition` here would trap in every
            // optimisation level, including `-Ounchecked`, on a swizzle attached to every
            // UIViewController in the customer's app.
            broker.handle(.started(id(vc), name: "Home", at: time(0)))
            done.fulfill()
        }

        wait(for: [done], timeout: 5)

        // Dropped, so the matching resume on main has no start time and emits nothing.
        broker.handle(.resumed(id(vc), name: "Home", at: time(1)))
        XCTAssertTrue(loads.isEmpty)
    }

    // MARK: - Interleaving

    func testInterleavedStartsAndResumesAttributeToTheRightContainer() {
        let first = Container()
        let second = Container()

        broker.handle(.started(id(first), name: "Home", at: time(0)))
        broker.handle(.started(id(second), name: "Detail", at: time(1)))
        broker.handle(.resumed(id(second), name: "Detail", at: time(2)))
        broker.handle(.paused(id(second), name: "Detail", at: time(3)))
        broker.handle(.resumed(id(first), name: "Home", at: time(4)))

        XCTAssertEqual(names, ["Detail", "Home"])
        XCTAssertEqual(loads[0].time, time(1), "Detail backdates to its own start")
        XCTAssertEqual(loads[1].time, time(0), "Home backdates to its own start")
    }
}
