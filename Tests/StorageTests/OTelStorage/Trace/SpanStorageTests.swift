//
//  SpanStorageTests.swift
//  
//
//  Created by Austin Emmons on 7/31/23.
//

import XCTest

@testable import Storage
import EmbraceOTel

import OpenTelemetryApi
import OpenTelemetrySdk

import TestSupport

final class SpanStorageTests: XCTestCase {

    let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
    var dbURL: URL { tmpURL.appendingPathComponent("span_storage_tests.sqlite") }

    let otel = EmbraceOTel(spanProcessor: NoopSpanProcessor())

    override func setUpWithError() throws {
        if FileManager.default.fileExists(atPath: dbURL.path) {
            try! FileManager.default.removeItem(at: dbURL)
        }

        try? FileManager.default.createDirectory(at: tmpURL, withIntermediateDirectories: true)

    }

    override func tearDownWithError() throws {
//        try! FileManager.default.removeItem(at: tmpURL)
    }

    func test_insertEmbraceSpanData() throws {
        let storage = try SpanStorageSQL(fileURL: dbURL)
        try storage.createIfNecessary()

        let span = otel.buildSpan(name: "example.hello", type: EmbraceSemantics.SpanType.performance).startSpan() as! ReadableSpan
        let context = span.context
        try storage.add(entry: span.toSpanData())

        let spans = try storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans.first?.spanId, context.spanId)
        XCTAssertEqual(spans.first?.traceId, context.traceId)
        XCTAssertEqual(spans.first?.name, "example.hello")
        XCTAssertEqual(spans.first?.kind, .internal)
        XCTAssertEqual(spans.first?.attributes, [
            "emb.type": .string("performance")
        ])
    }

    func test_insertEmbraceSpanData_withAttributes() throws {
        let storage = try SpanStorageSQL(fileURL: dbURL)
        try storage.createIfNecessary()

        let span = otel.buildSpan(name: "example.hello", type: EmbraceSemantics.SpanType.performance)
            .setAttribute(key: "a", value: .string("hello"))
            .setAttribute(key: "b", value: .int(42))
            .setAttribute(key: "c", value: .double(23.2))
            .startSpan() as! ReadableSpan
        let context = span.context
        try storage.add(entry: span.toSpanData())

        // Then
        let spans = try storage.fetchAll()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans.first?.spanId, context.spanId)
        XCTAssertEqual(spans.first?.traceId, context.traceId)
        XCTAssertEqual(spans.first?.name, "example.hello")
        XCTAssertEqual(spans.first?.kind, .internal)
        XCTAssertEqual(spans.first?.attributes, [
            "a": .string("hello"),
            "b": .int(42),
            "c": .double(23.2),
            "emb.type": .string("performance")
        ])
    }

    @available(iOS 13.0, *)
    func test_performance_insertEmbraceSpanData() throws {
        let storage = try SpanStorageSQL(fileURL: dbURL)
        try storage.createIfNecessary()

        let spanDataEntries = (0..<1000).map { _ in
            let span = otel.buildSpan(name: "example.hello", type: EmbraceSemantics.SpanType.performance)
                .setAttribute(key: "a", value: .string("hello"))
                .setAttribute(key: "b", value: .int(42))
                .setAttribute(key: "c", value: .double(23.2))
                .startSpan() as! ReadableSpan

            return span.toSpanData()
        }

        try! storage.add(entries: spanDataEntries)
    }

}
