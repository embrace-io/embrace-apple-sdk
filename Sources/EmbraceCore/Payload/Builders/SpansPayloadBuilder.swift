//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceStorageInternal
#endif

class SpansPayloadBuilder {

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

        for record in records {
            /// If the session crashed, we need to flag any open span in that session as failed, and send them as closed spans.
            /// If the `SpanRecord.endTime` is the same as the `SessionRecord.endTime`
            /// this means that the span didn't have an original `endTime` and that we set it manually
            /// during the recovery process in `UnsentDataHandler`.
            /// In other words it was an open span at the time the app crashed, and thus it must be closed and flagged as failed.
            /// The nil check is just a sanity check to cover all bases.
            let failed = session.crashReportId != nil && (record.endTime == nil || record.endTime == endTime)
            let payload = SpanPayload(from: record, endTime: failed ? endTime : record.endTime, failed: failed)

            if failed || record.endTime != nil {
                spans.append(payload)
            } else {
                spanSnapshots.append(payload)
            }
        }

        return (spans, spanSnapshots)
    }

    class func buildSessionSpanPayload(
        for session: EmbraceSession,
        storage: EmbraceStorage,
        customProperties: [EmbraceMetadata] = [],
        sessionNumber: Int
    ) -> SpanPayload? {

        let sessionSpan = storage.fetchSpan(id: session.spanId, traceId: session.traceId)

        return SessionSpanUtils.payload(
            from: session,
            span: sessionSpan,
            properties: customProperties,
            sessionNumber: sessionNumber
        )
    }
}
