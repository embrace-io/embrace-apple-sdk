//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTelInternal
import OpenTelemetryApi

public class InMemorySpanExporter: EmbraceSpanExporter {

    public private(set) var exportedSpans: [SpanId: SpanData] = [:]

    public private(set) var isShutdown = false

    private var onExportComplete: (() -> Void)?

    private var onFlush: (() -> Void)?

    public init() { }

    public func onExportComplete(completion: (() -> Void)?) {
        self.onExportComplete = completion
    }

    public func onFlush(completion: (() -> Void)?) {
        self.onFlush = completion
    }

    public func export(spans: [SpanData]) -> SpanExporterResultCode {
        spans.forEach { data in
            exportedSpans[data.spanId] = data
        }

        onExportComplete?()
        return .success
    }

    public func flush() -> SpanExporterResultCode {
        onFlush?()
        return .success
    }

    public func shutdown() {
        isShutdown = true
    }
}
