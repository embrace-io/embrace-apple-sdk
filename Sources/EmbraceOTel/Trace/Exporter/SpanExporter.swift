import Foundation
import OpenTelemetrySdk

import EmbraceStorage

public class SpanExporter: OpenTelemetrySdk.SpanExporter {

    public let options: Options

    var storage: EmbraceStorage { options.storage }

    public init(configuration: Options) {
        self.options = configuration
    }

    @discardableResult public func export(spans: [SpanData]) -> SpanExporterResultCode {
        var result = SpanExporterResultCode.success

        for spanData in spans {
            if let record = buildRecord(from: spanData) {
                do {
                    try storage.upsertSpan(record)
                } catch {
                    result = .failure
                }
            } else {
                result = .failure
            }
        }

        return result
    }

    public func flush() -> SpanExporterResultCode {
        return .success
    }

    public func shutdown() {
        _ = flush()
    }

}

extension SpanExporter {
    private func buildRecord(from spanData: SpanData) -> SpanRecord? {
        guard let data = try? spanData.toJSON() else {
            return nil
        }

        return SpanRecord(
            id: spanData.spanId.hexString,
            traceId: spanData.traceId.hexString,
            type: spanData.embType,
            data: data,
            startTime: spanData.startTime,
            endTime: spanData.endTime )
    }
}
