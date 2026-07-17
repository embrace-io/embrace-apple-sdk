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

    func test_experiments_emittedAsRawAttribute_andExcludedFromResources() throws {
        // given a stored experiments required-resource for the session's process
        storage.addMetadata(
            key: ExperimentsSemantics.key,
            value: "e:abc1:A:1717459200000",
            type: .requiredResource,
            lifespan: .process,
            lifespanId: ProcessIdentifier.current.stringValue
        )

        // when building a session payload
        let payload = try XCTUnwrap(SessionPayloadBuilder.build(for: sessionRecord, storage: storage))

        // then the session span carries the raw `emb.experiments` attribute (no `emb.properties.` prefix)
        let sessionSpan = payload.data["spans"]?.first { $0.name == "emb-session" }
        let attribute = sessionSpan?.attributes.first { $0.key == ExperimentsSemantics.key }
        XCTAssertEqual(attribute?.value, "e:abc1:A:1717459200000")
        XCTAssertNil(sessionSpan?.attributes.first { $0.key == "emb.properties.\(ExperimentsSemantics.key)" })

        // and it is not present in the resource payload
        XCTAssertNil(payload.resource.additionalResources[ExperimentsSemantics.key])
    }
}
