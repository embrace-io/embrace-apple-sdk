//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceOTelInternal
import OpenTelemetryApi
import OpenTelemetrySdk
import Foundation

public class InMemorySpanExporter: SpanExporter {

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

    public func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        spans.forEach { data in
            exportedSpans[data.spanId] = data
        }

        onExportComplete?()
        return .success
    }

    public func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        onFlush?()
        return .success
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        isShutdown = true
    }
}
