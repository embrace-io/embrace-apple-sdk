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

/// Read-only adapter that wraps an OTel `ReadableSpan` and exposes it as an `EmbraceSpan`.
/// Used by `EmbraceSpanProcessor` to forward external OTel spans into `EmbraceCore`.
class OTelSpanAdapter: EmbraceSpan {

    private let spanData: SpanData
    let metadataProvider: EmbraceMetadataProvider?

    init(span: ReadableSpan, metadataProvider: EmbraceMetadataProvider?) {
        self.spanData = span.toSpanData()
        self.metadataProvider = metadataProvider
    }

    // MARK: - EmbraceSpan

    lazy var context: EmbraceSpanContext = {
        EmbraceSpanContext(
            spanId: spanData.spanId.hexString,
            traceId: spanData.traceId.hexString
        )
    }()

    var parentSpanId: String? {
        guard let parentSpanId = spanData.parentSpanId, parentSpanId.isValid else {
            return nil
        }
        return parentSpanId.hexString
    }

    var name: String { spanData.name }

    var type: EmbraceType {
        guard let raw = spanData.attributes[SpanSemantics.keyEmbraceType]?.description,
            let type = EmbraceType(rawValue: raw)
        else {
            return .performance
        }
        return type
    }

    var status: EmbraceSpanStatus {
        switch spanData.status {
        case .ok: return .ok
        case .error: return .error
        default: return .unset
        }
    }

    var startTime: Date { spanData.startTime }

    var endTime: Date? {
        guard spanData.hasEnded else { return nil }
        return spanData.endTime
    }

    var events: [EmbraceSpanEvent] {
        spanData.events.map { event in
            EmbraceSpanEvent(
                name: event.name,
                timestamp: event.timestamp,
                attributes: event.attributes.toEmbraceAttributes()
            )
        }
    }

    var links: [EmbraceSpanLink] {
        spanData.links.map { link in
            EmbraceSpanLink(
                spanId: link.context.spanId.hexString,
                traceId: link.context.traceId.hexString,
                attributes: link.attributes.toEmbraceAttributes()
            )
        }
    }

    var attributes: EmbraceAttributes {
        spanData.attributes.toEmbraceAttributes()
    }

    var sessionId: EmbraceIdentifier? { metadataProvider?.currentSessionId }

    var processId: EmbraceIdentifier { metadataProvider?.currentProcessId ?? ProcessIdentifier.current }

    // MARK: - Mutation (no-op — adapter is read-only)

    func setStatus(_ status: EmbraceSpanStatus) {}
    func addEvent(name: String, type: EmbraceType?, timestamp: Date, attributes: EmbraceAttributes) throws {}
    func addLink(spanId: String, traceId: String, attributes: EmbraceAttributes) throws {}
    func setAttribute(key: String, value: EmbraceAttributeValue?) throws {}
    func end(endTime: Date) {}
    func end() {}
}
