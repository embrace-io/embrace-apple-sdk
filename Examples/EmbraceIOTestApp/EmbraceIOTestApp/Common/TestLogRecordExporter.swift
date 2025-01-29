//
//  TestLogRecordExporter.swift
//  EmbraceIOTestApp
//
//

import Foundation
import OpenTelemetrySdk

class TestLogRecordExporter: LogRecordExporter, ObservableObject {
    @Published var state: TestMockExporterState = .waiting

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

/*
 /// Perform actions that would trigger a span export and monitor changes on this property. When `state` is set to `ready`, you can perform tests on the cached spans.
 @Published var state: TestMockExporterState = .waiting

 var cachedExportedSpans: [OpenTelemetrySdk.SpanData] = []

 func clearAll() {
     cachedExportedSpans.removeAll()
     state = .clear
 }

 func shutdown(explicitTimeout: TimeInterval?) {}

 func flush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.SpanExporterResultCode {
     return .success
 }

 func export(spans: [OpenTelemetrySdk.SpanData], explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.SpanExporterResultCode {
     spans.forEach { cachedExportedSpans.append($0) }
     DispatchQueue.main.async { [weak self] in
         self?.state = .ready
     }
     return .success
 }

 // Will perform the provided test on the cached spans.
 /// `test`: The test to perform.
 /// `clearAfterTest`: By default all cached spans will be discarded after the test finishes. If you need to perform aditional tests on the same spans, set this parameter to `false`
 func performTest(_ test: PayloadTest, clearAfterTest: Bool = true) -> TestReport {
     state = .testing
     let result = test.test(spans:cachedExportedSpans)
     if clearAfterTest {
         cachedExportedSpans.removeAll()
         state = .clear
     } else {
         state = .ready
     }

     return result
 }
 */
