//
//  FinishedSessionTest.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI

class FinishedSessionTest: PayloadTest {
    var testRelevantPayloadNames: [String] { ["emb-session", "POST /api/v2/spans"] }
    var testType: TestType { .Spans }
    var requiresCleanup: Bool { true }
    var runImmediatelyIfSpansFound: Bool { false }

    var fakeAppState: Bool = false

    private var currentSession: String = ""

    func runTestPreparations() {
        currentSession = EmbraceIO.shared.currentSessionId ?? ""
        if fakeAppState {
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            }
        }
    }

    func test(spans: [OpenTelemetrySdk.SpanData]) -> TestReport {
        var testItems = [TestReportItem]()

        // Match on `emb.session_part_id` — the part UUID that `currentSessionId` returns. The
        // exported `emb-session` span deliberately does NOT carry `session.id` / `emb.user_session_id`;
        // those are stamped only at payload-build time from the stored `SessionRecord.userSessionId`.
        // See `UploadedSessionPayloadTest` for the identity assertions on the uploaded payload.
        let (resultItem, sessionSpan) = evaluateSpanExistence(
            identifiedBy: currentSession, underAttributeKey: "emb.session_part_id", on: spans)
        testItems.append(resultItem)

        guard let sessionSpan = sessionSpan else {
            return .init(items: testItems)
        }

        /// The post span exported doesn't contain anything that ties it to the session span it uploaded. I'm checking that the span was created after the last session ended.
        /// This is our best guess this Post Span is related to the last ended session.
        /// It'll... Do for now.
        guard
            spans.first(where: {
                $0.name == "POST /api/v2/spans" && $0.startTime > sessionSpan.endTime
            }) != nil
        else {
            testItems.append(.init(target: "POST Session Span", expected: "existing", recorded: "missing"))
            return .init(items: testItems)
        }

        testItems.append(.init(target: "POST Session Span", expected: "existing", recorded: "existing"))

        testItems.append(evaluate("emb.type", expecting: "ux.session", on: sessionSpan.attributes))
        testItems.append(evaluate("emb.state", expecting: "foreground", on: sessionSpan.attributes))
        testItems.append(evaluate("emb.session_part_id", expecting: currentSession, on: sessionSpan.attributes))
        testItems.append(heartbeatReportItem(for: sessionSpan))
        testItems.append(evaluate("emb.cold_start", expectedToExist: true, on: sessionSpan.attributes))
        testItems.append(contentsOf: OTelSemanticsValidation.validateAttributeNames(sessionSpan.attributes))

        return .init(items: testItems)
    }

    /// `emb.heartbeat_time_unix_nano` is stamped on the live span only when the heartbeat timer
    /// fires — the first tick is ~`SessionHeartbeat.defaultInterval` (5s) after the part starts, and
    /// the timer is stopped when the part ends. A part that ends before its first tick therefore has
    /// no heartbeat attribute on the live span (the uploaded payload always carries one, derived from
    /// `lastHeartbeatTime`). So only require it when the part lived long enough for a tick; treat its
    /// absence on a short-lived part as expected.
    private func heartbeatReportItem(for sessionSpan: SpanData) -> TestReportItem {
        let heartbeatInterval: TimeInterval = 5
        let key = "emb.heartbeat_time_unix_nano"
        let present = sessionSpan.attributes[key] != nil
        let duration = sessionSpan.hasEnded ? sessionSpan.endTime.timeIntervalSince(sessionSpan.startTime) : 0

        if present {
            return .init(target: key, expected: "exists", recorded: "exists", result: .success)
        }

        // Not present: fail only if the part lived long enough that a tick should have fired.
        let longEnough = duration > heartbeatInterval
        return .init(
            target: key,
            expected: longEnough ? "exists" : "exists (or expected-absent for a <\(Int(heartbeatInterval))s part)",
            recorded: longEnough ? "missing" : "missing (part too short for a heartbeat tick)",
            result: longEnough ? .fail : .warning)
    }
}
