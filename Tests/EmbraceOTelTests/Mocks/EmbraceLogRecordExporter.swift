//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetrySdk
@testable import EmbraceOTel

class SpyEmbraceLogRecordExporter: EmbraceLogRecordExporter {
    var stubbedExportResponse: ExportResult?
    var didCallExport: Bool = false
    var exportLogRecordsReceivedParameter: [ReadableLogRecord] = []
    func export(logRecords: [ReadableLogRecord]) -> ExportResult {
        didCallExport = true
        exportLogRecordsReceivedParameter = logRecords
        return stubbedExportResponse!
    }

    var didCallShutdown: Bool = false
    func shutdown() {
        didCallShutdown = true
    }

    var stubbedForceFlushResponse: ExportResult?
    var didCallForceFlush: Bool = false
    func forceFlush() -> ExportResult {
        didCallForceFlush = true
        return stubbedForceFlushResponse!
    }
}
