//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceStorageInternal
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

extension SpanData {
    func spanDataByRemovingEvents() -> SpanData {
        var span = self
        span.settingEvents([])
        return span
    }
}

// Synchronization on StorageSpanExporter is expected to be done at a higher level.
package class StorageSpanExporter: SpanExporter {

    private(set) weak var storage: EmbraceStorage?
    private weak var logger: InternalLogger?

    private let newStorageForEvents: Bool
    // As events are always added in order, this keeps a count of events.
    package var _spanEventsSideTable: [UInt64: Int] = [:]

    package init(storage: EmbraceStorage, logger: InternalLogger, useNewStorage: Bool = false) {
        self.storage = storage
        self.logger = logger
        self.newStorageForEvents = useNewStorage || ProcessInfo.processInfo.environment["EMBUseNewStorageForEvents"] == "1"
    }

    @discardableResult public func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        guard let storage else {
            return .failure
        }

        var result = SpanExporterResultCode.success
        for var inputSpanData in spans {

            var newEvents: [ImmutableSpanEventRecord] = []

            if newStorageForEvents {
                // check for storage for these spans
                let processedCount = _spanEventsSideTable[inputSpanData.spanId.rawValue, default: 0]
                let totalEvents = inputSpanData.events.count

                // Only get new events since last processed
                if processedCount < totalEvents {
                    newEvents = inputSpanData.events[processedCount..<totalEvents].map { spanEvent in
                        ImmutableSpanEventRecord(
                            name: spanEvent.name,
                            timestamp: spanEvent.timestamp,
                            attributes: spanEvent.attributes.compactMapValues { $0.description }
                        )
                    }
                }

                // cache the current state of events for this span
                _spanEventsSideTable[inputSpanData.spanId.rawValue] = totalEvents

                // now remove all events since we don't want them encoded
                inputSpanData = inputSpanData.spanDataByRemovingEvents()
            }

            // immutable from now on
            let spanData = inputSpanData

            // SpanData endTime is non-optional so we need to ensure it's only set if it should be.
            let endTime = inputSpanData.hasEnded ? inputSpanData.endTime : nil

            do {
                let data: Data = try spanData.toJSON()

                var sessionId: EmbraceIdentifier? = nil
                if let id = spanData.attributes[SpanSemantics.keySessionId]?.description {
                    sessionId = EmbraceIdentifier(stringValue: id)
                }

                // First, create or update the span
                storage.upsertSpan(
                    id: spanData.spanId.hexString,
                    name: spanData.name,
                    traceId: spanData.traceId.hexString,
                    type: spanData.embType,
                    data: data,
                    startTime: spanData.startTime,
                    endTime: endTime,
                    sessionId: sessionId
                )

                // Then, if using new storage, add the new events to the span
                if newStorageForEvents && !newEvents.isEmpty {
                    storage.addEventsToSpan(
                        id: spanData.spanId.hexString,
                        traceId: spanData.traceId.hexString,
                        events: newEvents
                    )
                }
            } catch let exception {
                logger?.error(exception.localizedDescription)
                result = .failure
            }

            // Remove the storage for an ended span
            if newStorageForEvents && spanData.hasEnded {
                _spanEventsSideTable.removeValue(forKey: spanData.spanId.rawValue)
            }
        }

        return result
    }

    public func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        return .success
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        _ = flush()
    }
}
