//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCore
import Foundation

public struct EmbraceEventName: Codable, Sendable, ExpressibleByStringLiteral {

    public let name: String

    public init(name: String) {
        self.name = name
    }

    public init(stringLiteral value: StringLiteralType) {
        self.name = value
    }
}

public protocol EmbraceIdentifiable: Sendable {
    var id: UUID { get }
    var timestamp: NanosecondClock { get }
}

public protocol EmbraceNamed: Sendable {
    var name: EmbraceEventName { get }
}

public protocol EmbraceIntervaled: Sendable {
    var startTime: NanosecondClock { get }
    var endTime: NanosecondClock { get }
}

extension EmbraceIntervaled where Self: EmbraceIdentifiable {
    public var startTime: NanosecondClock { timestamp }
}

extension EmbraceIntervaled where Self: EmbraceIdentifiable, Self: EmbraceIntervaled {
    public var duration: NanosecondClock { endTime - startTime }
}

public protocol EmbraceAttributed: Sendable {
    var attributes: [EmbraceIO.AttributeKey: EmbraceIO.AttributeValueType] { get }
}

public struct EmbraceSpan: EmbraceIdentifiable, EmbraceNamed, EmbraceIntervaled, EmbraceAttributed {

    public let id: UUID
    public let timestamp: NanosecondClock
    public let name: EmbraceEventName
    public let endTime: NanosecondClock
    public let attributes: [EmbraceIO.AttributeKey: EmbraceIO.AttributeValueType]

}
