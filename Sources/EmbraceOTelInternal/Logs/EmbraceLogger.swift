//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

class EmbraceLogger: Logger {
    let sharedState: EmbraceLogSharedState
    private let attributes: [String: AttributeValue]

    init(
        sharedState: EmbraceLogSharedState,
        attributes: [String: AttributeValue] = [:]
    ) {
        self.sharedState = sharedState
        self.attributes = attributes
    }

    /// This method is meant to be used as part of the [Event API](https://opentelemetry.io/docs/specs/otel/logs/event-api/).
    /// However, due to the experimental state of this interface and the changes it has been receiving, we decided to not support it.
    ///
    /// - Parameter name: the name of the event. **Won't be used**.
    /// - Returns: a `EmbraceLogRecordBuilder` instance.
    func eventBuilder(name: String) -> EventBuilder {
        EmbraceLogRecordBuilder(
            sharedState: sharedState,
            attributes: attributes)
    }

    func logRecordBuilder() -> LogRecordBuilder {
        EmbraceLogRecordBuilder(
            sharedState: sharedState,
            attributes: attributes)
    }
}
