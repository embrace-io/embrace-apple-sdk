//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage
import EmbraceOTel

class SpansPayloadBuilder {

    static let spanCountLimit = 1000

    class func build(
        for sessionRecord: SessionRecord,
        storage: EmbraceStorage
    ) -> (spans: [SpanPayload], spanSnapshots: [SpanPayload]) {

        let endTime = sessionRecord.endTime ?? Date()
        var records: [SpanRecord] = []

        // fetch spans that started during the session
        // ignore spans where emb.type == session
        do {
            records = try storage.fetchSpans(
                startTime: sessionRecord.startTime,
                endTime: endTime,
                ignoreSessionSpans: true,
                limit: spanCountLimit
            )

        } catch {
            ConsoleLog.error("Error fetching spans for session \(sessionRecord.id):\n\(error.localizedDescription)")
            return ([], [])
        }

        // decode spans and separate them by closed/open
        var spans: [SpanPayload] = []
        var spanSnapshots: [SpanPayload] = []

        // fetch and add session span first
        if let sessionSpanPayload = buildSessionSpanPayload(for: sessionRecord, storage: storage) {
            spans.append(sessionSpanPayload)
        }

        for record in records {
            do {
                let span = try JSONDecoder().decode(SpanData.self, from: record.data)
                let payload = SpanPayload(from: span)

                if span.hasEnded {
                    spans.append(payload)
                } else {
                    spanSnapshots.append(payload)
                }
            } catch {
                ConsoleLog.error("Error decoding span!:\n\(error.localizedDescription)")
            }
        }

        return (spans, spanSnapshots)
    }

    class func buildSessionSpanPayload(for sessionRecord: SessionRecord, storage: EmbraceStorage) -> SpanPayload? {
        do {
            let sessionSpan = try storage.fetchSpan(id: sessionRecord.spanId, traceId: sessionRecord.traceId)
            if let rawData = sessionSpan?.data {
                let sessionSpanData = try JSONDecoder().decode(SpanData.self, from: rawData)
                return SpanPayload(from: sessionSpanData, endTime: sessionRecord.endTime)
            } else {
                return SessionSpanUtils.payload(from: sessionRecord)
            }

        } catch {
            ConsoleLog.warning("Error fetching span for session \(sessionRecord.id):\n\(error.localizedDescription)")
        }

        return nil
    }
}
