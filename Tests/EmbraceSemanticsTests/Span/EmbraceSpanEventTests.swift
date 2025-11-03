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

        // when creating a span event with it
        let event = EmbraceSpanEvent(name: name, type: type, timestamp: timestamp, attributes: ["key": "value"])

        // then the event is created correctly
        XCTAssertEqual(event.name, name)
        XCTAssertEqual(event.type, type)
        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertEqual(event.attributes["key"] as! String, "value")
        XCTAssertEqual(event.attributes["emb.type"] as! String, "perf")
        XCTAssertEqual(event.attributes.count, 2)
    }

    func test_init_embTypeAttributeCollision() {
        // give some event data with attributes that have a forced emb.type
        let name = "test"
        let type = EmbraceType.performance
        let timestamp = Date()

        // when creating a span event with it
        let event = EmbraceSpanEvent(name: name, type: type, timestamp: timestamp, attributes: ["key": "value", "emb.type": "test"])

        // then the event is created correctly
        XCTAssertEqual(event.name, name)
        XCTAssertEqual(event.type, type)
        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertEqual(event.attributes["key"] as! String, "value")
        XCTAssertEqual(event.attributes["emb.type"] as! String, "perf")
        XCTAssertEqual(event.attributes.count, 2)
    }

    func test_init_noType() {
        // give some event data
        let name = "test"
        let timestamp = Date()

        // when creating a span event with it and no type
        let event = EmbraceSpanEvent(name: name, type: nil, timestamp: timestamp, attributes: ["key": "value"])

        // then the event is created correctly
        XCTAssertEqual(event.name, name)
        XCTAssertNil(event.type)
        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertEqual(event.attributes["key"] as! String, "value")
        XCTAssertEqual(event.attributes.count, 1)
    }
}
