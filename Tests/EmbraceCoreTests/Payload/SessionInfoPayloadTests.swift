//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
import EmbraceStorage
import EmbraceCommon

final class SessionInfoPayloadTests: XCTestCase {

    func test_init_setsPropertiesCorrectly() {

        let sessionId = SessionIdentifier.random
        let record = SessionRecord(
            id: sessionId,
            state: .foreground,
            processId: .current,
            traceId: .random(),
            spanId: .random(),
            startTime: Date(),
            endTime: Date(timeIntervalSinceNow: 2),
            lastHeartbeatTime: Date(timeIntervalSinceNow: 1.5) )

        let metadata = [
            MetadataRecord(
                key: "foo",
                value: .string("bar"),
                type: .customProperty,
                lifespan: .session, lifespanId: sessionId.toString, collectedAt: Date()
            ) ]

        let counter = 1
        let sessionInfoPayload = SessionInfoPayload(from: record, metadata: metadata, counter: counter)

        // Assert
        XCTAssertEqual(sessionInfoPayload.sessionId, record.id)
        XCTAssertEqual(sessionInfoPayload.startTime, record.startTime.millisecondsSince1970Truncated)
        XCTAssertEqual(sessionInfoPayload.endTime, record.endTime?.millisecondsSince1970Truncated)
        XCTAssertEqual(sessionInfoPayload.lastHeartbeatTime, record.lastHeartbeatTime.millisecondsSince1970Truncated)
        XCTAssertEqual(sessionInfoPayload.appState, record.state)
        XCTAssertEqual(sessionInfoPayload.sessionType, "en")
        XCTAssertEqual(sessionInfoPayload.counter, counter)
        XCTAssertEqual(sessionInfoPayload.appTerminated, record.appTerminated)
        XCTAssertEqual(sessionInfoPayload.cleanExit, record.cleanExit)
        XCTAssertEqual(sessionInfoPayload.coldStart, record.coldStart)
        XCTAssertEqual(sessionInfoPayload.properties.count, metadata.count)
        XCTAssertEqual(sessionInfoPayload.properties, ["foo": "bar"])
    }
}
