//
//  EmbraceSpan.swift
//  
//
//  Created by Austin Emmons on 7/30/23.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

class EmbraceSpan: Span {

    private(set) var kind: SpanKind

    private(set) var context: SpanContext

    private(set) var parentContext: SpanContext?

    var status: OpenTelemetryApi.Status = .unset

    var name: String

    private(set) var spanProcessor: SpanProcessor

    private(set) var startTime: Date

    private(set) var endTime: Date?

    private(set) var attributes = [String: AttributeValue]()

    private(set) var links: [SpanData.Link]
    private(set) var events = [SpanData.Event]()

    var isRecording: Bool { return endTime == nil }

    init(
        context: SpanContext,
        name: String,
        kind: SpanKind,
        startTime: Date,
        parentContext: SpanContext? = nil,
        attributes: [String: AttributeValue]=[:],
        links: [SpanData.Link] = [],
        spanProcessor: SpanProcessor
    ) {

        self.kind = .client
        self.context = context
        self.parentContext = parentContext
        self.name = name
        self.kind = kind

        self.attributes = attributes
        self.links = links
        self.startTime = startTime
        self.spanProcessor = spanProcessor
    }

    func setAttribute(key: String, value: OpenTelemetryApi.AttributeValue?) {
        attributes[key] = value
    }

    func addEvent(name: String) {

    }

    func addEvent(name: String, timestamp: Date) {

    }

    func addEvent(name: String, attributes: [String: OpenTelemetryApi.AttributeValue]) {

    }

    func addEvent(name: String, attributes: [String: OpenTelemetryApi.AttributeValue], timestamp: Date) {

    }

    func end() {
        end(time: Date())
    }

    func end(time: Date) {
        self.endTime = time

        // TODO: SpanProcessor protocol might be broken?
//        spanProcessor.onEnd(span: self)
    }

}

extension EmbraceSpan {

    var description: String {
        "<EmbraceSpan name=\(name)>"
    }

//    func toSpanData() -> SpanData {
//        // TODO: Implement everything after `kind`
//        return SpanData(
//            traceId: context.traceId,
//            spanId: context.spanId,
//            name: name,
//            kind: kind,
//            startTime: startTime,
//            attributes: attributes,
//            status: status,
//            endTime: Date(),
//            hasRemoteParent: false,
//            hasEnded: true,
//            totalRecordedEvents: 0,
//            totalRecordedLinks: 0,
//            totalAttributeCount: 0)
//    }
}

// extension EmbraceSpan: ReadableSpan {
//    var instrumentationScopeInfo: OpenTelemetrySdk.InstrumentationScopeInfo {
//        // TODO: Pass through InstrumentationScopeInfo
//        return InstrumentationScopeInfo()
//    }
//    
//    func toSpanData() -> OpenTelemetrySdk.SpanData {
//        // TODO: Return `SpanData` instead
//        return EmbraceSpanData(
//            traceId: context.traceId,
//            spanId: context.spanId,
//            name: name,
//            kind: kind,
//            startTime: startTime,
//            attributes: attributes,
//            status: status,
//            endTime: Date(),
//            hasRemoteParent: false,
//            hasEnded: true,
//            totalRecordedEvents: 0,
//            totalRecordedLinks: 0,
//            totalAttributeCount: 0) as! SpanData
//    }
//    
//    var hasEnded: Bool {
//        return endTime != nil
//    }
//    
//    /// Returns the latency of the Span in seconds. If still active then returns now() - start time.
//    public var latency: TimeInterval {
//        return endTime?.timeIntervalSince(startTime) ?? -startTime.timeIntervalSinceNow
//    }
//
//
// }
