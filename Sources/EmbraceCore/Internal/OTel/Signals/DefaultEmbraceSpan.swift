//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
    
import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
#endif

/// Internal implementation of the `EmbraceSpan`.
/// Users of the SDK are expected to create these through the public interface and hold them.
/// This class internally communicates with the `OTelSingalsHandler`.
class DefaultEmbraceSpan: EmbraceSpan {

    let context: EmbraceSpanContext
    let parentSpanId: String?
    let name: String
    let type: EmbraceType
    let startTime: Date
    let sessionId: EmbraceIdentifier?
    let processId: EmbraceIdentifier
    let autoTerminationCode: EmbraceSpanErrorCode?

    weak var delegate: EmbraceSpanDelegate?

    private(set) var status: EmbraceSpanStatus {
        get { state.safeValue.status }
        set { state.safeValue.status = newValue }
    }

    private(set) var endTime: Date? {
        get { state.safeValue.endTime }
        set { state.safeValue.endTime = newValue }
    }

    private(set) var events: [EmbraceSpanEvent] {
        get { state.safeValue.events }
        set { state.safeValue.events = newValue }
    }

    private(set) var links: [EmbraceSpanLink] {
        get { state.safeValue.links }
        set { state.safeValue.links = newValue }
    }

    private(set) var attributes: [String : String] {
        get { state.safeValue.attributes }
        set { state.safeValue.attributes = newValue }
    }

    struct MutableData {
        var status: EmbraceSpanStatus = .unset
        var endTime: Date? = nil
        var events: [EmbraceSpanEvent] = []
        var links: [EmbraceSpanLink] = []
        var attributes: [String : String] = [:]
    }
    private let state = EmbraceMutex(MutableData())

    init(
        context: EmbraceSpanContext,
        parentSpanId: String?,
        name: String,
        type: EmbraceType = .performance,
        status: EmbraceSpanStatus = .unset,
        startTime: Date = Date(),
        endTime: Date? = nil,
        events: [EmbraceSpanEvent] = [],
        links: [EmbraceSpanLink] = [],
        attributes: [String: String] = [:],
        sessionId: EmbraceIdentifier? = nil,
        processId: EmbraceIdentifier = ProcessIdentifier.current,
        autoTerminationCode: EmbraceSpanErrorCode? = nil,
        delegate: EmbraceSpanDelegate? = nil
    ) {
        self.context = context
        self.parentSpanId = parentSpanId
        self.name = name
        self.type = type
        self.startTime = startTime
        self.sessionId = sessionId
        self.processId = processId
        self.autoTerminationCode = autoTerminationCode
        self.delegate = delegate

        self.status = status
        self.endTime = endTime
        self.events = events
        self.links = links
        self.attributes = attributes
    }

    func setStatus(_ status: EmbraceSpanStatus) {
        self.status = status
        delegate?.onSpanStatusUpdated(self, status: status)
    }
    
    func addEvent(_ event: EmbraceSpanEvent) {
        events.append(event)
        delegate?.onSpanEventAdded(self, event: event)
    }
    
    func addLink(_ link: EmbraceSpanLink) {
        links.append(link)
        delegate?.onSpanLinkAdded(self, link: link)
    }
    
    func setAttribute(key: String, value: String?) {
        attributes[key] = value
        delegate?.onSpanAttributeUpdated(self, attributes: attributes)
    }
    
    func end(endTime: Date) {
        self.endTime = endTime
        delegate?.onSpanEnded(self, endTime: endTime)
    }
    
    func end() {
        end(endTime: Date())
    }
}
