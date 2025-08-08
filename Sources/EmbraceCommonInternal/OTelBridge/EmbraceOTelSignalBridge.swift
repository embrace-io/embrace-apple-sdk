//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Protocol used to bridge telemetry signals created through our SDK into 3rd party OTel implementations
public protocol EmbraceOTelSignalBridge {

    /// Called when a span is created and started
    func startSpan(
        id: String,
        traceId: String,
        parentSpanId: String?,
        name: String,
        status: EmbraceSpanStatus,
        startTime: Date,
        endTime: Date?,
        events: [EmbraceSpanEvent],
        links: [EmbraceSpanLink],
        attributes: [String: String]
    ) -> EmbraceSpan

    /// Called when the span status is updated
    func updateSpanStatus(_ span: EmbraceSpan, status: EmbraceSpanStatus)

    /// Called when a span attribute is added, modified or removed
    func updateSpanAttribute(_ span: EmbraceSpan, key: String, value: String?)

    /// Called when a new span even is added to a span
    func addSpanEvent(_ span: EmbraceSpan, event: EmbraceSpanEvent)

    /// Called when a new span link is added to a span
    func addSpanLink(_ span: EmbraceSpan, event: EmbraceSpanLink)

    /// Called when the span is ended
    func endSpan(_ span: EmbraceSpan, endTime: Date)

    /// Called when a log is created
    func createLog(body: String, timestamp: Date) -> EmbraceLog
}
