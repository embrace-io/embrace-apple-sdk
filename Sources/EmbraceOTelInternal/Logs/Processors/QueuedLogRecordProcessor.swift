//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

/// Forwards every call to the wrapped processor from a serial queue it owns.
///
/// Used to keep customer log processors and exporters off the thread that emits the log,
/// which is often an SDK queue. `onEmit` never blocks the caller, so a slow or re-entrant
/// customer exporter only delays this queue instead of stalling (or deadlocking) the SDK queue
/// it was called from.
///
/// `forceFlush` and `shutdown` block the caller until the queue drains, so they must not be
/// called from the wrapped processor's own callbacks: `queue.sync` on the current queue traps.
final class QueuedLogRecordProcessor: LogRecordProcessor {

    private let processor: SingleLogRecordProcessor

    /// Internal so tests can hold the queue. Nothing else should dispatch to it.
    let queue = DispatchQueue(label: "io.embrace.logprocessor", qos: .utility)

    init(processor: SingleLogRecordProcessor) {
        self.processor = processor
    }

    func onEmit(logRecord: ReadableLogRecord) {
        // Decide when the log is emitted, like `EmbraceSpanProcessor`, so disabling the SDK
        // while the log is queued can't drop it for customers after Embrace's inline exporters kept it.
        guard processor.sdkStateProvider?.isEnabled == true else {
            return
        }

        queue.async { [processor] in
            processor.forward(logRecord)
        }
    }

    // Both block the caller until every log emitted before them has been delivered to the
    // wrapped processor, then return its result.
    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        queue.sync {
            processor.forceFlush(explicitTimeout: explicitTimeout)
        }
    }

    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
        queue.sync {
            processor.shutdown(explicitTimeout: explicitTimeout)
        }
    }
}
