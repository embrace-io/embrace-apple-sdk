//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorage
import EmbraceOTel

class StorageSpanExporter: EmbraceSpanExporter {

    private(set) weak var storage: EmbraceStorage?

    let validation: SpanDataValidation

    init(options: Options) {
        self.storage = options.storage

        self.validation = SpanDataValidation(validators: options.validators)
    }

    @discardableResult public func export(spans: [SpanData]) -> SpanExporterResultCode {
        guard let storage = storage else {
            return .failure
        }

        var result = SpanExporterResultCode.success
        for var spanData in spans {

            let isValid = validation.execute(spanData: &spanData)
            if isValid, let record = buildRecord(from: spanData) {
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

        // spanData endTime is non-optional and will be set during `toSpanData()`
        let endTime = spanData.hasEnded ? spanData.endTime : nil

        return SpanRecord(
            id: spanData.spanId.hexString,
            name: spanData.name,
            traceId: spanData.traceId.hexString,
            type: spanData.embType,
            data: data,
            startTime: spanData.startTime,
            endTime: endTime )
    }
}
