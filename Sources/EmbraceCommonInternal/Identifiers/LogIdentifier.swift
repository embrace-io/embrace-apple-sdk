//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct LogIdentifier: Codable, Equatable {
    public let value: UUID

    public init(value: UUID) {
        self.value = value
    }

    public init() {
        self.init(value: UUID())
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(UUID.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    /// Converts the UUID to a string format without hyphens
    ///
    /// - This method transforms the UUID into a string representation without the hyphens that typically separate the segments of a UUID.
    /// It is designed to meet specific backend requirements where the hyphen-less format is preferred.
    ///
    /// - IMPORTANT: This method should not be used when you simply need the standard `uuidString` representation.
    /// For standard UUID strings, use the `value` property directly.
    public var toString: String {
        value.withoutHyphen
    }
}

extension LogIdentifier {
    public static var random: LogIdentifier {
        .init(value: UUID())
    }
}
