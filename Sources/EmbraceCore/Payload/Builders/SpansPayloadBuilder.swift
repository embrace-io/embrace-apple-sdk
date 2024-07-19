//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceStorageInternal
import EmbraceOTelInternal

class SpansPayloadBuilder {

    static let spanCountLimit = 1000

    class func build(
        for sessionRecord: SessionRecord,
        storage: EmbraceStorage,
        sessionNumber: Int = -1
    ) -> (spans: [SpanPayload], spanSnapshots: [SpanPayload]) {

        let endTime = sessionRecord.endTime ?? sessionRecord.lastHeartbeatTime
        var records: [SpanRecord] = []

        // fetch spans that started during the session
        // ignore spans where emb.type == session
        do {
            records = try storage.fetchSpans(for: sessionRecord, ignoreSessionSpans: true, limit: spanCountLimit)
        } catch {
            Embrace.logger.error("Error fetching spans for session \(sessionRecord.id):\n\(error.localizedDescription)")
            return ([], [])
        }

        // decode spans and separate them by closed/open
        var spans: [SpanPayload] = []
        var spanSnapshots: [SpanPayload] = []

        // fetch and add session span first
        if let sessionSpanPayload = buildSessionSpanPayload(
            for: sessionRecord,
            storage: storage,
            sessionNumber: sessionNumber
        ) {
            spans.append(sessionSpanPayload)
        }

        for record in records {
            do {
                /// If the session crashed, we need to flag any open span in that session as failed, and send them as closed spans.
                /// If the `SpanRecord.endTime` is the same as the `SessionRecord.endTime`
                /// this means that the span didn't have an original `endTime` and that we set it manually
                /// during the recovery process in `UnsentDataHandler`.
                /// In other words it was an open span at the time the app crashed, and thus it must be closed and flagged as failed.
                /// The nil check is just a sanity check to cover all bases.
                let failed = sessionRecord.crashReportId != nil && (record.endTime == nil || record.endTime == endTime)

                let span = try JSONDecoder().decode(SpanData.self, from: record.data)
                let payload = SpanPayload(from: span, endTime: failed ? endTime : record.endTime, failed: failed)

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

    class func buildSessionSpanPayload(
        for sessionRecord: SessionRecord,
        storage: EmbraceStorage,
        sessionNumber: Int
    ) -> SpanPayload? {
        do {
            var spanData: SpanData?
            let sessionSpan = try storage.fetchSpan(id: sessionRecord.spanId, traceId: sessionRecord.traceId)

            if let rawData = sessionSpan?.data {
                spanData = try JSONDecoder().decode(SpanData.self, from: rawData)
            }

            return SessionSpanUtils.payload(from: sessionRecord, spanData: spanData, sessionNumber: sessionNumber)

        } catch {
            Embrace.logger.warning("Error fetching span for session \(sessionRecord.id):\n\(error.localizedDescription)")
        }

        return nil
    }
}
