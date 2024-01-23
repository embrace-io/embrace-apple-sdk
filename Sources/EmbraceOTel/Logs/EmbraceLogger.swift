//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

class EmbraceLogger: Logger {
    private let sharedState: EmbraceLoggerSharedState
    private let eventDomain: String?
    private let attributes: [String: AttributeValue]

    init(sharedState: EmbraceLoggerSharedState,
         eventDomain: String? = nil,
         attributes: [String: AttributeValue] = [:]) {
        self.sharedState = sharedState
        self.eventDomain = eventDomain
        self.attributes = attributes
    }

    func eventBuilder(name: String) -> EventBuilder {
        let eventBuilder = EmbraceLogRecordBuilder(sharedState: sharedState,
                                                   attributes: attributes)
        return eventBuilder.setAttributes([
            "event.domain": .string(eventDomain ?? "unused"),
            "event.name": .string(eventDomain != nil ? name : "unused")
        ])
    }

    func logRecordBuilder() -> LogRecordBuilder {
        EmbraceLogRecordBuilder(sharedState: sharedState,
                                attributes: attributes)
    }
}
