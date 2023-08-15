//
//  EmbraceSpanBuilderTests.swift
//  
//
//  Created by Austin Emmons on 8/2/23.
//

import XCTest
import OpenTelemetryApi
@testable import embrace_ios_core

final class EmbraceSpanBuilderTests: XCTestCase {

    let builder = EmbraceSpanBuilder(spanName: "example")

    func test_startSpan_returnsEmbraceSpan() throws {
        let span = builder
            .setSpanKind(spanKind: .internal)
            .startSpan()

        XCTAssertEqual(span.name, "example")
        XCTAssertEqual(span.kind, SpanKind.internal)
        XCTAssertTrue(span.isRecording)
        XCTAssertTrue(span is EmbraceSpan)
    }

    func test_startSpan_withParent_returnsEmbraceSpan_withParent() throws {
        let parentBuilder = EmbraceSpanBuilder(spanName: "example_parent")
        let parentSpan = parentBuilder.startSpan()

        builder.setParent(parentSpan)

        guard let span = builder.startSpan() as? EmbraceSpan else {
            fatalError("Not an EmbraceSpan")
        }

        XCTAssertEqual(span.parentContext?.spanId, parentSpan.context.spanId)
    }

    func test_startSpan_withAttributes_setsAttributes() throws {
        builder.setAttribute(key: "test_bool", value: .bool(true))
        builder.setAttribute(key: "test_string", value: .string("hello"))

        guard let span = builder.startSpan() as? EmbraceSpan else {
            fatalError("Not an EmbraceSpan")
        }

        XCTAssertEqual(
            span.attributes, [
                "test_bool": .bool(true),
                "test_string": .string("hello")
            ] )
    }

    func test_startSpan_withLinks_addsLinks() throws {
        let traceId = TraceId.random()
        let spanId = SpanId.random()

        builder.addLink(.init(context: .create(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: TraceState())))

        guard let span = builder.startSpan() as? EmbraceSpan else {
            fatalError("Not an EmbraceSpan")
        }

        XCTAssertEqual(span.links.count, 1)
        let link = span.links.first!
        XCTAssertEqual(link.context.traceId, traceId)
        XCTAssertEqual(link.context.spanId, spanId)
    }
}
