//
//  TestSpanExporter.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import OpenTelemetrySdk

class TestSpanExporter: SpanExporter, ObservableObject {
    /// Perform actions that would trigger a span export and monitor changes on this property. When `state` is set to `ready`, you can perform tests on the cached spans.
    @Published var state: TestMockExporterState = .waiting

    var cachedExportedSpans: [String: [OpenTelemetrySdk.SpanData]] = [:]

    func clearAll() {
        cachedExportedSpans.removeAll()
        state = .clear
    }

    func shutdown(explicitTimeout: TimeInterval?) {}

    func flush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.SpanExporterResultCode {
        return .success
    }

    func export(spans: [OpenTelemetrySdk.SpanData], explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.SpanExporterResultCode {
        spans.forEach {
            if cachedExportedSpans[$0.name] == nil {
                cachedExportedSpans[$0.name] = []
            }
            cachedExportedSpans[$0.name]?.append($0)
        }
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
