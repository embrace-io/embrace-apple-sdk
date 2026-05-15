//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

final class SessionSpanUtilsTests: XCTestCase {

    var otel: MockOTelSignalsHandler!

    override func setUpWithError() throws {
        otel = MockOTelSignalsHandler()
    }

    override func tearDownWithError() throws {
    }

    func test_buildSpan() throws {
        // when building a session span
        _ = SessionSpanUtils.span(
            otel: otel,
            id: TestConstants.sessionId,
            startTime: TestConstants.date,
            state: .foreground,
            coldStart: true
        )

        // then the span is correct. The live attributes carry the part id under
        // `emb.session_part_id`; the user-session id keys are stamped later (at payload-build
        // time) because `attachPart` hasn't run yet when the session-part span is created.
        let span = otel.startedSpans[0]
        XCTAssertEqual(span.name, "emb-session")
        XCTAssertEqual(span.type, .session)
        XCTAssertEqual(span.startTime, TestConstants.date)
        XCTAssertEqual(
            span.attributes["emb.session_part_id"] as! String,
            TestConstants.sessionId.stringValue
        )
        XCTAssertEqual(span.attributes["emb.state"] as! String, SessionState.foreground.rawValue)
        XCTAssertEqual(span.attributes["emb.cold_start"] as! String, "true")
    }

    func test_setState() throws {
        // given a session span
        let span = SessionSpanUtils.span(
            otel: otel,
            id: TestConstants.sessionId,
            startTime: TestConstants.date,
            state: .foreground,
            coldStart: true
        )

        // when updating the state
        SessionSpanUtils.setState(span: span, state: .background)
        span!.end()

        // then it is updated correctly
        XCTAssertEqual(otel.endedSpans[0].attributes["emb.state"] as! String, SessionState.background.rawValue)
    }

    func test_setHeartbeat() throws {
        // given a session span
        let span = SessionSpanUtils.span(
            otel: otel,
            id: TestConstants.sessionId,
            startTime: TestConstants.date,
            state: .foreground,
            coldStart: true
        )

        // when updating the heartbeat
        let heartbeat = Date()
        SessionSpanUtils.setHeartbeat(span: span, heartbeat: heartbeat)
        span!.end()

        // then it is updated correctly
        XCTAssertEqual(
            otel.endedSpans[0].attributes["emb.heartbeat_time_unix_nano"] as! String,
            String(heartbeat.nanosecondsSince1970Truncated)
        )
    }

    func test_setTerminated() throws {
        // given a session span
        let span = SessionSpanUtils.span(
            otel: otel,
            id: TestConstants.sessionId,
            startTime: TestConstants.date,
            state: .foreground,
            coldStart: true
        )

        // when updating the terminated flag
        SessionSpanUtils.setTerminated(span: span, terminated: true)
        span!.end()

        // then it is updated correctly
        XCTAssertEqual(otel.endedSpans[0].attributes["emb.terminated"] as! String, "true")
    }

    func test_payloadFromSesssion() throws {
        // given a session record with a full user-session metadata bag
        let endTime = Date(timeIntervalSince1970: 60)
        let heartbeat = Date(timeIntervalSince1970: 58)
        let userSessionId = EmbraceIdentifier.random
        let userSessionStart = Date(timeIntervalSince1970: 10)

        let session = MockSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: TestConstants.date,
            endTime: endTime,
            lastHeartbeatTime: heartbeat,
            crashReportId: "test",
            coldStart: true,
            cleanExit: false,
            appTerminated: true,
            sessionNumber: 100,
            userSessionId: userSessionId,
            userSessionStartTime: userSessionStart,
            userSessionMaxDuration: 43200,
            userSessionInactivityTimeout: 1800,
            userSessionPartIndex: 3
        )

        let payload = SessionSpanUtils.payload(from: session)

        XCTAssertEqual(payload.name, "emb-session")
        XCTAssertEqual(payload.traceId, TestConstants.traceId)
        XCTAssertEqual(payload.spanId, TestConstants.spanId)
        XCTAssertNil(payload.parentSpanId)
        XCTAssertEqual(payload.status, "error")
        XCTAssertEqual(payload.startTime, TestConstants.date.nanosecondsSince1970Truncated)
        XCTAssertEqual(payload.endTime, endTime.nanosecondsSince1970Truncated)
        XCTAssertEqual(payload.events.count, 0)
        XCTAssertEqual(payload.links.count, 0)

        func attribute(_ key: String) -> String? {
            payload.attributes.first { $0.key == key }?.value
        }

        XCTAssertEqual(attribute("emb.type"), "ux.session")

        // Identity: session.id is the user-session id (not the part id); emb.session_part_id is the part.
        XCTAssertEqual(attribute("session.id"), userSessionId.stringValue)
        XCTAssertEqual(attribute("emb.user_session_id"), userSessionId.stringValue)
        XCTAssertEqual(attribute("emb.session_part_id"), TestConstants.sessionId.stringValue)

        XCTAssertEqual(attribute("emb.state"), SessionState.foreground.rawValue)
        XCTAssertEqual(attribute("emb.cold_start"), "true")
        XCTAssertEqual(attribute("emb.terminated"), "true")
        XCTAssertEqual(attribute("emb.clean_exit"), "false")
        XCTAssertEqual(attribute("emb.heartbeat_time_unix_nano"), String(heartbeat.nanosecondsSince1970Truncated))

        // Counters
        XCTAssertEqual(attribute("emb.session_part_number"), "100")
        XCTAssertEqual(attribute("emb.user_session_part_index"), "3")

        // User-session config snapshots
        XCTAssertEqual(attribute("emb.user_session_start_ts"), String(userSessionStart.nanosecondsSince1970Truncated))
        XCTAssertEqual(attribute("emb.user_session_max_duration_seconds"), "43200.0")
        XCTAssertEqual(attribute("emb.user_session_inactivity_timeout_seconds"), "1800.0")

        XCTAssertEqual(attribute("emb.crash_id"), "test")

        // Old key gone, no termination-reason-related keys when not set.
        XCTAssertNil(attribute("emb.session_number"))
        XCTAssertNil(attribute("emb.user_session_termination_reason"))
        XCTAssertNil(attribute("emb.is_final_session_part"))
    }

    func test_payload_emitsTerminationReasonAndFinalPartFlagOnLastPart() throws {
        let session = MockSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: TestConstants.date,
            sessionNumber: 5,
            userSessionId: EmbraceIdentifier.random,
            userSessionStartTime: TestConstants.date,
            userSessionMaxDuration: 43200,
            userSessionInactivityTimeout: 1800,
            userSessionPartIndex: 2,
            userSessionTerminationReason: .manual
        )

        let payload = SessionSpanUtils.payload(from: session)

        let terminationReason = payload.attributes.first { $0.key == "emb.user_session_termination_reason" }
        let finalPartFlag = payload.attributes.first { $0.key == "emb.is_final_session_part" }
        XCTAssertEqual(terminationReason?.value, "manual")
        XCTAssertEqual(finalPartFlag?.value, "1")
    }

    func test_payload_legacySessionEmitsEmptyUserSessionId() throws {
        // Pre-v7 row: no user-session columns set.
        let session = MockSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: TestConstants.date
        )

        let payload = SessionSpanUtils.payload(from: session)

        func attribute(_ key: String) -> String? {
            payload.attributes.first { $0.key == key }?.value
        }

        XCTAssertEqual(attribute("session.id"), "")
        XCTAssertEqual(attribute("emb.user_session_id"), "")
        XCTAssertEqual(attribute("emb.session_part_id"), TestConstants.sessionId.stringValue)
    }

    func test_status() {
        // test ok status
        var session = MockSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: TestConstants.date,
            endTime: Date(),
            lastHeartbeatTime: Date(),
            crashReportId: nil,
            coldStart: true,
            cleanExit: false,
            appTerminated: true
        )

        var payload = SessionSpanUtils.payload(from: session)
        XCTAssertEqual(payload.status, "ok")

        // test error status
        session = MockSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: TestConstants.date,
            endTime: Date(),
            lastHeartbeatTime: Date(),
            crashReportId: "test",
            coldStart: true,
            cleanExit: false,
            appTerminated: true
        )

        payload = SessionSpanUtils.payload(from: session)
        XCTAssertEqual(payload.status, "error")
    }

    func test_payloadFromSession_shouldAddCustomePropertiesWithPrefixedKey() {
        let session = givenSessionRecord()

        let properties = [
            givenCustomProperty(withKey: "a_permanent_key", value: "a_permanent_value", lifespan: .permanent),
            givenCustomProperty(withKey: "a_process_key", value: "a_process_value", lifespan: .permanent),
            givenCustomProperty(withKey: "a_session_key", value: "a_session_value", lifespan: .permanent)
        ]

        // when building the session span payload
        let payload = SessionSpanUtils.payload(from: session, properties: properties)

        XCTAssertGreaterThanOrEqual(payload.attributes.count, 3)
        let permanentCustomProperty = payload.attributes.first {
            $0.key == "emb.properties.a_permanent_key"
        }
        XCTAssertEqual(permanentCustomProperty!.value, "a_permanent_value")

        let processCustomProperty = payload.attributes.first {
            $0.key == "emb.properties.a_process_key"
        }
        XCTAssertEqual(processCustomProperty!.value, "a_process_value")

        let sessionCustomProperty = payload.attributes.first {
            $0.key == "emb.properties.a_session_key"
        }
        XCTAssertEqual(sessionCustomProperty!.value, "a_session_value")
    }

    func test_payloadFromSession_attributesShouldntIncludeUserProperties() {
        let session = givenSessionRecord()
        var properties: [EmbraceMetadata] = []
        properties.append(
            givenCustomProperty(
                withKey: "emb.user.username",
                value: "embrace",
                lifespan: .session
            )
        )
        properties.append(
            givenCustomProperty(
                withKey: "emb.user.email",
                value: "asd@embrace.io",
                lifespan: .permanent
            )
        )
        properties.append(
            givenCustomProperty(
                withKey: "emb.user.identifier",
                value: .random(),
                lifespan: .process
            )
        )

        // when building the session span payload
        let payload = SessionSpanUtils.payload(from: session, properties: properties)

        XCTAssertFalse(payload.attributes.contains(where: { $0.key == "emb.user.username " }))
        XCTAssertFalse(payload.attributes.contains(where: { $0.key == "emb.user.email" }))
        XCTAssertFalse(payload.attributes.contains(where: { $0.key == "emb.user.identifierj" }))
    }
}

extension SessionSpanUtilsTests {
    fileprivate func givenSessionRecord() -> MockSession {
        let endTime = Date(timeIntervalSince1970: 60)
        let heartbeat = Date(timeIntervalSince1970: 58)

        return MockSession(
            id: TestConstants.sessionId,
            processId: TestConstants.processId,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: TestConstants.date,
            endTime: endTime,
            lastHeartbeatTime: heartbeat,
            crashReportId: .random(),
            coldStart: .random(),
            cleanExit: .random(),
            appTerminated: .random())
    }

    fileprivate func givenCustomProperty(withKey key: String, value: String, lifespan: MetadataRecordLifespan)
        -> MockMetadata
    {
        MockMetadata(
            key: key,
            value: value,
            type: .customProperty,
            lifespan: lifespan,
            lifespanId: .random()
        )
    }
}
