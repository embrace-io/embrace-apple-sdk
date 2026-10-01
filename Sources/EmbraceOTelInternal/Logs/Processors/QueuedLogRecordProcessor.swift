//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

/// Forwards every call to the wrapped processor from a serial queue it owns.
///
/// Used to keep customer log processors and exporters off the thread that emits the log,
/// which is often an SDK queue. A slow or re-entrant customer exporter then only delays
/// this queue instead of stalling (or deadlocking) the SDK queue it was called from.
class QueuedLogRecordProcessor: LogRecordProcessor {

    let processor: LogRecordProcessor
    let queue = DispatchQueue(label: "io.embrace.logprocessor", qos: .utility)

    init(processor: LogRecordProcessor) {
        self.processor = processor
    }

    func onEmit(logRecord: ReadableLogRecord) {
        let processor = self.processor
        queue.async {
            processor.onEmit(logRecord: logRecord)
        }
    }

    // `forceFlush` and `shutdown` run synchronously so they also wait for every log that was
    // emitted before them to reach the wrapped processor.
    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        let processor = self.processor
        return queue.sync {
            processor.forceFlush(explicitTimeout: explicitTimeout)
        }
    }

    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
        let processor = self.processor
        return queue.sync {
            processor.shutdown(explicitTimeout: explicitTimeout)
        }
    }
}
