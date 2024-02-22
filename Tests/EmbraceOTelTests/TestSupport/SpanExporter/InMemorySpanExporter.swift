//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTel
import OpenTelemetryApi

class InMemorySpanExporter: EmbraceSpanExporter {

    private(set) var exportedSpans: [SpanId: SpanData] = [:]

    private var onExportComplete: (() -> Void)?

    private var onFlush: (() -> Void)?

    private(set) var isShutdown = false

    func onExportComplete(completion: (() -> Void)?) {
        self.onExportComplete = completion
    }

    func onFlush(completion: (() -> Void)?) {
        self.onFlush = completion
    }

    func export(spans: [SpanData]) -> SpanExporterResultCode {
        spans.forEach { data in
            exportedSpans[data.spanId] = data
        }

        onExportComplete?()
        return .success
    }

    func flush() -> SpanExporterResultCode {
        onFlush?()
        return .success
    }

    func shutdown() {
        isShutdown = true
    }
}
