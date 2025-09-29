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
    var name: EmbraceEventName { get }
}

public protocol EmbraceIntervaled: EmbraceIdentifiable {
    var startTime: NanosecondClock { get }
    var endTime: NanosecondClock { get }
}

extension EmbraceIntervaled {
    public var startTime: NanosecondClock { timestamp }
    public var duration: NanosecondClock { endTime - startTime }
}

public protocol EmbraceAttributed: Sendable {
    var attributes: [EmbraceIO.AttributeKey: EmbraceIO.AttributeValueType] { get }
}

public protocol EmbraceMutableAttributed: EmbraceAttributed {
    func addAttribute(_ key: EmbraceIO.AttributeKey, value: EmbraceIO.AttributeValueType?)
    func setAttributes(_ attributes: [EmbraceIO.AttributeKey: EmbraceIO.AttributeValueType]?)
}

public protocol EmbraceEvent: EmbraceIdentifiable, EmbraceAttributed {}
public protocol EmbraceSpan: EmbraceIdentifiable, EmbraceIntervaled, EmbraceAttributed {
    func end(at timestamp: NanosecondClock)
}
