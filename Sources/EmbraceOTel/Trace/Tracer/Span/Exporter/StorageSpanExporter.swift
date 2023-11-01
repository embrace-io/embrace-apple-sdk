//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorage

public class StorageSpanExporter: EmbraceSpanExporter {

    public let options: Options

    var storage: EmbraceStorage { options.storage }

    public init(options: Options) {
        self.options = options
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
        // TODO: do we need to make sure storage writes are finished?
        return .success
    }

    public func shutdown() {
        _ = flush()
    }

}

extension StorageSpanExporter {
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