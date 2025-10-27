//
//  TestSpanExporter.swift
//  EmbraceIOTestApp
//
//

import EmbraceCore
import OpenTelemetrySdk
import SwiftUI

@Observable class TestSpanExporter: SpanExporter {
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
            write(allSpans)
            return
        }
        _cachedSpans.removeAll { $0.name == specific }
        write(allSpans)
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

        write(allSpans)

        if !embraceStarted && spans.contains(where: { $0.name == "emb-sdk-start-process" }) {
            embraceStarted = true
            NotificationCenter.default.post(name: NSNotification.Name("TestSpanExporter.EmbraceStarted"), object: nil)
        }

        NotificationCenter.default.post(name: NSNotification.Name("TestSpanExporter.SpansUpdated"), object: nil)

        return .success
    }

    func write(_ spans: [SpanData]) {

        #if DEBUG
            let output = spans.compactMap { s in
                [
                    "name": s.name,
                    "start_time": s.startTime.description,
                    "end_time": s.endTime.description,
                    "attributes": s.attributes.compactMapValues { $0.description },
                    "resources": s.resource.attributes.compactMapValues { $0.description }
                ]
            }

            if let data = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]) {
                let home = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] ?? "/Users/alexcohen").appending(path: "Desktop/IOTestOutput")
                try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
                let url = home.appending(path: "spans.json")
                try? data.write(to: url)
            }
        #endif

    }
}
