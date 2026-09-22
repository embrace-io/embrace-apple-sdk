//
//  TestSpanExporter.swift
//  EmbraceIOTestApp
//
//

import EmbraceCore
import OpenTelemetrySdk
import SwiftUI

@Observable final class TestSpanExporter: SpanExporter {
    var cachedExportedSpans: [String: [SpanData]] {
        Dictionary(grouping: _cachedSpans, by: { $0.name })
    }

    private(set) var latestExportedSpans: [SpanData] = []
    private var _cachedSpans: [SpanData] = []  // kept unique by spanId

    private var embraceStarted = false

    var allSpans: [SpanData] {
        _cachedSpans.sorted { $0.startTime < $1.startTime }
    }

    func clearAll(_ specifics: [String]) {
        specifics.forEach { clearAll($0) }
    }

    func clearAll(_ specific: String? = nil) {
        guard let specific = specific else {
            _cachedSpans.removeAll()
            return
        }
        _cachedSpans.removeAll { $0.name == specific }
    }

    func shutdown(explicitTimeout: TimeInterval?) {}

    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        return .success
    }

    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        latestExportedSpans = spans

        for s in spans {
            _cachedSpans.removeAll { $0.spanId == s.spanId }
        }
        _cachedSpans.append(contentsOf: spans)

        if !embraceStarted && spans.contains(where: { $0.name == "emb-sdk-start-process" }) {
            embraceStarted = true
            NotificationCenter.default.post(name: NSNotification.Name("TestSpanExporter.EmbraceStarted"), object: nil)
        }

        NotificationCenter.default.post(name: NSNotification.Name("TestSpanExporter.SpansUpdated"), object: nil)

        return .success
    }
}
