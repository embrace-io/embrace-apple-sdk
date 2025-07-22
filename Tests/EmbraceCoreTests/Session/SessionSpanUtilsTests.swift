//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceOTelInternal
import EmbraceStorageInternal
import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCore

final class SessionSpanUtilsTests: XCTestCase {

    var spanProcessor: MockSpanProcessor!

    override func setUpWithError() throws {
        spanProcessor = MockSpanProcessor()
        EmbraceOTel.setup(spanProcessors: [spanProcessor])
    }

    override func tearDownWithError() throws {
        spanProcessor = nil
        EmbraceOTel.setup(spanProcessors: [])
    }

    func test_buildSpan() throws {
        // when building a session span
        _ = SessionSpanUtils.span(
            id: TestConstants.sessionId,
            startTime: TestConstants.date,
            state: .foreground,
            coldStart: true
        )

        // then the span is correct
        let spanData = spanProcessor.startedSpans[0]
        XCTAssertEqual(spanData.name, "emb-session")
        XCTAssertEqual(spanData.startTime, TestConstants.date)
        XCTAssertEqual(spanData.attributes["emb.type"], .string("ux.session"))
        XCTAssertEqual(spanData.attributes["session.id"], .string(TestConstants.sessionId.toString))
        XCTAssertEqual(spanData.attributes["emb.state"], .string(SessionState.foreground.rawValue))
        XCTAssertEqual(spanData.attributes["emb.cold_start"], .bool(true))
    }

    func test_setState() throws {
        // given a session span
        let span = SessionSpanUtils.span(
            id: TestConstants.sessionId,
            startTime: TestConstants.date,
            state: .foreground,
            coldStart: true
        )

        // when updating the state
        SessionSpanUtils.setState(span: span, state: .background)
        span.end()

        // then it is updated correctly
        let spanData = spanProcessor.endedSpans[0]
        XCTAssertEqual(spanData.attributes["emb.state"], .string(SessionState.background.rawValue))
    }

    func test_setHeartbeat() throws {
        // given a session span
        let span = SessionSpanUtils.span(
            id: TestConstants.sessionId,
            startTime: TestConstants.date,
            state: .foreground,
            coldStart: true
        )

        // when updating the heartbeat
        let heartbeat = Date()
        SessionSpanUtils.setHeartbeat(span: span, heartbeat: heartbeat)
        span.end()

        // then it is updated correctly
        let spanData = spanProcessor.endedSpans[0]
        XCTAssertEqual(
            spanData.attributes["emb.heartbeat_time_unix_nano"],
            .int(heartbeat.nanosecondsSince1970Truncated)
        )
    }

    func test_setTerminated() throws {
        // given a session span
        let span = SessionSpanUtils.span(
            id: TestConstants.sessionId,
            startTime: TestConstants.date,
            state: .foreground,
            coldStart: true
        )

        // when updating the terminated flag
        SessionSpanUtils.setTerminated(span: span, terminated: true)
        span.end()

        // then it is updated correctly
        let spanData = spanProcessor.endedSpans[0]
        XCTAssertEqual(spanData.attributes["emb.terminated"], .bool(true))
    }

    func test_payloadFromSesssion() throws {
        // given a session record
        let endTime = Date(timeIntervalSince1970: 60)
        let heartbeat = Date(timeIntervalSince1970: 58)

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
            appTerminated: true
        )

        // when building the session span payload
        let payload = SessionSpanUtils.payload(from: session, sessionNumber: 100)

        // then the payload is correct
        XCTAssertEqual(payload.name, "emb-session")
        XCTAssertEqual(payload.traceId, TestConstants.traceId)
        XCTAssertEqual(payload.spanId, TestConstants.spanId)
        XCTAssertNil(payload.parentSpanId)
        XCTAssertEqual(payload.status, "error")
        XCTAssertEqual(payload.startTime, TestConstants.date.nanosecondsSince1970Truncated)
        XCTAssertEqual(payload.endTime, endTime.nanosecondsSince1970Truncated)
        XCTAssertEqual(payload.events.count, 0)
        XCTAssertEqual(payload.links.count, 0)

        let typeAttribute = payload.attributes.first {
            $0.key == "emb.type"
        }
        XCTAssertEqual(typeAttribute!.value, "ux.session")

        let sessionAttribute = payload.attributes.first {
            $0.key == "session.id"
        }
        XCTAssertEqual(sessionAttribute!.value, TestConstants.sessionId.toString)

        let stateAttribute = payload.attributes.first {
            $0.key == "emb.state"
        }
        XCTAssertEqual(stateAttribute!.value, SessionState.foreground.rawValue)

        let coldStartAttribute = payload.attributes.first {
            $0.key == "emb.cold_start"
        }
        XCTAssertEqual(coldStartAttribute!.value, "true")

        let terminatedAttribute = payload.attributes.first {
            $0.key == "emb.terminated"
        }
        XCTAssertEqual(terminatedAttribute!.value, "true")

        let cleanExitAttribute = payload.attributes.first {
            $0.key == "emb.clean_exit"
        }
        XCTAssertEqual(cleanExitAttribute!.value, "false")

        let heartbeatAttribute = payload.attributes.first {
            $0.key == "emb.heartbeat_time_unix_nano"
        }
        XCTAssertEqual(heartbeatAttribute!.value, String(heartbeat.nanosecondsSince1970Truncated))

        let sessionNumberAttribute = payload.attributes.first {
            $0.key == "emb.session_number"
        }
        XCTAssertEqual(sessionNumberAttribute!.value, "100")

        let crashIdAttribute = payload.attributes.first {
            $0.key == "emb.crash_id"
        }
        XCTAssertEqual(crashIdAttribute!.value, "test")
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

        var payload = SessionSpanUtils.payload(from: session, sessionNumber: 100)
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

        payload = SessionSpanUtils.payload(from: session, sessionNumber: 100)
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
        let payload = SessionSpanUtils.payload(from: session, properties: properties, sessionNumber: 100)

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
        let payload = SessionSpanUtils.payload(from: session, properties: properties, sessionNumber: 100)

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
