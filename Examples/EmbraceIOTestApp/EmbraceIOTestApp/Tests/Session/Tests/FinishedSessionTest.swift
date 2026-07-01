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
        testItems.append(evaluate("emb.heartbeat_time_unix_nano", expectedToExist: true, on: sessionSpan.attributes))
        testItems.append(evaluate("emb.cold_start", expectedToExist: true, on: sessionSpan.attributes))
        testItems.append(contentsOf: OTelSemanticsValidation.validateAttributeNames(sessionSpan.attributes))

        return .init(items: testItems)
    }
}
