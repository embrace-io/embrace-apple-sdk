//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

class SingleLogRecordProcessor: EmbraceLogRecordProcessor {
    private let exporters: [EmbraceLogRecordExporter]

    init(exporters: [EmbraceLogRecordExporter]) {
        self.exporters = exporters
    }

    func onEmit(logRecord: ReadableLogRecord) {
        exporters.forEach {
           _ = $0.export(logRecords: [logRecord])
        }
    }

    func forceFlush() -> ExportResult {
        exporters.forEach { _ = $0.forceFlush() }
        return .success
    }

    func shutdown() -> ExportResult {
        exporters.forEach { _ = $0.shutdown() }
        return .success
    }
}
