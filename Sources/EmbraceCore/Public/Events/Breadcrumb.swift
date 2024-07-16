//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTelInternal
import EmbraceCommonInternal

public struct Breadcrumb: SpanEvent {
    public let name: String
    public let timestamp: Date
    public private(set) var attributes: [String: AttributeValue]

    private enum Constants {
        static let name = "emb-breadcrumb"
        static let messageKey = "message"
        static let typeKey = "emb.type"
    }

    init(
        message: String,
        timestamp: Date = Date(),
        attributes: [String: AttributeValue]
    ) {
        self.name = Constants.name
        self.timestamp = timestamp
        self.attributes = attributes
        self.attributes[Constants.messageKey] = .string(message)
        self.attributes[Constants.typeKey] = .string(LogType.breadcrumb.rawValue)
    }
}

public extension SpanEvent where Self == Breadcrumb {
    static func breadcrumb(
        _ message: String,
        properties: [String: String] = [:]
    ) -> SpanEvent {
        let otelAttributes = properties.reduce(into: [String: AttributeValue]()) {
            $0[$1.key] = AttributeValue.string($1.value)
        }
        return Breadcrumb(message: message, attributes: otelAttributes)
    }
}
