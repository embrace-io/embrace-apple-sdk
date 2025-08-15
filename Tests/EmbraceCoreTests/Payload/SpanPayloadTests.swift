//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import XCTest
import TestSupport
import EmbraceSemantics
@testable import EmbraceCore
@testable import EmbraceOTelInternal
@testable import OpenTelemetrySdk

// swiftlint:disable force_cast

class SpanPayloadTests: XCTestCase {

    var testAttributes: [String: String] {
        return [
            "bool": "true",
            "double": "123.456",
            "int": "123456",
            "string": "test"
        ]
    }

    var testSpan: EmbraceSpan {
        return MockSpan(
            id: SpanId.random().hexString,
            traceId: TraceId.random().hexString,
            parentSpanId: SpanId.random().hexString,
            name: "test-span",
            type: .performance,
            status: .ok,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 60),
            events: [
                EmbraceSpanEvent(
                    name: "test-span-event",
                    timestamp: Date(timeIntervalSince1970: 20),
                    attributes: testAttributes
                )
            ],
            links: [
                EmbraceSpanLink(
                    spanId: SpanId.random().hexString,
                    traceId: TraceId.random().hexString,
                    attributes: testAttributes)
            ],
            sessionId: TestConstants.sessionId,
            processId: TestConstants.processId,
            attributes: testAttributes)
    }

    func testAttributes(_ attributes: [Attribute]) {
        let boolAttribute = attributes.first { $0.key == "bool" }
        XCTAssertEqual(boolAttribute!.value, "true")

        let doubleAttribute = attributes.first { $0.key == "double" }
        XCTAssertEqual(doubleAttribute!.value, "123.456")

        let intAttribute = attributes.first { $0.key == "int" }
        XCTAssertEqual(intAttribute!.value, "123456")

        let stringAttribute = attributes.first { $0.key == "string" }
        XCTAssertEqual(stringAttribute!.value, "test")
    }

    func testJSONAttributes(_ attributes: [[String: Any]]) {

        var count = 0
        for keyValue in attributes {
            if keyValue["key"] as! String == "bool" {
                XCTAssertEqual(keyValue["value"] as! String, "true")
                count += 1

            } else if keyValue["key"] as! String == "double" {
                XCTAssertEqual(keyValue["value"] as! String, "123.456")
                count += 1

            } else if keyValue["key"] as! String == "int" {
                XCTAssertEqual(keyValue["value"] as! String, "123456")
                count += 1

            } else if keyValue["key"] as! String == "string" {
                XCTAssertEqual(keyValue["value"] as! String, "test")
                count += 1
            }
        }

        XCTAssertEqual(count, 4)
    }

    func test_properties() {
        // given a span data
        let span = testSpan

        // when creating a payload
        let payload = SpanPayload(from: span)

        // then the properties are correctly set
        XCTAssertEqual(payload.traceId, span.context.traceId)
        XCTAssertEqual(payload.spanId, span.context.spanId)
        XCTAssertEqual(payload.parentSpanId, span.parentSpanId)
        XCTAssertEqual(payload.name, span.name)
        XCTAssertEqual(payload.status, span.status.name)
        XCTAssertEqual(payload.startTime, span.startTime.nanosecondsSince1970Truncated)
        XCTAssertEqual(payload.endTime, span.endTime!.nanosecondsSince1970Truncated)

        // attributes
        testAttributes(payload.attributes)

        // events
        XCTAssertEqual(payload.events.count, 1)
        XCTAssertEqual(payload.events[0].name, span.events[0].name)
        XCTAssertEqual(payload.events[0].timestamp, span.events[0].timestamp.nanosecondsSince1970Truncated)
        testAttributes(payload.events[0].attributes)

        // links
        XCTAssertEqual(payload.links.count, 1)
        XCTAssertEqual(payload.links[0].traceId, span.links[0].context.traceId)
        XCTAssertEqual(payload.links[0].spanId, span.links[0].context.spanId)
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
        let attributes = json["attributes"] as! [[String: Any]]
        testJSONAttributes(attributes)

        // events
        let events = json["events"] as! [[String: Any]]
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0]["name"])
        XCTAssertNotNil(events[0]["time_unix_nano"])
        testJSONAttributes(events[0]["attributes"] as! [[String: Any]])

        // links
        let links = json["links"] as! [[String: Any]]
        XCTAssertEqual(links.count, 1)
        XCTAssertNotNil(links[0]["trace_id"])
        XCTAssertNotNil(links[0]["span_id"])
        testJSONAttributes(links[0]["attributes"] as! [[String: Any]])
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

