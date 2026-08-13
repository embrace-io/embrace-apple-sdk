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
}
