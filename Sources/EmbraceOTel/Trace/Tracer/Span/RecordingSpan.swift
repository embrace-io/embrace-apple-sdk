//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

final class RecordingSpan: Span {
    let spanProcessor: EmbraceSpanProcessor

    var kind: OpenTelemetryApi.SpanKind
    var context: OpenTelemetryApi.SpanContext
    var status: OpenTelemetryApi.Status = .unset
    var name: String

    private (set) var startTime: Date
    private (set) var endTime: Date?
    private (set) var parentContext: SpanContext?
    private (set) var attributes = [String: AttributeValue]()
    private (set) var events = [RecordingSpanEvent]()
    private (set) var links = [RecordingSpanLink]()

    var isRecording: Bool { endTime == nil }

    init(
        startTime: Date,
        kind: SpanKind = .internal,
        context: SpanContext,
        parentContext: SpanContext? = nil,
        name: String,
        attributes: [String: AttributeValue] = [:],
        events: [RecordingSpanEvent] = [],
        links: [RecordingSpanLink] = [],
        processor: EmbraceSpanProcessor) {

        self.startTime = startTime
        self.kind = kind
        self.context = context
        self.parentContext = parentContext
        self.name = name
        self.attributes = attributes
        self.events = events
        self.links = links
        self.spanProcessor = processor
    }

    func setAttribute(key: String, value: OpenTelemetryApi.AttributeValue?) {
        attributes[key] = value
    }

    func addEvent(name: String) {
        addEvent(name: name, attributes: [:], timestamp: Date())
    }

    func addEvent(name: String, timestamp: Date) {
        addEvent(name: name, attributes: [:], timestamp: timestamp)
    }

    func addEvent(name: String, attributes: [String: OpenTelemetryApi.AttributeValue]) {
        addEvent(name: name, attributes: attributes, timestamp: Date())
    }

    func addEvent(name: String, attributes: [String: OpenTelemetryApi.AttributeValue], timestamp: Date) {
        let event = RecordingSpanEvent(name: name, timestamp: timestamp, attributes: attributes)
        events.append(event)
    }

    func end() {
        end(time: Date())
    }

    func end(time: Date) {
        endTime = time

        if status == .unset {
            status = .ok
        }

        spanProcessor.onEnd(span: self)
    }

}

extension RecordingSpan: ExportableSpan {
    var spanData: SpanData {
        SpanData(
            traceId: context.traceId,
            spanId: context.spanId,
            parentSpanId: parentContext?.spanId,
            name: name,
            kind: kind,
            startTime: startTime,
            endTime: endTime,
            attributes: attributes,
            events: events,
            links: links,
            status: status
        )
    }
}

extension RecordingSpan: CustomStringConvertible {
    var description: String { "<\(type(of: self)): \(Unmanaged.passUnretained(self).toOpaque()) name: '\(name)'>" }
}
