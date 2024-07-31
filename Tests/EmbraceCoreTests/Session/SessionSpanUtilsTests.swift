//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
import EmbraceCommonInternal
import EmbraceStorageInternal
import TestSupport
import EmbraceOTelInternal
import OpenTelemetryApi
import OpenTelemetrySdk

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
        XCTAssertEqual(spanData.name, SessionSpanUtils.spanName)
        XCTAssertEqual(spanData.startTime, TestConstants.date)
        XCTAssertEqual(
            spanData.attributes[SessionSpanUtils.AttributeKey.type.rawValue],
            .string(SessionSpanUtils.spanType)
        )
        XCTAssertEqual(
            spanData.attributes[SessionSpanUtils.AttributeKey.id.rawValue],
            .string(TestConstants.sessionId.toString)
        )
        XCTAssertEqual(
            spanData.attributes[SessionSpanUtils.AttributeKey.state.rawValue],
            .string(SessionState.foreground.rawValue)
        )
        XCTAssertEqual(
            spanData.attributes[SessionSpanUtils.AttributeKey.coldStart.rawValue],
            .bool(true)
        )
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
        XCTAssertEqual(
            spanData.attributes[SessionSpanUtils.AttributeKey.state.rawValue],
            .string(SessionState.background.rawValue)
        )
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
            spanData.attributes[SessionSpanUtils.AttributeKey.heartbeat.rawValue],
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
        XCTAssertEqual(
            spanData.attributes[SessionSpanUtils.AttributeKey.terminated.rawValue],
            .bool(true)
        )
    }

    func test_setCleanExit() throws {
        // given a session span
        let span = SessionSpanUtils.span(
            id: TestConstants.sessionId,
            startTime: TestConstants.date,
            state: .foreground,
            coldStart: true
        )

        // when updating the clean exit flagvay
        SessionSpanUtils.setCleanExit(span: span, cleanExit: true)
        span.end()

        // then it is updated correctly
        let spanData = spanProcessor.endedSpans[0]
        XCTAssertEqual(
            spanData.attributes[SessionSpanUtils.AttributeKey.cleanExit.rawValue],
            .bool(true)
        )
    }

    func test_payloadFromSesssion() throws {
        // given a session record
        let endTime = Date(timeIntervalSince1970: 60)
        let heartbeat = Date(timeIntervalSince1970: 58)

        let session = SessionRecord(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: TestConstants.processId,
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
        XCTAssertEqual(payload.name, SessionSpanUtils.spanName)
        XCTAssertEqual(payload.traceId, TestConstants.traceId)
        XCTAssertEqual(payload.spanId, TestConstants.spanId)
        XCTAssertNil(payload.parentSpanId)
        XCTAssertEqual(payload.status, Status.ok.name)
        XCTAssertEqual(payload.startTime, TestConstants.date.nanosecondsSince1970Truncated)
        XCTAssertEqual(payload.endTime, endTime.nanosecondsSince1970Truncated)
        XCTAssertEqual(payload.events.count, 0)
        XCTAssertEqual(payload.links.count, 0)

        let typeAttribute = payload.attributes.first {
            $0.key == SessionSpanUtils.AttributeKey.type.rawValue
        }
        XCTAssertEqual(typeAttribute!.value, SessionSpanUtils.spanType)

        let sessionAttribute = payload.attributes.first {
            $0.key == SessionSpanUtils.AttributeKey.id.rawValue
        }
        XCTAssertEqual(sessionAttribute!.value, TestConstants.sessionId.toString)

        let stateAttribute = payload.attributes.first {
            $0.key == SessionSpanUtils.AttributeKey.state.rawValue
        }
        XCTAssertEqual(stateAttribute!.value, SessionState.foreground.rawValue)

        let coldStartAttribute = payload.attributes.first {
            $0.key == SessionSpanUtils.AttributeKey.coldStart.rawValue
        }
        XCTAssertEqual(coldStartAttribute!.value, "true")

        let terminatedAttribute = payload.attributes.first {
            $0.key == SessionSpanUtils.AttributeKey.terminated.rawValue
        }
        XCTAssertEqual(terminatedAttribute!.value, "true")

        let cleanExitAttribute = payload.attributes.first {
            $0.key == SessionSpanUtils.AttributeKey.cleanExit.rawValue
        }
        XCTAssertEqual(cleanExitAttribute!.value, "false")

        let heartbeatAttribute = payload.attributes.first {
            $0.key == SessionSpanUtils.AttributeKey.heartbeat.rawValue
        }
        XCTAssertEqual(heartbeatAttribute!.value, String(heartbeat.nanosecondsSince1970Truncated))

        let sessionNumberAttribute = payload.attributes.first {
            $0.key == SessionSpanUtils.AttributeKey.sessionNumber.rawValue
        }
        XCTAssertEqual(sessionNumberAttribute!.value, "100")

        let crashIdAttribute = payload.attributes.first {
            $0.key == SessionSpanUtils.AttributeKey.crashId.rawValue
        }
        XCTAssertEqual(crashIdAttribute!.value, "test")
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
        var properties: [MetadataRecord] = []
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

        XCTAssertFalse(payload.attributes.contains(where: { $0.key == "emb.user.username "}))
        XCTAssertFalse(payload.attributes.contains(where: { $0.key == "emb.user.email"}))
        XCTAssertFalse(payload.attributes.contains(where: { $0.key == "emb.user.identifierj"}))
    }
}

private extension SessionSpanUtilsTests {
    func givenSessionRecord() -> SessionRecord {
        let endTime = Date(timeIntervalSince1970: 60)
        let heartbeat = Date(timeIntervalSince1970: 58)

        return SessionRecord(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: TestConstants.processId,
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

    func givenCustomProperty(withKey key: String, value: String, lifespan: MetadataRecordLifespan) -> MetadataRecord {
        .init(key: key, value: .string(value), type: .customProperty, lifespan: lifespan, lifespanId: .random())
    }
}
