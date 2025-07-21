//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

/// An EmbraceType is an Embrace specific concept to allow for better categorization of Telemetry Primitives.
/// - This struct will be serialized into an `emb.type` attribute.
/// - This struct is encoded as a String with the format `<primary>.<secondary>`.
/// - The primary category is required, but the secondary category is optional.
public protocol EmbraceType: Hashable, Codable, CustomStringConvertible, RawRepresentable where RawValue == String {

    var primary: PrimaryType { get }

    var secondary: String? { get }

    init(primary: PrimaryType, secondary: String?)
}

/// Top level category for the EmbraceType
public enum PrimaryType: String {
    /// Category for observing a logical operation
    case performance = "perf"

    /// Category for observing the user's interaction or behavior
    case ux = "ux"

    /// Category for observing the system's operation or status
    case system = "sys"
}

// MARK: - EmbraceType Extensions -

extension EmbraceType {
    public init(primary: PrimaryType, secondary: String? = nil) {
        self.init(primary: primary, secondary: secondary)
    }

    public init(performance secondary: String) {
        self.init(primary: .performance, secondary: secondary)
    }

    public init(ux secondary: String) {
        self.init(primary: .ux, secondary: secondary)
    }

    public init(system secondary: String) {
        self.init(primary: .system, secondary: secondary)
    }
}

extension EmbraceType {

    public static var performance: Self { .init(primary: .performance, secondary: nil) }

    public static var ux: Self { .init(primary: .ux, secondary: nil) }

    public static var system: Self { .init(primary: .system, secondary: nil) }
}

// MARK: RawRepresentable
extension EmbraceType {
    public var rawValue: String {
        [primary.rawValue, secondary]
            .compactMap { $0 }
            .joined(separator: ".")
    }

    public init?(rawValue: String) {
        let components = rawValue.components(separatedBy: ".")
        guard let first = components.first,
            let primary = PrimaryType(rawValue: first)
        else {
            return nil
        }

        let secondary = components.count > 1 ? components.dropFirst().joined(separator: ".") : nil

        self.init(primary: primary, secondary: secondary)
    }
}

// MARK: Codable
extension EmbraceType {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        guard let embType = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid EmbraceType: '\(rawValue.prefix(20))'")
        }

        self = embType
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: CustomStringConvertible
extension EmbraceType {
    public var description: String { rawValue }
}
