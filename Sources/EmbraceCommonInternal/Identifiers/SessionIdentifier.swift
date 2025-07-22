//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct SessionIdentifier: Equatable {
    let value: UUID

    public init(value: UUID) {
        self.value = value
    }

    public init?(string: String?) {
        guard let string = string,
            let uuid = UUID(withoutHyphen: string)
        else {
            return nil
        }

        self.value = uuid
    }

    /// Converts the UUID to a string format without hyphens
    ///
    /// - This method transforms the UUID into a string representation without the hyphens that typically separate the segments of a UUID.
    /// It is designed to meet specific backend requirements where the hyphen-less format is preferred.
    ///
    /// - IMPORTANT: This method should not be used when you simply need the standard `uuidString` representation.
    /// For standard UUID strings, use the `value` property directly.
    public var toString: String { value.withoutHyphen }
}

extension SessionIdentifier: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if let uuid = UUID(withoutHyphen: rawValue) {
            value = uuid
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Encoded value is not a valid UUID string"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.withoutHyphen)
    }
}

extension SessionIdentifier {
    public static var random: SessionIdentifier {
        .init(value: UUID())
    }
}

extension SessionIdentifier: CustomStringConvertible {
    public var description: String { value.uuidString }
}
