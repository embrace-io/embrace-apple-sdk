//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

@testable import EmbraceOTelInternal
import OpenTelemetrySdk
import Foundation

class SpyEmbraceLogRecordExporter: LogRecordExporter {
    var exportLogRecordsReceivedParameter: [ReadableLogRecord] = []
    var stubbedExportResponse: ExportResult?
    var didCallExport: Bool = false
    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        didCallExport = true
        exportLogRecordsReceivedParameter = logRecords
        return stubbedExportResponse!
    }

    var didCallShutdown: Bool = false
    func shutdown(explicitTimeout: TimeInterval?) {
        didCallShutdown = true
    }

    var stubbedForceFlushResponse: ExportResult?
    var didCallForceFlush: Bool = false
    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        didCallForceFlush = true
        return stubbedForceFlushResponse!
    }
}
