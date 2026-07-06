//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// An EmbraceType is an Embrace specific concept to allow for better categorization of Telemetry Primitives.
/// - This struct will be serialized into an `emb.type` attribute.
/// - This struct is encoded as a String with the format `<primary>.<secondary>`.
/// - The primary category is required, but the secondary category is optional.
public class EmbraceType: RawRepresentable, Hashable {

    /// The primary (top-level) category of the type.
    public let primary: PrimaryType

    /// The optional secondary (sub) category of the type.
    public let secondary: String?

    /// Creates a new `EmbraceType` with the given primary and optional secondary categories.
    /// - Parameters:
    ///   - primary: The primary category.
    ///   - secondary: The optional secondary category.
    public init(primary: PrimaryType, secondary: String? = nil) {
        self.primary = primary
        self.secondary = secondary
    }

    // MARK: Convenience initializers

    /// Creates a new `EmbraceType` with a `.performance` primary category and the given secondary category.
    public convenience init(performance secondary: String) {
        self.init(primary: .performance, secondary: secondary)
    }

    /// Creates a new `EmbraceType` with a `.ux` primary category and the given secondary category.
    public convenience init(ux secondary: String) {
        self.init(primary: .ux, secondary: secondary)
    }

    /// Creates a new `EmbraceType` with a `.system` primary category and the given secondary category.
    public convenience init(system secondary: String) {
        self.init(primary: .system, secondary: secondary)
    }

    /// An `EmbraceType` with a `.performance` primary category and no secondary category.
    public static var performance: EmbraceType {
        .init(primary: .performance, secondary: nil)
    }

    /// An `EmbraceType` with a `.ux` primary category and no secondary category.
    public static var ux: EmbraceType {
        .init(primary: .ux, secondary: nil)
    }

    /// An `EmbraceType` with a `.system` primary category and no secondary category.
    public static var system: EmbraceType {
        .init(primary: .system, secondary: nil)
    }

    // MARK: RawRepresentable
    public var rawValue: String {
        [primary.name, secondary]
            .compactMap { $0 }
            .joined(separator: ".")
    }

    required public convenience init?(rawValue: String) {
        let components = rawValue.components(separatedBy: ".")
        guard let first = components.first else {
            return nil
        }

        let secondary = components.count > 1 ? components.dropFirst().joined(separator: ".") : nil

        self.init(primary: PrimaryType(name: first), secondary: secondary)
    }

    public static func == (lhs: EmbraceType, rhs: EmbraceType) -> Bool {
        return lhs.primary == rhs.primary && lhs.secondary == rhs.secondary
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(primary)
        hasher.combine(secondary)
    }
}

/// Top level category for the EmbraceType
public enum PrimaryType: Int, CaseIterable {
    /// Category for observing a logical operation
    case performance = 1

    /// Category for observing the user's interaction or behavior
    case ux = 2

    /// Category for observing the system's operation or status
    case system = 3

    var name: String {
        switch self {
        case .performance: "perf"
        case .ux: "ux"
        case .system: "sys"
        }
    }

    /// Creates a `PrimaryType` from its serialized name (`"perf"`, `"ux"`, or `"sys"`).
    /// Unknown names default to `.performance`.
    public init(name: String) {
        switch name {
        case "ux": self = .ux
        case "sys": self = .system
        default: self = .performance
        }
    }
}
