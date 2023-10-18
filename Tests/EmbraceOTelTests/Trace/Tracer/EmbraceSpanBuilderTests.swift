//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceOTel
import OpenTelemetryApi

final class EmbraceSpanBuilderTests: XCTestCase {

    func test_buildSpan_startsCorrectSpanType() throws {
        let builder = EmbraceSpanBuilder(spanName: "example", processor: .noop)

        let span = builder.startSpan()
        XCTAssertTrue(span is RecordingSpan)
    }

    func test_buildSpan_withAttributes_appendsAttributes() throws {
        let builder = EmbraceSpanBuilder(spanName: "example", processor: .noop)

        let span = builder
            .setAttribute(key: "foo", value: "bar")
            .setAttribute(key: "baz", value: "buzz")
            .startSpan()

        if let span = span as? RecordingSpan {
            XCTAssertEqual(span.attributes, [
                "foo": .string("bar"),
                "baz": .string("buzz")
            ])
        } else {
            XCTFail("Builder did not return a RecordingSpan")
        }
    }

    func test_buildSpan_withLink_appendsLinks() throws {
        let builder = EmbraceSpanBuilder(spanName: "example", processor: .noop)
        let linkedSpanContextWithAttributes = SpanContext.create()
        let linkedSpanContextNoAttributes = SpanContext.create()

        let span = builder
            .addLink(spanContext: linkedSpanContextWithAttributes, attributes: ["example": .string("test")])
            .addLink(spanContext: linkedSpanContextNoAttributes)
            .startSpan()

        if let span = span as? RecordingSpan {
            XCTAssertEqual(span.links.count, 2)
            let linkWithAttributes = span.links.first
            XCTAssertEqual(linkWithAttributes?.context, linkedSpanContextWithAttributes)
            XCTAssertEqual(linkWithAttributes?.attributes, ["example": .string("test")])

            let linkNoAttributes = span.links.last
            XCTAssertEqual(linkNoAttributes?.context, linkedSpanContextNoAttributes)
            XCTAssertEqual(linkNoAttributes?.attributes, [:])

        } else {
            XCTFail("Builder did not return a RecordingSpan")
        }
    }

    func test_buildSpan_withParentContext_setsParent() throws {
        let builder = EmbraceSpanBuilder(spanName: "example", processor: .noop)
        let parentContext = SpanContext.create()

        let span = builder
            .setParent(parentContext)
            .startSpan()

        if let span = span as? RecordingSpan {
            XCTAssertEqual(span.parentContext, parentContext)
        } else {
            XCTFail("Builder did not return a RecordingSpan")
        }
    }

    func test_buildSpan_withParent_setsParent() throws {
        let parentSpan = EmbraceSpanBuilder(spanName: "parent-example", processor: .noop).startSpan()

        let span = EmbraceSpanBuilder(spanName: "example", processor: .noop)
            .setParent(parentSpan)
            .startSpan()

        if let span = span as? RecordingSpan {
            XCTAssertEqual(span.parentContext, parentSpan.context)
        } else {
            XCTFail("Builder did not return a RecordingSpan")
        }
    }

    func test_buildSpan_withParent_withNoParent_doesNot_setParent() throws {
        let parentSpan = EmbraceSpanBuilder(spanName: "parent-example", processor: .noop).startSpan()

        let span = EmbraceSpanBuilder(spanName: "example", processor: .noop)
            .setParent(parentSpan)
            .setNoParent()
            .startSpan()

        if let span = span as? RecordingSpan {
            XCTAssertNil(span.parentContext)
        } else {
            XCTFail("Builder did not return a RecordingSpan")
        }
    }

    func test_buildSpan_setSpanKind_setsKind() throws {
        let span = EmbraceSpanBuilder(spanName: "example", processor: .noop)
            .setSpanKind(spanKind: .server)
            .startSpan()

        XCTAssertEqual(span.kind, .server)
    }

    func test_setStartTime_setsStartTime() throws {
        let startTime = Date().addingTimeInterval(-30)

        let span = EmbraceSpanBuilder(spanName: "example", processor: .noop)
            .setStartTime(time: startTime)
            .startSpan()

        if let span = span as? RecordingSpan {
            XCTAssertEqual(span.startTime, startTime)
        } else {
            XCTFail("Builder did not return a RecordingSpan")
        }
    }

    func test_setActive_setsAsActive() throws {

        let span = EmbraceSpanBuilder(spanName: "example", processor: .noop)
            .setActive(true)
            .startSpan()

        XCTAssertEqual(OpenTelemetry.instance.contextProvider.activeSpan?.context, span.context)
    }

}
