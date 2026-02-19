//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

/// OTel `LogRecordProcessor` that intercepts logs from any OTel logger using the shared provider.
///
/// Logs that were emitted by `EmbraceOTelBridge` itself (outbound signals) are identified
/// via `EmbraceLogProcessorDelegate.isInternalLog` and skipped — only genuinely external
/// logs are forwarded to `EmbraceCore` via the delegate.
///
/// All logs (internal and external) are forwarded to the child processors and exporters
/// supplied at init time, making this processor the single root of the log pipeline.
class EmbraceLogProcessor: LogRecordProcessor {

    weak var delegate: EmbraceLogProcessorDelegate?

    private let childProcessors: [LogRecordProcessor]
    private let childExporters: [LogRecordExporter]

    init(
        delegate: EmbraceLogProcessorDelegate? = nil,
        childProcessors: [LogRecordProcessor] = [],
        childExporters: [LogRecordExporter] = []
    ) {
        self.delegate = delegate
        self.childProcessors = childProcessors
        self.childExporters = childExporters
    }

    func onEmit(logRecord: ReadableLogRecord) {

        var log = logRecord

        if let delegate, !delegate.isInternalLog(logRecord) == false {
            log.setAttribute(key: LogSemantics.keyEmbraceType, value: EmbraceType.message.rawValue)
            log.setAttribute(key: LogSemantics.keyState, value: delegate.currentSessionState.rawValue)
            log.setAttribute(key: LogSemantics.keySessionId, value: delegate.currentSessionId?.stringValue ?? "")
            delegate.onExternalLogEmitted(log)
        }

        childProcessors.forEach { $0.onEmit(logRecord: log) }
        childExporters.forEach { _ = $0.export(logRecords: [log]) }
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        let processorResults = childProcessors.map { $0.forceFlush(explicitTimeout: explicitTimeout) }
        let exporterResults = childExporters.map { $0.forceFlush() }
        let resultSet = Set(processorResults + exporterResults)
        if let first = resultSet.first {
            return resultSet.count > 1 ? .failure : first
        }
        return .success
    }

    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
        childProcessors.forEach { _ = $0.shutdown(explicitTimeout: explicitTimeout) }
        childExporters.forEach { $0.shutdown(explicitTimeout: explicitTimeout) }
        return .success
    }
}
