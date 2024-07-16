//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
@testable import EmbraceOTelInternal
@testable import OpenTelemetrySdk
import OpenTelemetryApi
import EmbraceStorageInternal

final class StorageSpanExporterTests: XCTestCase {
    func test_DB_preventsClosedSpan_fromUpdatingEndTime() throws {
        // Given
        let storage = try EmbraceStorage.createInMemoryDb()
        let exporter = StorageSpanExporter(options: .init(storage: storage))

        let traceId = TraceId.random()
        let spanId = SpanId.random()
        let name = "target_span"

        let startTime = Date()
        let endTime = startTime.addingTimeInterval(2000)

        let closedSpanData = SpanData(traceId: traceId,
                                             spanId: spanId,
                                             parentSpanId: nil,
                                             name: name,
                                             kind: .internal,
                                             startTime: startTime,
                                             endTime: endTime,
                                             hasEnded: true )

        let updated_closedSpanData = SpanData(traceId: traceId,
                                             spanId: spanId,
                                             parentSpanId: nil,
                                             name: name,
                                             kind: .internal,
                                             startTime: startTime.addingTimeInterval(1000),
                                             endTime: startTime.addingTimeInterval(-10000),
                                             hasEnded: false )

        // When spans are exported
        exporter.export(spans: [closedSpanData])
        exporter.export(spans: [updated_closedSpanData])

        let exportedSpans: [SpanRecord] = try storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 1)

        let exportedSpan = try XCTUnwrap(exportedSpans.first)
        XCTAssertEqual(exportedSpan.traceId, traceId.hexString)
        XCTAssertEqual(exportedSpan.id, spanId.hexString)
        XCTAssertEqual(exportedSpan.endTime!.timeIntervalSince1970, endTime.timeIntervalSince1970, accuracy: 0.01)
    }

    func test_DB_allowsOpenSpan_toUpdateAttributes() throws {
        // Given
        let storage = try EmbraceStorage.createInMemoryDb()
        let exporter = StorageSpanExporter(options: .init(storage: storage))

        let traceId = TraceId.random()
        let spanId = SpanId.random()
        let name = "target_span"

        let startTime = Date()

        let openSpanData = SpanData(traceId: traceId,
                                    spanId: spanId,
                                    parentSpanId: nil,
                                    name: name,
                                    kind: .internal,
                                    startTime: startTime,
                                    attributes: ["foo": .string("bar")],
                                    endTime: Date(),
                                    hasEnded: false )

        let updated_openSpanData = SpanData(traceId: traceId,
                                             spanId: spanId,
                                             parentSpanId: nil,
                                             name: name,
                                             kind: .internal,
                                             startTime: startTime.addingTimeInterval(1000),
                                             attributes: ["foo": .string("baz")],
                                             endTime: Date(),
                                             hasEnded: false )

        // When spans are exported
        exporter.export(spans: [openSpanData])
        exporter.export(spans: [updated_openSpanData])

        let exportedSpans: [SpanRecord] = try storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 1)

        let exportedSpan = exportedSpans.first
        XCTAssertEqual(exportedSpan?.traceId, traceId.hexString)
        XCTAssertEqual(exportedSpan?.id, spanId.hexString)

        let spanData = try JSONDecoder().decode(SpanData.self, from: exportedSpan!.data)
        XCTAssertEqual(spanData.attributes, ["foo": .string("baz")])
    }
}
