//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

class SingleLogRecordProcessor: LogRecordProcessor {

    private let exporters: [LogRecordExporter]

    weak var sdkStateProvider: EmbraceSDKStateProvider?

    init(exporters: [LogRecordExporter], sdkStateProvider: EmbraceSDKStateProvider) {
        self.exporters = exporters
        self.sdkStateProvider = sdkStateProvider
    }

    func onEmit(logRecord: ReadableLogRecord) {
        guard sdkStateProvider?.isEnabled == true else {
            return
        }

        exporters.forEach {
            _ = $0.export(logRecords: [logRecord])
        }
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        guard sdkStateProvider?.isEnabled == true else {
            return .failure
        }

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
