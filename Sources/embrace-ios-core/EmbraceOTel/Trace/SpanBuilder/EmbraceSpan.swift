//
//  EmbraceSpan.swift
//  
//
//  Created by Austin Emmons on 7/30/23.
//

import Foundation
import OpenTelemetryApi


class EmbraceSpan: Span {

    private(set) var kind: SpanKind

    private(set) var context: SpanContext

    private(set) var parentContext: SpanContext?

    var status: OpenTelemetryApi.Status = .unset

    var name: String

    private(set) var startTime: Date

    private(set) var endTime: Date?

    private(set) var attributes = [String: AttributeValue]()

    private(set) var links: [EmbraceSpanData.Link]
    private(set) var events = [EmbraceSpanData.Event]()

    var isRecording: Bool { return endTime == nil }

    init(
        context: SpanContext,
        name: String,
        kind: SpanKind,
        startTime: Date,
        parentContext: SpanContext? = nil,
        attributes: [String : AttributeValue]=[:],
        links: [EmbraceSpanData.Link] = []
    ) {

        self.kind = .client
        self.context = context
        self.parentContext = parentContext
        self.name = name
        self.kind = kind

        self.attributes = attributes
        self.links = links
        self.startTime = startTime
    }

    func setAttribute(key: String, value: OpenTelemetryApi.AttributeValue?) {
        attributes[key] = value
    }

    func addEvent(name: String) {

    }
    
    func addEvent(name: String, timestamp: Date) {

    }
    
    func addEvent(name: String, attributes: [String : OpenTelemetryApi.AttributeValue]) {

    }
    
    func addEvent(name: String, attributes: [String : OpenTelemetryApi.AttributeValue], timestamp: Date) {

    }

    func end() {
        end(time: Date())
    }
    
    func end(time: Date) {
        self.endTime = time
    }

}

extension EmbraceSpan {

    var description: String {
        "<EmbraceSpan name=\(name)>"
    }

    func toSpanData() -> EmbraceSpanData {
        // TODO: Implement everything after `kind`
        return EmbraceSpanData(
            traceId: context.traceId,
            spanId: context.spanId,
            name: name,
            kind: kind,
            startTime: startTime,
            attributes: attributes,
            status: status,
            endTime: Date(),
            hasRemoteParent: false,
            hasEnded: true,
            totalRecordedEvents: 0,
            totalRecordedLinks: 0,
            totalAttributeCount: 0)
    }
}


