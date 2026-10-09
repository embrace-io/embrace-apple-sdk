//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore

final class SessionPayloadBuilderTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionRecord: MockSession!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInMemoryDb()

        sessionRecord = MockSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 60)
        )
    }

    override func tearDownWithError() throws {
        sessionRecord = nil
        storage.coreData.destroy()
    }

    func test_usesSessionNumberFromSession() throws {
        // given a session with a pre-assigned sessionNumber
        sessionRecord = MockSession(
            id: TestConstants.sessionId,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 60),
            sessionNumber: 7
        )

        // when building a session payload
        let payload = SessionPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the session span contains the correct session-part number
        let sessionSpan = payload?.data["spans"]?.first { $0.name == "emb-session" }
        let sessionNumberAttr = sessionSpan?.attributes.first { $0.key == "emb.session_part_number" }
        XCTAssertEqual(sessionNumberAttr?.value, "7")

        // and the MetadataRecord counter was NOT touched
        let resource = storage.fetchMetadata(
            key: SessionController.sessionPartNumberKey,
            type: .requiredResource,
            lifespan: .permanent
        )
        XCTAssertNil(resource)
    }

    func test_usesSessionNumberFromStoredSession() throws {
        // given a session whose number was assigned by storage
        storage.addMetadata(
            key: SessionController.sessionPartNumberKey,
            value: "41",
            type: .requiredResource,
            lifespan: .permanent
        )
        let session = try XCTUnwrap(
            storage.addSession(
                id: TestConstants.sessionId,
                processId: ProcessIdentifier.current,
                state: .foreground,
                traceId: TestConstants.traceId,
                spanId: TestConstants.spanId,
                startTime: Date(timeIntervalSince1970: 0),
                endTime: Date(timeIntervalSince1970: 60),
                sessionNumberCounterKey: SessionController.sessionPartNumberKey
            ))

        // when building a session payload from the in-memory session, which doesn't carry the number
        XCTAssertEqual(session.sessionNumber, 0)
        let payload = SessionPayloadBuilder.build(for: session, storage: storage)

        // then the session span contains the stored session-part number
        let sessionSpan = payload?.data["spans"]?.first { $0.name == "emb-session" }
        let sessionNumberAttr = sessionSpan?.attributes.first { $0.key == "emb.session_part_number" }
        XCTAssertEqual(sessionNumberAttr?.value, "42")
    }

    func test_usesUserSessionFromStoredSession() throws {
        // given a part whose user session was resolved on the storage queue
        let userSession = ImmutableUserSession(
            id: .random,
            startTime: Date(timeIntervalSince1970: 0),
            maxDuration: 100,
            inactivityTimeout: 10,
            lastForegroundPartEnd: nil,
            partIndex: 3,
            endTime: nil,
            terminationReason: nil,
            isBackgroundOnly: false
        )
        let session = try XCTUnwrap(
            storage.addSession(
                id: TestConstants.sessionId,
                processId: ProcessIdentifier.current,
                state: .foreground,
                traceId: TestConstants.traceId,
                spanId: TestConstants.spanId,
                startTime: Date(timeIntervalSince1970: 0),
                endTime: Date(timeIntervalSince1970: 60),
                resolveUserSession: { userSession }
            ))

        // and a property of that user session
        storage.addMetadata(
            key: "prop", value: "value", type: .customProperty,
            lifespan: .userSession, lifespanId: userSession.id.stringValue
        )

        // when building a session payload from the in-memory part, which doesn't have the user session
        XCTAssertNil(session.userSessionId)
        let payload = SessionPayloadBuilder.build(for: session, storage: storage)

        // then the session span has the stored user session and its properties
        let sessionSpan = try XCTUnwrap(payload?.data["spans"]?.first { $0.name == "emb-session" })
        let attributes = Dictionary(uniqueKeysWithValues: sessionSpan.attributes.map { ($0.key, $0.value) })
        XCTAssertEqual(attributes["emb.user_session_id"], userSession.id.stringValue)
        XCTAssertEqual(attributes["emb.user_session_part_index"], "3")
        XCTAssertEqual(attributes["emb.properties.prop"], "value")
    }

    func test_doesNotTakeTheBackfilledTerminationReasonFromTheStoredSession() throws {
        // given a stored part whose record got a termination reason backfilled, and the in-memory copy without it
        let session = try XCTUnwrap(
            storage.addSession(
                id: TestConstants.sessionId,
                processId: ProcessIdentifier.current,
                state: .foreground,
                traceId: TestConstants.traceId,
                spanId: TestConstants.spanId,
                startTime: Date(timeIntervalSince1970: 0),
                endTime: Date(timeIntervalSince1970: 60),
                userSessionId: .random,
                userSessionPartIndex: 1
            ))
        storage.setUserSessionTerminationReasonOnLatestSessionIfNeeded(.manual)

        // when building a session payload from the in-memory copy
        let payload = SessionPayloadBuilder.build(for: session, storage: storage)

        // then the payload has no termination reason, as the in-memory copy
        let sessionSpan = try XCTUnwrap(payload?.data["spans"]?.first { $0.name == "emb-session" })
        XCTAssertNil(sessionSpan.attributes.first { $0.key == "emb.user_session_termination_reason" })
    }

    func test_userSessionMetadata_isIncludedInEveryPartOfTheUserSession() throws {
        let userSessionId = EmbraceIdentifier.random

        // given a property and a persona tag of a user session
        storage.addMetadata(
            key: "prop", value: "value", type: .customProperty,
            lifespan: .userSession, lifespanId: userSessionId.stringValue
        )
        storage.addMetadata(
            key: "persona", value: "", type: .personaTag,
            lifespan: .userSession, lifespanId: userSessionId.stringValue
        )

        // when building the payloads of three consecutive parts of that user session
        for partIndex in 1...3 {
            let part = MockSession(
                id: .random,
                processId: ProcessIdentifier.current,
                state: partIndex == 2 ? .background : .foreground,
                traceId: TestConstants.traceId,
                spanId: TestConstants.spanId,
                startTime: Date(timeIntervalSince1970: TimeInterval(partIndex * 60)),
                endTime: Date(timeIntervalSince1970: TimeInterval(partIndex * 60 + 30)),
                userSessionId: userSessionId,
                userSessionPartIndex: partIndex
            )

            let payload = try XCTUnwrap(SessionPayloadBuilder.build(for: part, storage: storage))

            // then every part carries the same metadata
            XCTAssertEqual(payload.metadata.personas, ["persona"])

            let sessionSpan = try XCTUnwrap(payload.data["spans"]?.first { $0.name == "emb-session" })
            let property = sessionSpan.attributes.first { $0.key == "emb.properties.prop" }
            XCTAssertEqual(property?.value, "value")
        }
    }

    func test_userSessionMetadata_isNotIncludedInPartsOfOtherUserSessions() throws {
        let userSessionId = EmbraceIdentifier.random

        storage.addMetadata(
            key: "prop", value: "value", type: .customProperty,
            lifespan: .userSession, lifespanId: userSessionId.stringValue
        )
        storage.addMetadata(
            key: "persona", value: "", type: .personaTag,
            lifespan: .userSession, lifespanId: userSessionId.stringValue
        )

        // when building the payload of a part belonging to a different user session
        let part = MockSession(
            id: .random,
            processId: ProcessIdentifier.current,
            state: .foreground,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 60),
            userSessionId: .random,
            userSessionPartIndex: 1
        )
        let payload = try XCTUnwrap(SessionPayloadBuilder.build(for: part, storage: storage))

        // then none of the metadata is included
        XCTAssertEqual(payload.metadata.personas, [])

        let sessionSpan = try XCTUnwrap(payload.data["spans"]?.first { $0.name == "emb-session" })
        XCTAssertNil(sessionSpan.attributes.first { $0.key == "emb.properties.prop" })
    }

    func test_experiments_areASessionSpanAttribute() throws {
        // given experiments stored for the session's process
        storage.addRequiredResources([SpanSemantics.keyExperiments: "e:exp:A:1000000"])

        // when building a session payload
        let payload = try XCTUnwrap(SessionPayloadBuilder.build(for: sessionRecord, storage: storage))

        // then the session span carries them as an attribute
        XCTAssertEqual(sessionSpanAttribute(in: payload), "e:exp:A:1000000")
    }

    /// The value is exempt from the standard attribute value length limit.
    func test_experiments_longValueSurvivesIntact() throws {
        // given an experiments value longer than the attribute value length limit
        let value = String(repeating: "a", count: 2000)
        storage.addRequiredResources([SpanSemantics.keyExperiments: value])

        // when building a session payload
        let payload = try XCTUnwrap(SessionPayloadBuilder.build(for: sessionRecord, storage: storage))

        // then the value survives untouched
        XCTAssertEqual(sessionSpanAttribute(in: payload), value)
    }

    func test_experiments_fromAnotherProcess_areNotIncluded() throws {
        // given experiments that belong to another process
        storage.addRequiredResources(
            [SpanSemantics.keyExperiments: "e:other::1"],
            processId: EmbraceIdentifier.random
        )

        // when building a session payload
        let payload = try XCTUnwrap(SessionPayloadBuilder.build(for: sessionRecord, storage: storage))

        // then this session's span doesn't carry them
        XCTAssertNil(sessionSpanAttribute(in: payload))
    }

    /// Experiments are stored as a required resource only so a later process can read them back. They
    /// must never be reported in the resource block.
    func test_experiments_areNeverInTheResourceBlock() throws {
        // given experiments stored for the session's process
        storage.addRequiredResources([SpanSemantics.keyExperiments: "e:exp:A:1000000"])

        // when building a session payload
        let payload = try XCTUnwrap(SessionPayloadBuilder.build(for: sessionRecord, storage: storage))

        // then they are absent from the resource block
        let resource = try encodedResource(from: payload)
        XCTAssertNil(resource[SpanSemantics.keyExperiments])
    }

    /// Only the session span carries the attribute; the other spans in the payload are untouched.
    func test_experiments_areOnlyOnTheSessionSpan() throws {
        // given experiments stored for the session's process, and another span in the session
        storage.addRequiredResources([SpanSemantics.keyExperiments: "e:exp:A:1000000"])

        storage.upsertSpan(
            MockSpan(
                id: .randomSpanId(),
                traceId: TestConstants.traceId,
                parentSpanId: nil,
                name: "other-span",
                type: .performance,
                status: .ok,
                startTime: Date(timeIntervalSince1970: 10),
                endTime: Date(timeIntervalSince1970: 20),
                events: [],
                links: [],
                sessionId: TestConstants.sessionId,
                processId: ProcessIdentifier.current,
                attributes: [:]
            )
        )

        // when building a session payload
        let payload = try XCTUnwrap(SessionPayloadBuilder.build(for: sessionRecord, storage: storage))

        // then only the session span has the attribute
        let others = payload.data["spans"]?.filter { $0.name != "emb-session" } ?? []
        XCTAssertFalse(others.isEmpty)
        for span in others {
            XCTAssertNil(span.attributes.first { $0.key == SpanSemantics.keyExperiments })
        }
    }
}

extension SessionPayloadBuilderTests {
    fileprivate func sessionSpanAttribute(in payload: PayloadEnvelope<[SpanPayload]>) -> String? {
        let sessionSpan = payload.data["spans"]?.first { $0.name == "emb-session" }
        return sessionSpan?.attributes.first { $0.key == SpanSemantics.keyExperiments }?.value
    }

    fileprivate func encodedResource(from payload: PayloadEnvelope<[SpanPayload]>) throws -> [String: Any] {
        let jsonData = try JSONEncoder().encode(payload)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any])
        return try XCTUnwrap(json["resource"] as? [String: Any])
    }
}
