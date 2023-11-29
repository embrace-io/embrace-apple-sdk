//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage
import EmbraceOTel

class SpansPayloadBuilder {

    class func build(for sessionRecord: SessionRecord, storage: EmbraceStorage) -> (spans: [SpanPayload], spanSnapshots: [SpanPayload]) {

        let endTime = sessionRecord.endTime ?? Date()
        var records: [SpanRecord] = []

        // fetch spans that started during the session
        do {
            records = try storage.fetchSpans(startTime: sessionRecord.startTime, endTime: endTime)
        } catch {
            ConsoleLog.error("Error fetching spans for session \(sessionRecord.id):\n\(error.localizedDescription)")
            return ([], [])
        }

        // decode spans and separate them by closed/open
        var spans: [SpanPayload] = []
        var spanSnapshots: [SpanPayload] = []

        for record in records {
            do {
                let span = try JSONDecoder().decode(SpanData.self, from: record.data)
                let payload = SpanPayload(from: span)

                if span.endTime != nil {
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
}
