//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

class SingleLogRecordProcessor: LogRecordProcessor {

    private let exporters: [LogRecordExporter]

    init(exporters: [LogRecordExporter]) {
        self.exporters = exporters
    }

    func onEmit(logRecord: ReadableLogRecord) {
        exporters.forEach {
            _ = $0.export(logRecords: [logRecord])
        }
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        let resultSet = Set(exporters.map { $0.forceFlush() })
        if let firstResult = resultSet.first {
            return resultSet.count > 1 ? .failure : firstResult
        }
        return .success
    }

    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {
        exporters.forEach { $0.shutdown() }
        return .success
    }
}
