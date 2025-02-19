//
//  TestSpanExporter.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import OpenTelemetrySdk

@Observable class TestSpanExporter: SpanExporter {
    /// Perform actions that would trigger a span export and monitor changes on this property. When `state` is set to `ready`, you can perform tests on the cached spans.

    private(set) var cachedExportedSpans: [String: [SpanData]] = [:]
    private var embraceStarted = false

    func clearAll(_ specific: String? = nil) {
        guard let specific = specific else {
            cachedExportedSpans.removeAll()
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

        if !embraceStarted && spans.contains(where: { $0.name == "emb-sdk-start" }) {
            embraceStarted = true
            NotificationCenter.default.post(name: NSNotification.Name("TestSpanExporter.EmbraceStarted"), object: nil)
        }

        NotificationCenter.default.post(name: NSNotification.Name("TestSpanExporter.SpansUpdated"), object: nil)

        return .success
    }
}
