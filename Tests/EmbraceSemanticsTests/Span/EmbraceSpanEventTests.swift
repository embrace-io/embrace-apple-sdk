//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceSemantics

class EmbraceSpanEventTests: XCTestCase {

    func test_init() {
        // give some event data
        let name = "test"
        let type = EmbraceType.performance
        let timestamp = Date()
        let attributes = ["key": "value"]

        // when creating a span event with it
        let event = EmbraceSpanEvent(name: name, type: type, timestamp: timestamp, attributes: attributes)

        // then the event is created correctly
        XCTAssertEqual(event.name, name)
        XCTAssertEqual(event.type, type)
        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertEqual(event.attributes["key"], "value")
        XCTAssertEqual(event.attributes["emb.type"], "perf")
        XCTAssertEqual(event.attributes.count, 2)
    }

    func test_init_embTypeAttributeCollision() {
        // give some event data with attributes that have a forced emb.type
        let name = "test"
        let type = EmbraceType.performance
        let timestamp = Date()
        let attributes = ["key": "value", "emb.type": "test"]

        // when creating a span event with it
        let event = EmbraceSpanEvent(name: name, type: type, timestamp: timestamp, attributes: attributes)

        // then the event is created correctly
        XCTAssertEqual(event.name, name)
        XCTAssertEqual(event.type, type)
        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertEqual(event.attributes["key"], "value")
        XCTAssertEqual(event.attributes["emb.type"], "perf")
        XCTAssertEqual(event.attributes.count, 2)
    }

    func test_init_noType() {
        // give some event data
        let name = "test"
        let timestamp = Date()
        let attributes = ["key": "value"]

        // when creating a span event with it and no type
        let event = EmbraceSpanEvent(name: name, type: nil, timestamp: timestamp, attributes: attributes)

        // then the event is created correctly
        XCTAssertEqual(event.name, name)
        XCTAssertNil(event.type)
        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertEqual(event.attributes, attributes)
    }
}
