//
//  SpanStorageTests.swift
//  
//
//  Created by Austin Emmons on 7/31/23.
//

import XCTest

@testable import embrace_ios_core
import OpenTelemetryApi

final class SpanStorageTests: XCTestCase {

    let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
    var dbURL: URL { tmpURL.appendingPathComponent("span_storage_tests.sqlite") }

    override func setUpWithError() throws {
        if FileManager.default.fileExists(atPath: dbURL.path) {
            try! FileManager.default.removeItem(at: dbURL)
        }

        try? FileManager.default.createDirectory(at: tmpURL, withIntermediateDirectories: true)

    }

    override func tearDownWithError() throws {
        try! FileManager.default.removeItem(at: tmpURL)
    }

    func test_insertEmbraceSpanData() throws {
        let storage = try SpanStorage(fileURL: dbURL)
        try storage.createIfNecessary()

        let spanId = SpanId.random()
        let traceId = TraceId.random()
        let span = EmbraceSpan(
            context: .create(
                traceId: traceId,
                spanId: spanId,
                traceFlags: .init(),
                traceState: .init()),
            name: "example.hello",
            startTime: Date())

        try storage.add(spanData: span.toSpanData())

        let spans = try storage.fetch()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans.first?.spanId, spanId)
        XCTAssertEqual(spans.first?.traceId, traceId)
        XCTAssertEqual(spans.first?.name, "example.hello")
        XCTAssertEqual(spans.first?.kind, .client)
    }

    func test_insertEmbraceSpanData_withAttributes() throws {
        let storage = try SpanStorage(fileURL: dbURL)
        try storage.createIfNecessary()

        let spanId = SpanId.random()
        let traceId = TraceId.random()
        let span = EmbraceSpan(
            context: .create(
                traceId: traceId,
                spanId: spanId,
                traceFlags: .init(),
                traceState: .init()),
            name: "example.hello",
            startTime: Date()
        )

        span.setAttribute(key: "a", value: .string("hello"))
        span.setAttribute(key: "b", value: .int(42))
        span.setAttribute(key: "c", value: .double(23.2))

        try storage.add(spanData: span.toSpanData())

        let spans = try storage.fetch()
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans.first?.spanId, spanId)
        XCTAssertEqual(spans.first?.traceId, traceId)
        XCTAssertEqual(spans.first?.name, "example.hello")
        XCTAssertEqual(spans.first?.kind, .client)
        XCTAssertEqual(spans.first?.attributes, [
            "a" : .string("hello"),
            "b" : .int(42),
            "c" : .double(23.2)
        ])
    }

    @available(iOS 13.0, *)
    func test_performance_insertEmbraceSpanData() throws {
        let storage = try SpanStorage(fileURL: dbURL)
        try storage.createIfNecessary()

        let spanDataEntries = (0..<1000).map { _ in
            EmbraceSpan(
                context: .create(
                    traceId: .random(),
                    spanId: .random(),
                    traceFlags: .init(),
                    traceState: .init()),
                name: "example.hello",
                startTime: Date())
            .toSpanData()
        }

        try! storage.add(entries: spanDataEntries)
    }

}
