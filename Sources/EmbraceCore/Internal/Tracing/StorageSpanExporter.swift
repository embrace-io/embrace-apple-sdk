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

    let nameLengthLimit = 128

    private(set) weak var storage: EmbraceStorage?
    private(set) weak var sessionController: SessionControllable?
    private weak var logger: InternalLogger?

    init(options: Options, logger: InternalLogger) {
        self.storage = options.storage
        self.sessionController = options.sessionController
        self.logger = logger
    }

    @discardableResult public func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        guard let storage = storage else {
            return .failure
        }

        var result = SpanExporterResultCode.success
        for var spanData in spans {

            // spanData endTime is non-optional and will be set during `toSpanData()`
            let endTime = spanData.hasEnded ? spanData.endTime : nil

            // Prevent exporting our session spans on end.
            // This process is handled by the `SessionController` to prevent
            // race conditions when a session ends and its payload gets built.
            if endTime != nil && spanData.embType == SpanType.session {
                continue
            }

            // sanitize name
            let spanName = sanitizedName(spanData.name, type: spanData.embType)
            guard !spanName.isEmpty else {
                logger?.warning("Can't export span with empty name!")
                result = .failure
                continue
            }

            do {
                // add session id attribute
                if let sessionId = sessionController?.currentSession?.idRaw {
                    var attributes = spanData.attributes
                    attributes[SpanSemantics.keySessionId] = .string(sessionId)
                    spanData = spanData.settingAttributes(attributes)
                }
                
                let data = try spanData.toJSON()

                storage.upsertSpan(
                    id: spanData.spanId.hexString,
                    name: spanName,
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
        }

        return result
    }

    public func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        return .success
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        _ = flush()
    }

    func sanitizedName(_ name: String, type: SpanType) -> String {

        // do not truncate specific types
        guard type != .networkRequest,
            type != .view,
            type != .viewLoad
        else {
            return name
        }

        var result = name

        // trim white spaces
        let trimSet: CharacterSet = .whitespacesAndNewlines.union(.controlCharacters)
        result = name.trimmingCharacters(in: trimSet)

        // truncate
        if result.count > nameLengthLimit {
            result = String(result.prefix(nameLengthLimit))
            logger?.warning("Span name is too long and has to be truncated!: \(name)")
        }

        return result
    }
}
