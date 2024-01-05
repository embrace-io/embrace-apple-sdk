//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

/// A SpanType is an Embrace specific concept to allow for better categorization of Spans.
/// - This struct will be serialized into the Span's `emb.type` attribute.
/// - This struct is encoded as a String with the format `<primary>.<secondary>`.
/// - The primary category is required, but the secondary category is optional.
public struct SpanType: Equatable {
    let primary: Primary

    let secondary: String?

    init(primary: Primary, secondary: String? = nil) {
        self.primary = primary
        self.secondary = secondary
    }
}

extension SpanType {

    init(performance secondary: String) {
        self.primary = .performance
        self.secondary = secondary
    }

    init(ux secondary: String) {
        self.primary = .ux
        self.secondary = secondary
    }

    init(system secondary: String) {
        self.primary = .system
        self.secondary = secondary
    }
}

extension SpanType: RawRepresentable {
    public typealias RawValue = String

    public var rawValue: String {
        [primary.rawValue, secondary]
            .compactMap { $0 }
            .joined(separator: ".")
    }

    public init?(rawValue: String) {
        let components = rawValue.components(separatedBy: ".")
        guard let first = components.first,
            let primary = Primary(rawValue: first) else {
            return nil
        }

        self.primary = primary
        if components.count > 1 {
            self.secondary = components.dropFirst().joined(separator: ".")
        } else {
            self.secondary = nil
        }
    }
}

extension SpanType: CustomStringConvertible {
    public var description: String { rawValue }
}

extension SpanType: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        guard let spanType = SpanType(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Invalid SpanType: '\(rawValue.prefix(10))'")
        }

        self = spanType
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension SpanType {

    /// Top level category for the SpanType
    enum Primary: String {
        /// Category for observing a logical operation
        case performance

        /// Category for observing the user's interaction or behavior
        case ux

        /// Category for observing the system's operation or status
        case system
    }
}
