//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

class DefaultEmbraceLogTests: XCTestCase {
    func test_init() {
        // when initializing a log
        let timestamp = Date(timeIntervalSince1970: 1)
        let log = DefaultEmbraceLog(
            id: "test",
            severity: .info,
            type: .message,
            timestamp: timestamp,
            body: "body",
            attributes: ["key1": "value1"],
            sessionId: TestConstants.sessionId,
            processId: TestConstants.processId
        )

        // then the values are stored correctly
        XCTAssertEqual(log.id, "test")
        XCTAssertEqual(log.severity, .info)
        XCTAssertEqual(log.type, .message)
        XCTAssertEqual(log.timestamp, timestamp)
        XCTAssertEqual(log.body, "body")
        XCTAssertEqual(log.attributes.count, 1)
        XCTAssertEqual(log.attributes["key1"] as! String, "value1")
        XCTAssertEqual(log.sessionId, TestConstants.sessionId)
        XCTAssertEqual(log.processId, TestConstants.processId)
    }
}
