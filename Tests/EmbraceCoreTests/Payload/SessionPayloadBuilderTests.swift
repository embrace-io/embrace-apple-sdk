//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import EmbraceStorageInternal
import OpenTelemetryApi
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceOTelInternal
@testable import OpenTelemetrySdk

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

        // then the session span contains the correct session number
        let sessionSpan = payload?.data["spans"]?.first { $0.name == "emb-session" }
        let sessionNumberAttr = sessionSpan?.attributes.first { $0.key == "emb.session_number" }
        XCTAssertEqual(sessionNumberAttr?.value, "7")

        // and the MetadataRecord counter was NOT touched
        let resource = storage.fetchMetadata(
            key: SessionController.sessionNumberKey,
            type: .requiredResource,
            lifespan: .permanent
        )
        XCTAssertNil(resource)
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

        let spanData = SpanData(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            parentSpanId: nil,
            name: "other-span",
            kind: .internal,
            startTime: Date(timeIntervalSince1970: 10),
            attributes: [SpanSemantics.keyEmbraceType: .string(SpanType.performance.rawValue)],
            status: .ok,
            endTime: Date(timeIntervalSince1970: 20),
            hasEnded: true
        )
        storage.upsertSpan(
            id: spanData.spanId.hexString,
            name: spanData.name,
            traceId: TestConstants.traceId,
            type: .performance,
            data: try spanData.toJSON(),
            startTime: spanData.startTime,
            endTime: spanData.endTime
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
