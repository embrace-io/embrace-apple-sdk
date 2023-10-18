//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

/// A really simple implementation of the SpanProcessor that converts the ExportableSpan to SpanData
/// and passes it to the configured exporter in both `onStart` and `onEnd`
public struct SingleSpanProcessor: EmbraceSpanProcessor {
    private let spanExporter: EmbraceSpanExporter
    private let processorQueue = DispatchQueue(label: "io.embrace.spanprocessor", qos: .utility)

    /// Returns a new SingleSpanProcessor that converts spans to SpanData and forwards them to
    /// the given spanExporter.
    /// - Parameter spanExporter: the SpanExporter to where the Spans are pushed.
    public init(spanExporter: EmbraceSpanExporter) {
        self.spanExporter = spanExporter
    }

    public func onStart(span: ExportableSpan) {
        let exporter = self.spanExporter
        let data = span.spanData

        processorQueue.async {
            exporter.export(spans: [data])
        }
    }

    public func onEnd(span: ExportableSpan) {
        let exporter = self.spanExporter
        let data = span.spanData

        processorQueue.async {
            exporter.export(spans: [data])
        }
    }

    public func shutdown() {
        processorQueue.sync {
            spanExporter.shutdown()
        }
    }

}
