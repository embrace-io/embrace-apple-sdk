//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Convenience declarations for common patterns using User Personas
public extension PersonaTag {
    static let free: PersonaTag = "free"
    static let preview: PersonaTag = "preview"
    static let subscriber: PersonaTag = "subscriber"
    static let payer: PersonaTag = "payer"
    static let guest: PersonaTag = "guest"

    static let pro: PersonaTag = "pro"
    static let mvp: PersonaTag = "mvp"
    static let vip: PersonaTag = "vip"
}

/// A PersonaTag is used by the ``MetadataHandler`` in order to tag app users with values to summarize their traits or behavior
public struct PersonaTag: Equatable {

    /// The maximum length of a PersonaTag.
    static let maxPersonaTagLength = 32

    /// Placeholder value for ``MetadataRecord.value``.
    /// A PersonaTag's MetadataRecord uses the ``MetadataRecord.key`` to store their data as they are not key-value pairs.
    static let metadataValue = ""

    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension PersonaTag: RawRepresentable {
    public init(rawValue: String) {
        self.init(rawValue)
    }
}

extension PersonaTag: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension PersonaTag: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension PersonaTag {
    // MARK: Validation

    private var isLengthValid: Bool {
        rawValue.count <= Self.maxPersonaTagLength
    }

    func validate() throws {
        guard isLengthValid else {
            throw MetadataError.invalidValue(
                "The persona tag length can not be greater than \(PersonaTag.maxPersonaTagLength)"
            )
        }
    }
}
