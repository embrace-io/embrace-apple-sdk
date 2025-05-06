//
//  TestSpanExporter.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import OpenTelemetrySdk

@Observable class TestSpanExporter: SpanExporter {
    private(set) var cachedExportedSpans: [String: [SpanData]] = [:]
    private(set) var latestExporterSpans: [SpanData] = []

    private var embraceStarted = false

    func clearAll(_ specifics: [String]) {
        specifics.forEach { clearAll($0) }
    }

    func clearAll(_ specific: String? = nil) {
        guard let specific = specific else {
            cachedExportedSpans.removeAll()
            return
        }
        cachedExportedSpans[specific] = nil
    }

    func shutdown(explicitTimeout: TimeInterval?) {}

    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        return .success
    }

    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        latestExporterSpans = spans
        spans.forEach {
            if cachedExportedSpans[$0.name] == nil {
                cachedExportedSpans[$0.name] = []
            }
            cachedExportedSpans[$0.name]?.append($0)
        }

        if !embraceStarted && spans.contains(where: { $0.name == "emb-sdk-start" }) {
            embraceStarted = true
            NotificationCenter.default.post(name: NSNotification.Name("TestSpanExporter.EmbraceStarted"), object: nil)
        }

        NotificationCenter.default.post(name: NSNotification.Name("TestSpanExporter.SpansUpdated"), object: nil)

        return .success
    }
}
