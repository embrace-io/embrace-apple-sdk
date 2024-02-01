//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest
@testable import EmbraceCore
@testable import EmbraceOTel
import OpenTelemetryApi

// swiftlint:disable force_cast

class SpanPayloadTests: XCTestCase {

    var testAttributes: [String: AttributeValue] {
        return [
            "bool": .bool(true),
            "double": .double(123.456),
            "int": .int(123456),
            "string": .string("test")
        ]
    }

    var testSpan: SpanData {
        return SpanData(
            traceId: TraceId.random(),
            spanId: SpanId.random(),
            parentSpanId: SpanId.random(),
            name: "test-span",
            kind: .internal,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 60),
            attributes: testAttributes,
            events: [
                RecordingSpanEvent(
                    name: "test-span-event",
                    timestamp: Date(timeIntervalSince1970: 20),
                    attributes: testAttributes
                )
            ],
            links: [
                RecordingSpanLink(
                    traceId: TraceId.random(),
                    spanId: SpanId.random(),
                    attributes: testAttributes
                )
            ],
            status: .ok
        )
    }

    func testAttributes(_ attributes: [String: Any]) {
        XCTAssertEqual(attributes["bool"] as! Bool, true)
        XCTAssertEqual(attributes["double"] as! Double, 123.456)
        XCTAssertEqual(attributes["int"] as! Int, 123456)
        XCTAssertEqual(attributes["string"] as! String, "test")
    }

    func test_properties() {
        // given a span data
        let span = testSpan

        // when creating a payload
        let payload = SpanPayload(from: span)

        // then the properties are correctly set
        XCTAssertEqual(payload.traceId, span.traceId.hexString)
        XCTAssertEqual(payload.spanId, span.spanId.hexString)
        XCTAssertEqual(payload.parentSpanId, span.parentSpanId?.hexString)
        XCTAssertEqual(payload.name, span.name)
        XCTAssertEqual(payload.status, span.status.name)
        XCTAssertEqual(payload.startTime, span.startTime.nanosecondsSince1970Truncated)
        XCTAssertEqual(payload.endTime, span.endTime?.nanosecondsSince1970Truncated)

        // attributes
        testAttributes(payload.attributes)

        // events
        XCTAssertEqual(payload.events.count, 1)
        XCTAssertEqual(payload.events[0].name, span.events[0].name)
        XCTAssertEqual(payload.events[0].timestamp, span.events[0].timestamp.nanosecondsSince1970Truncated)
        testAttributes(payload.events[0].attributes)

        // links
        XCTAssertEqual(payload.links.count, 1)
        XCTAssertEqual(payload.links[0].traceId, span.links[0].traceId.hexString)
        XCTAssertEqual(payload.links[0].spanId, span.links[0].spanId.hexString)
        testAttributes(payload.links[0].attributes)
    }

    func test_jsonKeys() throws {
        // given a span data
        let span = testSpan

        // when serializing
        let payload = SpanPayload(from: span)
        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        // then the payload has all the necessary keys
        XCTAssertNotNil(json["trace_id"])
        XCTAssertNotNil(json["span_id"])
        XCTAssertNotNil(json["parent_span_id"])
        XCTAssertNotNil(json["name"])
        XCTAssertNotNil(json["status"])
        XCTAssertNotNil(json["start_time_unix_nano"])
        XCTAssertNotNil(json["end_time_unix_nano"])
        XCTAssertNotNil(json["attributes"])
        XCTAssertNotNil(json["events"])
        XCTAssertNotNil(json["links"])

        // attributes
        let attributes = json["attributes"] as! [String: Any]
        testAttributes(attributes)

        // events
        let events = json["events"] as! [[String: Any]]
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0]["name"])
        XCTAssertNotNil(events[0]["time_unix_nano"])
        testAttributes(events[0]["attributes"] as! [String: Any])

        // links
        let links = json["links"] as! [[String: Any]]
        XCTAssertEqual(links.count, 1)
        XCTAssertNotNil(links[0]["trace_id"])
        XCTAssertNotNil(links[0]["span_id"])
        testAttributes(links[0]["attributes"] as! [String: Any])
    }

    func test_endTime() throws {
        // given a span data
        let span = testSpan

        // when creating a payload with a given end time
        let now = Date()
        let payload = SpanPayload(from: span, endTime: now)

        // then the correct end time is used
        XCTAssertEqual(payload.endTime, now.nanosecondsSince1970Truncated)
    }
}

// swiftlint:enable force_cast
