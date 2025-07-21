//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

class StdoutLogExporter: LogRecordExporter {
    private let isDebug: Bool

    init(isDebug: Bool) {
        self.isDebug = isDebug
    }

    func export(logRecords: [OpenTelemetrySdk.ReadableLogRecord], explicitTimeout: TimeInterval?)
        -> OpenTelemetrySdk.ExportResult
    {
        if isDebug {
            for logRecord in logRecords {
                print(String(repeating: "-", count: 40))
                print("Severity: \(String(describing: logRecord.severity))")
                print("Body: \(String(describing: logRecord.body))")
                print("InstrumentationScopeInfo: \(logRecord.instrumentationScopeInfo)")
                print("Timestamp: \(logRecord.timestamp)")
                print("ObservedTimestamp: \(String(describing: logRecord.observedTimestamp))")
                print("SpanContext: \(String(describing: logRecord.spanContext))")
                print("Resource: \(logRecord.resource.attributes)")
                print("Attributes: \(logRecord.attributes)")
                print(String(repeating: "-", count: 40))
            }
        } else {
            do {
                let jsonData = try JSONEncoder().encode(logRecords)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } catch {
                print("Failed to serialize LogRecord as JSON: \(error)")
                return .failure
            }
        }
        return .success
    }

    func forceFlush(explicitTimeout: TimeInterval?) -> OpenTelemetrySdk.ExportResult {
        return .success
    }

    func shutdown(explicitTimeout: TimeInterval?) {}

}
