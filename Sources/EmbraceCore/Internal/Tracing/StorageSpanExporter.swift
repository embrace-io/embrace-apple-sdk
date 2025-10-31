//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceStorageInternal
    import EmbraceOTelInternal
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

class StorageSpanExporter: SpanExporter {

    private(set) weak var storage: EmbraceStorage?
    private weak var logger: InternalLogger?

    init(storage: EmbraceStorage, logger: InternalLogger) {
        self.storage = storage
        self.logger = logger
    }

    @discardableResult public func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        guard let storage else {
            return .failure
        }

        var result = SpanExporterResultCode.success
        for spanData in spans {

            // SpanData endTime is non-optional so we need to ensure it's only set if it should be.
            let endTime = spanData.hasEnded ? spanData.endTime : nil

            do {
                let data = try spanData.toJSON()
                var sessionId: EmbraceIdentifier? = nil
                if let id = spanData.attributes[SpanSemantics.keySessionId]?.description {
                    sessionId = EmbraceIdentifier(stringValue: id)
                }

                storage.upsertSpan(
                    id: spanData.spanId.hexString,
                    name: spanData.name,
                    traceId: spanData.traceId.hexString,
                    type: spanData.embType,
                    data: data,
                    startTime: spanData.startTime,
                    endTime: endTime,
                    sessionId: sessionId
                )
            } catch let exception {
                logger?.error(exception.localizedDescription)
                result = .failure
            }
        }

        return result
    }

    public func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        return .success
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        _ = flush()
    }
}
