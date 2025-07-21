//
//  TestLogRecordExporter.swift
//  EmbraceIOTestApp
//
//

import OpenTelemetrySdk
import SwiftUI

@Observable class TestLogRecordExporter: LogRecordExporter {
    func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult { return .success }

    func shutdown(explicitTimeout: TimeInterval?) {}

    private(set) var cachedExportedLogs: [ReadableLogRecord] = []
    private(set) var latestExportedLogs: [ReadableLogRecord] = []

    func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        latestExportedLogs = logRecords
        logRecords.forEach { cachedExportedLogs.append($0) }
        NotificationCenter.default.post(name: NSNotification.Name("TestLogRecordExporter.LogsUpdated"), object: nil)
        return .success
    }

    func clearAll(_ specifics: [String]) {
        specifics.forEach { clearAll($0) }
    }

    func clearAll(_ specific: String? = nil) {
        guard let specific = specific else {
            cachedExportedLogs.removeAll()
            return
        }

        cachedExportedLogs.removeAll { $0.body?.description == specific }
    }
}
