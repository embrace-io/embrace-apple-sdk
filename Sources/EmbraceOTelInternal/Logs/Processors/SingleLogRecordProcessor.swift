//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
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
        let resultSet = Set(exporters.map { $0.forceFlush() })
        if let firstResult = resultSet.first {
            return resultSet.count > 1 ? .failure : firstResult
        }
        return .success
    }

    func shutdown() -> ExportResult {
        exporters.forEach { $0.shutdown() }
        return .success
    }
}
