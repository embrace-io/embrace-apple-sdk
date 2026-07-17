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

/// Read-only adapter that wraps an OTel `ReadableLogRecord` and exposes it as an `EmbraceLog`.
/// Used by `EmbraceLogProcessor` to forward external OTel logs into `EmbraceCore`.
class OTelLogAdapter: EmbraceLog {

    private let logRecord: ReadableLogRecord
    let metadataProvider: EmbraceMetadataProvider?

    init(logRecord: ReadableLogRecord, metadataProvider: EmbraceMetadataProvider?) {
        self.logRecord = logRecord
        self.metadataProvider = metadataProvider
    }

    // MARK: - EmbraceLog

    lazy var id: String = {
        // Use the log.record.uid attribute if present, otherwise generate one.
        if case let .string(uid) = logRecord.attributes[LogSemantics.keyId] {
            return uid
        }
        return EmbraceIdentifier.random.stringValue
    }()

    var severity: EmbraceLogSeverity {
        guard let otelSeverity = logRecord.severity,
            let embraceSeverity = EmbraceLogSeverity(rawValue: otelSeverity.rawValue)
        else {
            return .info
        }
        return embraceSeverity
    }

    var type: EmbraceType {
        if case let .string(raw) = logRecord.attributes[LogSemantics.keyEmbraceType],
            let type = EmbraceType(rawValue: raw)
        {
            return type
        }
        return .message
    }

    var timestamp: Date { logRecord.observedTimestamp ?? logRecord.timestamp }

    var body: String {
        switch logRecord.body {
        case let .string(text): return text
        default: return ""
        }
    }

    var attributes: EmbraceAttributes {
        logRecord.attributes.toEmbraceAttributes()
    }

    var sessionId: EmbraceIdentifier? { metadataProvider?.currentSessionId }

    var processId: EmbraceIdentifier { metadataProvider?.currentProcessId ?? ProcessIdentifier.current }
}
