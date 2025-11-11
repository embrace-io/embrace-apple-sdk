//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Protocol used to generate OTel signals.
package protocol EmbraceOTelSignalsHandler: AnyObject {

    @discardableResult
    func _createSpan(
        name: String,
        parentSpan: EmbraceSpan?,
        type: EmbraceType,
        status: EmbraceSpanStatus,
        startTime: Date,
        endTime: Date?,
        events: [EmbraceSpanEvent],
        links: [EmbraceSpanLink],
        attributes: EmbraceAttributes,
        autoTerminationCode: EmbraceSpanErrorCode?,
        isInternal: Bool
    ) throws -> EmbraceSpan

    func _addSessionEvent(
        name: String,
        type: EmbraceType?,
        timestamp: Date,
        attributes: EmbraceAttributes,
        isInternal: Bool
    ) throws

    func _log(
        _ message: String,
        severity: EmbraceLogSeverity,
        type: EmbraceType,
        timestamp: Date,
        attachment: EmbraceLogAttachment?,
        attributes: EmbraceAttributes,
        stackTraceBehavior: EmbraceStackTraceBehavior,
        isInternal: Bool,
        send: Bool
    ) throws
}

extension EmbraceOTelSignalsHandler {
    package func createInternalSpan(
        name: String,
        parentSpan: EmbraceSpan? = nil,
        type: EmbraceType,
        status: EmbraceSpanStatus = .unset,
        startTime: Date = Date(),
        endTime: Date? = nil,
        events: [EmbraceSpanEvent] = [],
        links: [EmbraceSpanLink] = [],
        attributes: EmbraceAttributes = [:],
        autoTerminationCode: EmbraceSpanErrorCode? = nil
    ) throws -> EmbraceSpan {
        return try _createSpan(
            name: name,
            parentSpan: parentSpan,
            type: type,
            status: status,
            startTime: startTime,
            endTime: endTime,
            events: events,
            links: links,
            attributes: attributes,
            autoTerminationCode: autoTerminationCode,
            isInternal: true
        )
    }

    package func addInternalSessionEvent(
        name: String,
        type: EmbraceType? = nil,
        timestamp: Date = Date(),
        attributes: EmbraceAttributes = [:]
    ) throws {
        try _addSessionEvent(
            name: name,
            type: type,
            timestamp: timestamp,
            attributes: attributes,
            isInternal: true
        )
    }

    package func internalLog(
        _ message: String,
        severity: EmbraceLogSeverity = .info,
        type: EmbraceType = .internal,
        timestamp: Date = Date(),
        attachment: EmbraceLogAttachment? = nil,
        attributes: EmbraceAttributes = [:],
        stackTraceBehavior: EmbraceStackTraceBehavior = .default
    ) throws {
        try _log(
            message,
            severity: severity,
            type: type,
            timestamp: timestamp,
            attachment: attachment,
            attributes: attributes,
            stackTraceBehavior: stackTraceBehavior,
            isInternal: true,
            send: true
        )
    }
}
