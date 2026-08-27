//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

class SingleLogRecordProcessor: LogRecordProcessor {

    let processors: [LogRecordProcessor]
    let exporters: [LogRecordExporter]

    weak var sdkStateProvider: EmbraceSDKStateProvider?

    init(
        processors: [LogRecordProcessor] = [],
        exporters: [LogRecordExporter] = [],
        sdkStateProvider: EmbraceSDKStateProvider
    ) {
        self.processors = processors
        self.exporters = exporters
        self.sdkStateProvider = sdkStateProvider
    }

    func onEmit(logRecord: ReadableLogRecord) {
        guard sdkStateProvider?.isEnabled == true else {
            return
        }

        let processors = self.processors
        processors.forEach {
            $0.onEmit(logRecord: logRecord)
        }

        let exporters = self.exporters
        exporters.forEach {
            _ = $0.export(logRecords: [logRecord])
        }
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        guard sdkStateProvider?.isEnabled == true else {
            return .failure
        }

        let processors = self.processors
        processors.forEach {
            _ = $0.forceFlush(explicitTimeout: explicitTimeout)
        }

        let exporters = self.exporters
        let resultSet = Set(exporters.map { $0.forceFlush() })
        if let firstResult = resultSet.first {
            return resultSet.count > 1 ? .failure : firstResult
        }
        return .success
    }

    func shutdown(explicitTimeout: TimeInterval?) -> ExportResult {

        let processors = self.processors
        processors.forEach {
            _ = $0.shutdown(explicitTimeout: explicitTimeout)
        }

        let exporters = self.exporters
        exporters.forEach {
            $0.shutdown(explicitTimeout: explicitTimeout)
        }

        return .success
    }
}
