//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceStorageInternal
    import EmbraceSemantics
#endif

class SpansPayloadBuilder {

    static let startupSpanMaxLength: TimeInterval = 10

    class func build(
        for session: EmbraceSession,
        storage: EmbraceStorage,
        customProperties: [EmbraceMetadata] = []
    ) -> (spans: [SpanPayload], spanSnapshots: [SpanPayload]) {

        let endTime = session.endTime ?? session.lastHeartbeatTime

        // fetch spans that started during the session, minus the two types this builder fetches
        // for itself: the session span (added below) and state spans (fetched separately, next).
        let cappedRecords = storage.fetchSpans(for: session, excluding: [.session, .state])

        // State spans get their own fetch — and so their own budget — so a session busy enough to
        // exhaust the one above can't crowd them out. Note this is a separate budget, not an
        // unlimited one: the same row cap applies to each fetch. There are only a handful per
        // part, and losing one loses that part's whole state timeline plus the session span's
        // link target.
        let stateRecords = storage.fetchSpans(for: session, fetchOnly: .state)

        // processed identically from here on — the separate fetch is their only difference
        let records = cappedRecords + stateRecords

        // decode spans and separate them by closed/open
        var spans: [SpanPayload] = []
        var spanSnapshots: [SpanPayload] = []

        // fetch and add session span first
        if let sessionSpanPayload = buildSessionSpanPayload(
            for: session,
            storage: storage,
            customProperties: customProperties
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
            /// If the session crashed, we need to flag any open span in that session as failed, and send them as closed spans.
            /// If the `SpanRecord.endTime` is the same as the `SessionRecord.endTime`
            /// this means that the span didn't have an original `endTime` and that we set it manually
            /// during the recovery process in `UnsentDataHandler`.
            /// In other words it was an open span at the time the app crashed, and thus it must be closed and flagged as failed.
            /// The nil check is just a sanity check to cover all bases.
            let failed = session.crashReportId != nil && (record.endTime == nil || record.endTime == endTime)

            // drop startup span?
            if record.type == .startup && shouldDropStartupSpans {
                continue
            }

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
        customProperties: [EmbraceMetadata] = []
    ) -> SpanPayload? {

        let sessionSpan = storage.fetchSpan(id: session.spanId, traceId: session.traceId)

        return SessionSpanUtils.payload(
            from: session,
            span: sessionSpan,
            properties: customProperties
        )
    }
}
