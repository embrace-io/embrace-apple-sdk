//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceStorageInternal
    import EmbraceOTelInternal
    import EmbraceSemantics
#endif

class SpansPayloadBuilder {

    static let startupSpanMaxLength: TimeInterval = 10

    class func build(
        for session: EmbraceSession,
        storage: EmbraceStorage,
        customProperties: [EmbraceMetadata] = [],
        sessionNumber: Int = -1
    ) -> (spans: [SpanPayload], spanSnapshots: [SpanPayload]) {

        let endTime = session.endTime ?? session.lastHeartbeatTime

        // fetch spans that started during the session
        // ignore spans where emb.type == session
        let records = storage.fetchSpans(for: session, ignoreSessionSpans: true)

        // decode spans and separate them by closed/open
        var spans: [SpanPayload] = []
        var spanSnapshots: [SpanPayload] = []

        // fetch and add session span first
        if let sessionSpanPayload = buildSessionSpanPayload(
            for: session,
            storage: storage,
            customProperties: customProperties,
            sessionNumber: sessionNumber
        ) {
            spans.append(sessionSpanPayload)
        }

        // check if we need to drop startup spans
        var shouldDropStartupSpans = true
        let startupRoot = records.first { $0.type == .startup && $0.name.contains(SpanSemantics.Startup.parentName) }
        if let startupRoot,
            let endTime = startupRoot.endTime
        {
            shouldDropStartupSpans = endTime.timeIntervalSince(startupRoot.startTime) > startupSpanMaxLength
        }

        for record in records {
            do {
                /// If the session crashed, we need to flag any open span in that session as failed, and send them as closed spans.
                /// If the `SpanRecord.endTime` is the same as the `SessionRecord.endTime`
                /// this means that the span didn't have an original `endTime` and that we set it manually
                /// during the recovery process in `UnsentDataHandler`.
                /// In other words it was an open span at the time the app crashed, and thus it must be closed and flagged as failed.
                /// The nil check is just a sanity check to cover all bases.
                let failed = session.crashReportId != nil && (record.endTime == nil || record.endTime == endTime)

                let span = try JSONDecoder().decode(SpanData.self, from: record.data)

                // drop startup span?
                if span.embType == .startup && shouldDropStartupSpans {
                    continue
                }

                let adjustedSpan = spanDataAdjustedForEvents(span, in: record)
                let payload = SpanPayload(from: adjustedSpan, endTime: failed ? endTime : record.endTime, failed: failed)

                if failed || span.hasEnded {
                    spans.append(payload)
                } else {
                    spanSnapshots.append(payload)
                }
            } catch {
                Embrace.logger.error("Error decoding span!:\n\(error.localizedDescription)")
            }
        }

        return (spans, spanSnapshots)
    }

    // Take in SpanData, and if the events are empty, fills it in with events from the EmbraceSpan.
    // I've chosen to do adjust spans this way in order to keep compatibility with all current tests
    // so we're not building new tests to fit with our changes.
    private class func spanDataAdjustedForEvents(_ spanData: SpanData, in record: EmbraceSpan) -> SpanData {
        var newSpanData: SpanData = spanData
        if newSpanData.events.isEmpty {
            newSpanData.settingEvents(
                record.events.map {
                    SpanData.Event(
                        name: $0.name,
                        timestamp: $0.timestamp,
                        attributes: $0.attributes.mapValues { v in .string(v) }
                    )
                }
            )
        }
        return newSpanData
    }

    class func buildSessionSpanPayload(
        for session: EmbraceSession,
        storage: EmbraceStorage,
        customProperties: [EmbraceMetadata] = [],
        sessionNumber: Int
    ) -> SpanPayload? {

        let sessionSpan = storage.fetchSpan(id: session.spanId, traceId: session.traceId)
        let adjustedSpanData: SpanData?
        do {
            if let sessionSpan {
                let spanData = try JSONDecoder().decode(SpanData.self, from: sessionSpan.data)
                adjustedSpanData = spanDataAdjustedForEvents(spanData, in: sessionSpan)
            } else {
                adjustedSpanData = nil
            }

        } catch {
            Embrace.logger.warning("Error fetching span for session \(session.idRaw):\n\(error.localizedDescription)")
            return nil
        }

        return SessionSpanUtils.payload(
            from: session,
            spanData: adjustedSpanData,
            properties: customProperties,
            sessionNumber: sessionNumber
        )
    }
}
