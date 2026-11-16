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

    // MARK: - Slow callbacks

    /// The session span is read from storage, so a session part that never ended cleanly still reports its slow calls.
    func test_slowCallbacks_storedOnTheSessionSpan_areSessionSpanAttributes() throws {
        // given a stored session span that never ended, with slow-call attributes and another attribute
        storage.upsertSpan(
            MockSpan(
                id: TestConstants.spanId,
                traceId: TestConstants.traceId,
                name: "emb-session",
                type: .session,
                startTime: Date(timeIntervalSince1970: 0),
                sessionId: TestConstants.sessionId,
                processId: ProcessIdentifier.current,
                attributes: [
                    "emb.private.slow_callback.network_span_parent_provider.count": "3",
                    "emb.private.slow_callback.network_span_parent_provider.max_ms": "42",
                    "emb.private.other": "value"
                ]
            )
        )

        // when building a session payload
        let payload = try XCTUnwrap(SessionPayloadBuilder.build(for: sessionRecord, storage: storage))

        // then the session span carries the slow-call attributes, and only those
        let sessionSpan = try XCTUnwrap(payload.data["spans"]?.first { $0.name == "emb-session" })
        func attribute(_ key: String) -> String? {
            sessionSpan.attributes.first { $0.key == key }?.value
        }
        XCTAssertEqual(attribute("emb.private.slow_callback.network_span_parent_provider.count"), "3")
        XCTAssertEqual(attribute("emb.private.slow_callback.network_span_parent_provider.max_ms"), "42")
        XCTAssertNil(attribute("emb.private.other"))
    }

    func test_slowCallbacks_noneRecorded_noAttributes() throws {
        // given a stored session span without slow calls
        storage.upsertSpan(
            MockSpan(
                id: TestConstants.spanId,
                traceId: TestConstants.traceId,
                name: "emb-session",
                type: .session,
                startTime: Date(timeIntervalSince1970: 0),
                sessionId: TestConstants.sessionId,
                processId: ProcessIdentifier.current
            )
        )

        // when building a session payload
        let payload = try XCTUnwrap(SessionPayloadBuilder.build(for: sessionRecord, storage: storage))

        // then the session span has no slow-call attributes
        let sessionSpan = try XCTUnwrap(payload.data["spans"]?.first { $0.name == "emb-session" })
        XCTAssertFalse(sessionSpan.attributes.contains { $0.key.hasPrefix("emb.private.slow_callback.") })
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
