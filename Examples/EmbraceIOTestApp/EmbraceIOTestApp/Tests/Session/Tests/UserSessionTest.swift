//
//  UserSessionTest.swift
//  EmbraceIOTestApp
//
//

import EmbraceCommonInternal
import EmbraceIO
import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI

/// Exercises the public **User Session** API (`EmbraceIO.shared.endUserSession()`).
///
/// Ending a user session closes the currently active session part — finishing and exporting its
/// `emb-session` span — and immediately rolls into a brand-new user session by starting a fresh
/// part with the same foreground/background state. This test validates both halves of that
/// behavior:
///   1. the part that was active when the test started is exported as a finished `emb-session`
///      span carrying the expected attributes (verified from `spans`); and
///   2. the active user session is terminated with `.manual` and a *different* user session is
///      started (verified from the public user-session notifications).
///
/// ### Why this test does NOT poll `EmbraceIO.shared.currentSessionId`
///
/// `endUserSession()` is **asynchronous**: it dispatches the whole roll
/// (end-part → end-user-session → start-part) onto the session-controller's serial queue, and the
/// new part id is only published at the very last step. Meanwhile this `test(spans:)` method is
/// invoked from the span-exporter's notification, which runs on the exporter's processing queue and
/// fires the moment the *old* part's span is exported — i.e. at the *start* of the roll, before the
/// new part exists. Reading `currentSessionId` here therefore races the roll and frequently returns
/// `nil` (the window after the old part is cleared but before the new part is assigned). A
/// `Thread.sleep` on the main thread does not help because none of this work runs on main.
///
/// Instead we observe the roll through the public, event-driven user-session notifications and wait
/// on them with semaphores, which is order-independent and not racy.
///
/// - Note: `endUserSession()` is rate-limited to one call every 5 seconds. If this test is run
///   again within that window the call is ignored, no roll happens, and the notification waits time
///   out — wait a few seconds between runs.
class UserSessionTest: PayloadTest {
    var testRelevantPayloadNames: [String] { ["emb-session"] }
    var testType: TestType { .Spans }
    var requiresCleanup: Bool { true }
    var runImmediatelyIfSpansFound: Bool { false }

    /// Max time `test(spans:)` waits (off the main thread) for the user-session notifications that
    /// the asynchronous roll posts on the main queue.
    private static let notificationTimeout: TimeInterval = 3.0

    /// Part id of the session that is active when the test starts. Ending the user session closes
    /// this part, so this is the id we expect on the finished `emb-session` span that gets exported.
    private var endedSessionPartId: String = ""

    // Captured from the public user-session notifications posted during the roll.
    private let lock = NSLock()
    private var _endedUserSession: EmbraceUserSession?
    private var _startedUserSession: EmbraceUserSession?
    private let didEndSemaphore = DispatchSemaphore(value: 0)
    private let didStartSemaphore = DispatchSemaphore(value: 0)
    private var observers: [NSObjectProtocol] = []

    func runTestPreparations() {
        endedSessionPartId = EmbraceIO.shared.currentSessionId ?? ""

        // Subscribe BEFORE ending the session so we don't miss the notifications the roll posts.
        let endObserver = NotificationCenter.default.addObserver(
            forName: .embraceUserSessionDidEnd, object: nil, queue: nil
        ) { [weak self] note in
            guard let self, let session = note.object as? EmbraceUserSession else { return }
            self.lock.withLock { self._endedUserSession = session }
            self.didEndSemaphore.signal()
        }

        let startObserver = NotificationCenter.default.addObserver(
            forName: .embraceUserSessionDidStart, object: nil, queue: nil
        ) { [weak self] note in
            guard let self, let session = note.object as? EmbraceUserSession else { return }
            self.lock.withLock { self._startedUserSession = session }
            self.didStartSemaphore.signal()
        }

        observers = [endObserver, startObserver]

        // Asynchronous: closes the current part (exporting its span), ends the active user session
        // with `.manual`, and starts a fresh part under a new user session with the same state.
        EmbraceIO.shared.endUserSession()
    }

    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        // The part that was active when the test started must have been finished and exported.
        let (existenceItem, endedSpan) = evaluateSpanExistence(
            identifiedBy: endedSessionPartId, underAttributeKey: "emb.session_part_id", on: spans)
        testItems.append(existenceItem)

        if let endedSpan = endedSpan {
            // Ending the user session closes the part, so its span must be finished.
            testItems.append(
                .init(
                    target: "Ended session part finished",
                    expected: "finished",
                    recorded: endedSpan.hasEnded ? "finished" : "open",
                    result: endedSpan.hasEnded ? .success : .fail))

            testItems.append(evaluate("emb.type", expecting: "ux.session", on: endedSpan.attributes))
            testItems.append(evaluate("emb.state", expecting: "foreground", on: endedSpan.attributes))
            testItems.append(evaluate("emb.session_part_id", expecting: endedSessionPartId, on: endedSpan.attributes))
            testItems.append(evaluate("emb.cold_start", expectedToExist: true, on: endedSpan.attributes))
            testItems.append(contentsOf: OTelSemanticsValidation.validateAttributeNames(endedSpan.attributes))
        }

        // The roll posts its notifications asynchronously on the main queue; this method runs on the
        // exporter's queue, so wait (off-main) for them rather than reading live SDK state.
        appendUserSessionRollItems(to: &testItems)

        cleanup()
        return .init(items: testItems)
    }

    private func appendUserSessionRollItems(to testItems: inout [TestReportItem]) {
        let endObserved = didEndSemaphore.wait(timeout: .now() + Self.notificationTimeout) == .success
        let startObserved = didStartSemaphore.wait(timeout: .now() + Self.notificationTimeout) == .success

        let endedUserSession = lock.withLock { _endedUserSession }
        let startedUserSession = lock.withLock { _startedUserSession }

        testItems.append(
            .init(
                target: "Active user session ended",
                expected: "ended",
                recorded: endObserved ? "ended" : "not observed",
                result: endObserved ? .success : .fail))

        testItems.append(
            .init(
                target: "User session termination reason",
                expected: TerminationReason.manual.rawValue,
                recorded: endedUserSession?.terminationReason?.rawValue ?? "missing"))

        testItems.append(
            .init(
                target: "New user session started",
                expected: "started",
                recorded: startObserved ? "started" : "not observed",
                result: startObserved ? .success : .fail))

        let endedId = endedUserSession?.id.stringValue
        let startedId = startedUserSession?.id.stringValue
        let rolled = endedId != nil && startedId != nil && endedId != startedId
        testItems.append(
            .init(
                target: "Rolled into a different user session",
                expected: "new user session id",
                recorded: rolled ? (startedId ?? "") : "\(startedId ?? "nil") vs ended \(endedId ?? "nil")",
                result: rolled ? .success : .fail))
    }

    private func cleanup() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}
