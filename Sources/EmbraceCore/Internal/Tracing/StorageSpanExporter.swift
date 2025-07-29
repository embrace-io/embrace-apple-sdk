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
    private(set) weak var sessionController: SessionControllable?
    private weak var logger: InternalLogger?

    let validation: SpanDataValidation

    init(options: Options, logger: InternalLogger) {
        self.storage = options.storage
        self.sessionController = options.sessionController
        self.validation = SpanDataValidation(validators: options.validators)
        self.logger = logger
    }

    @discardableResult public func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        guard let storage = storage else {
            return .failure
        }

        var result = SpanExporterResultCode.success
        for var spanData in spans {

            if validation.execute(spanData: &spanData) {
                do {
                    let data = try spanData.toJSON()

                    // spanData endTime is non-optional and will be set during `toSpanData()`
                    let endTime = spanData.hasEnded ? spanData.endTime : nil

                    // Prevent exporting our session spans on end.
                    // This process is handled by the `SessionController` to prevent
                    // race conditions when a session ends and its payload gets built.
                    if endTime != nil
                        && spanData.attributes[SpanSemantics.keyEmbraceType]?.description == SpanType.session.rawValue {
                        continue
                    }

                    storage.upsertSpan(
                        id: spanData.spanId.hexString,
                        name: spanData.name,
                        traceId: spanData.traceId.hexString,
                        type: spanData.embType,
                        data: data,
                        startTime: spanData.startTime,
                        endTime: endTime,
                        sessionId: sessionController?.currentSession?.id
                    )
                } catch let exception {
                    self.logger?.error(exception.localizedDescription)
                    result = .failure
                }
            } else {
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
