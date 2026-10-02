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
///
/// Attribute injection and delegate notifications happen synchronously on the calling thread;
/// child processor/exporter forwarding is dispatched to a dedicated utility queue, matching
/// `EmbraceSpanProcessor`. The calling thread is often an SDK queue, so a slow or re-entrant
/// child exporter then only delays this queue instead of stalling (or trapping) that SDK queue.
/// `criticalResourceGroup` (set by the bridge after `Embrace.setup` completes) is waited on before
/// any child forwarding begins, ensuring children never receive logs before critical SDK resources
/// are ready.
///
/// `forceFlush` and `shutdown` block the caller until the queue drains, so they must not be
/// called from a child's own callbacks: `queue.sync` on the current queue traps.
class EmbraceLogProcessor: LogRecordProcessor {

    weak var delegate: EmbraceLogProcessorDelegate?

    /// Set by `EmbraceOTelBridge.setup(delegate:metadataProvider:criticalResourceGroup:)`
    /// after `Embrace.setup()` completes. Child forwarding waits on this group before proceeding.
    var criticalResourceGroup: DispatchGroup?

    private let childProcessors: [LogRecordProcessor]
    private let childExporters: [LogRecordExporter]
    private let processorQueue = DispatchQueue(label: "io.embrace.otelbridge.logprocessor", qos: .utility)

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

        if let delegate, !delegate.isInternalLog(logRecord) {
            log.setAttribute(key: LogSemantics.keyEmbraceType, value: EmbraceType.message.rawValue)
            log.setAttribute(key: LogSemantics.keyState, value: delegate.currentSessionState.rawValue)

            let userSessionId = delegate.currentUserSessionId?.stringValue ?? ""
            let partId = delegate.currentSessionId?.stringValue ?? ""
            log.setAttribute(key: LogSemantics.keySessionId, value: userSessionId)
            log.setAttribute(key: LogSemantics.keyUserSessionId, value: userSessionId)
            log.setAttribute(key: LogSemantics.keyPartId, value: partId)
            delegate.onExternalLogEmitted(log)
        }

        processorQueue.async { [self, log] in
            criticalResourceGroup?.wait()

            let mkProcessSpan = EmbraceMetricKitSpan.begin(name: "log-processor-onemit")
            childProcessors.forEach { $0.onEmit(logRecord: log) }
            mkProcessSpan.end()

            let mkExportSpan = EmbraceMetricKitSpan.begin(name: "log-exporter-onemit")
            childExporters.forEach { _ = $0.export(logRecords: [log]) }
            mkExportSpan.end()
        }
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        processorQueue.sync {
            let mkProcessSpan = EmbraceMetricKitSpan.begin(name: "log-processor-forceflush")
            let processorResults = childProcessors.map { $0.forceFlush(explicitTimeout: explicitTimeout) }
            mkProcessSpan.end()

            let mkExportSpan = EmbraceMetricKitSpan.begin(name: "log-exporter-forceflush")
            let exporterResults = childExporters.map { $0.forceFlush() }
            mkExportSpan.end()

            let resultSet = Set(processorResults + exporterResults)
            if let first = resultSet.first {
                return resultSet.count > 1 ? .failure : first
            }
            return .success
        }
    }

    /// Drains the internal processor queue synchronously by enqueuing an empty barrier and
    /// waiting. Used by benchmark/test harnesses to ensure all queued log work is processed
    /// before measurements are taken.
    func waitForAllWork() {
        let group = DispatchGroup()
        processorQueue.async(group: group, flags: .assignCurrentContext) {}
        group.wait()
    }

    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
        processorQueue.sync {
            childProcessors.forEach { _ = $0.shutdown(explicitTimeout: explicitTimeout) }
            childExporters.forEach { $0.shutdown(explicitTimeout: explicitTimeout) }
        }
        return .success
    }
}
