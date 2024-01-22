//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
@testable import EmbraceOTel
import OpenTelemetryApi
import EmbraceStorage

final class StorageSpanExporterTests: XCTestCase {
    func test_DB_prevents_already_closed_spans_from_being_modified() throws {
        // Given
        let storage = try EmbraceStorage.createInMemoryDb()
        let exporter = StorageSpanExporter(options: .init(storage: storage))
        let startTime = Date()
        let updatedStartTime = startTime.addingTimeInterval(1000)
        let endTime = startTime.addingTimeInterval(2000)

        let alreadyClosedSpanData = SpanData(traceId: .random(),
                                             spanId: .random(),
                                             parentSpanId: .random(),
                                             name: "target_span",
                                             kind: .internal,
                                             startTime: startTime,
                                             endTime: endTime)

        /// Same data as spanDataTested but without endTime to make the DB update the existing entry instead of adding a new one.
        let closedSpanUpdatedData = SpanData(traceId: alreadyClosedSpanData.traceId,
                                             spanId: alreadyClosedSpanData.spanId,
                                             parentSpanId: alreadyClosedSpanData.parentSpanId,
                                             name: alreadyClosedSpanData.name,
                                             kind: alreadyClosedSpanData.kind,
                                             startTime: updatedStartTime,
                                             endTime: nil)

        /// This is a span used as control to make sure open spans update as normal.
        let openSpanData = SpanData(traceId: .random(),
                                    spanId: .random(),
                                    parentSpanId: .random(),
                                    name: "control_span",
                                    kind: .internal,
                                    startTime: startTime,
                                    endTime: nil)

        let openSpanUpdatedData = SpanData(traceId: openSpanData.traceId,
                                           spanId: openSpanData.spanId,
                                           parentSpanId: openSpanData.parentSpanId,
                                           name: openSpanData.name,
                                           kind: openSpanData.kind,
                                           startTime: openSpanData.startTime,
                                           endTime: endTime)

        // When spans are exported
        exporter.export(spans: [alreadyClosedSpanData])
        exporter.export(spans: [openSpanData])
        exporter.export(spans: [openSpanUpdatedData])
        exporter.export(spans: [closedSpanUpdatedData])

        // The open "control" span should have been closed.
        let exportedSpans: [SpanRecord] = try storage.fetchAll()
        XCTAssertTrue(exportedSpans.count == 2)

        let controlSpan = exportedSpans.first { span in
            span.id == openSpanData.spanId.hexString
        }

        XCTAssertNotNil(controlSpan)
        XCTAssertTrue(controlSpan!.name == "control_span")
        /// dates lose some precision when stored in DB so we have to compare with a tolerance.
        XCTAssertEqual(controlSpan!.startTime.timeIntervalSince1970, startTime.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertNotNil(controlSpan!.endTime)

        // The already closed span should not have been modified.
        let targetSpan = exportedSpans.first { span in
            span.id == alreadyClosedSpanData.spanId.hexString
        }

        XCTAssertNotNil(targetSpan)
        XCTAssertTrue(targetSpan!.name == "target_span")
        /// Updating already closed spans is not allowed so the original start time should be still present on the stored span.
        XCTAssertEqual(targetSpan!.startTime.timeIntervalSince1970, startTime.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertNotNil(targetSpan!.endTime)
    }
}
