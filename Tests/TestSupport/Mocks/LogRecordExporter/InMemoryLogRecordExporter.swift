//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

public class InMemoryLogRecordExporter: LogRecordExporter {

    private(set) public var finishedLogRecords = [ReadableLogRecord]()
    private var isRunning = true

    public init() { }

    public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        guard isRunning else {
            return .failure
        }
        finishedLogRecords.append(contentsOf: logRecords)
        return .success
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        finishedLogRecords.removeAll()
        isRunning = false
    }

    public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        guard isRunning else {
            return .failure
        }
        return .success
    }
}
