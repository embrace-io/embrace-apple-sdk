//
//  TestLogRecordExporter.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import OpenTelemetrySdk

@Observable class TestLogRecordExporter: LogRecordExporter {
    var state: TestMockExporterState = .waiting

    func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult { return .success }

    func shutdown(explicitTimeout: TimeInterval?) {}

    var cachedExportedLogs: [ReadableLogRecord] = []

    func export(logRecords: [ReadableLogRecord], explicitTimeout : TimeInterval?) -> ExportResult {
        logRecords.forEach { cachedExportedLogs.append($0) }
        DispatchQueue.main.async { [weak self] in
            self?.state = .ready
        }
        return .success
    }

    func clearAll() {
        cachedExportedLogs.removeAll()
        state = .clear
    }

    // Will perform the provided test on the cached logs.
    /// `test`: The test to perform.
    /// `clearAfterTest`: By default all cached logs will be discarded after the test finishes. If you need to perform aditional tests on the same logs, set this parameter to `false`
    func performTest(_ test: PayloadTest, clearAfterTest: Bool = true) -> TestReport {
        state = .testing
        let result = test.test(logs:cachedExportedLogs)
        if clearAfterTest {
            cachedExportedLogs.removeAll()
            state = .clear
        } else {
            state = .ready
        }

        return result
    }
}
