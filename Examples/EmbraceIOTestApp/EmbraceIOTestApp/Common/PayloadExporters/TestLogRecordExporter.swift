//
//  TestLogRecordExporter.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import OpenTelemetrySdk

@Observable class TestLogRecordExporter: LogRecordExporter {
    func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult { return .success }

    func shutdown(explicitTimeout: TimeInterval?) {}

    var cachedExportedLogs: [ReadableLogRecord] = []

    func export(logRecords: [ReadableLogRecord], explicitTimeout : TimeInterval?) -> ExportResult {
        logRecords.forEach { cachedExportedLogs.append($0) }
        NotificationCenter.default.post(name: NSNotification.Name("TestLogRecordExporter.LogsUpdated"), object: nil)
        return .success
    }

    func clearAll(_ specific: String? = nil) {
        guard let specific = specific else {
            cachedExportedLogs.removeAll()
            return
        }

        cachedExportedLogs.removeAll { $0.body?.description == specific }
    }
}
