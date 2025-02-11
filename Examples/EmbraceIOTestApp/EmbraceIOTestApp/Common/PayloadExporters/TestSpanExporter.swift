//
//  TestSpanExporter.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import OpenTelemetrySdk

@Observable class TestSpanExporter: SpanExporter {
    /// Perform actions that would trigger a span export and monitor changes on this property. When `state` is set to `ready`, you can perform tests on the cached spans.
    var state: TestMockExporterState = .waiting

    private(set) var cachedExportedSpans: [String: [SpanData]] = [:]

    func clearAll(_ specific: String? = nil) {
        guard let specific = specific else {
            cachedExportedSpans.removeAll()
            state = .clear
            return
        }
        cachedExportedSpans[specific]?.removeAll()
    }

    func shutdown(explicitTimeout: TimeInterval?) {}

    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        return .success
    }

    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        spans.forEach {
            if cachedExportedSpans[$0.name] == nil {
                cachedExportedSpans[$0.name] = []
            }
            cachedExportedSpans[$0.name]?.append($0)
        }
        DispatchQueue.main.async { [weak self] in
            self?.state = .ready
        }

        NotificationCenter.default.post(name: NSNotification.Name("TestSpanExporter.SpansUpdated"), object: nil)

        return .success
    }

    // Will perform the provided test on the cached spans.
    /// `test`: The test to perform.
    /// `clearAfterTest`: By default all cached spans will be discarded after the test finishes. If you need to perform aditional tests on the same spans, set this parameter to `false`
    func performTest(_ test: PayloadTest, clearAfterTest: Bool = true) -> TestReport {
        state = .testing
        let testRelevantSpans = cachedExportedSpans[test.testRelevantSpanName] ?? []
        let result = test.test(spans: testRelevantSpans)
        if clearAfterTest {
            cachedExportedSpans.removeAll()
            state = .clear
        } else {
            state = .ready
        }

        return result
    }

}
