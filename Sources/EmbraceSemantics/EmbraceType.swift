//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// An EmbraceType is an Embrace specific concept to allow for better categorization of Telemetry Primitives.
/// - This struct will be serialized into an `emb.type` attribute.
/// - This struct is encoded as a String with the format `<primary>.<secondary>`.
/// - The primary category is required, but the secondary category is optional.
public class EmbraceType: RawRepresentable, Hashable {

    public let primary: PrimaryType
    public let secondary: String?

    public init(primary: PrimaryType, secondary: String? = nil) {
        self.primary = primary
        self.secondary = secondary
    }

    // MARK: Convenience initializers
    public convenience init(performance secondary: String) {
        self.init(primary: .performance, secondary: secondary)
    }

    public convenience init(ux secondary: String) {
        self.init(primary: .ux, secondary: secondary)
    }

    public convenience init(system secondary: String) {
        self.init(primary: .system, secondary: secondary)
    }

    public static var performance: EmbraceType {
        .init(primary: .performance, secondary: nil)
    }
    public static var ux: EmbraceType {
        .init(primary: .ux, secondary: nil)
    }
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

    public init(name: String) {
        switch name {
        case "ux": self = .ux
        case "sys": self = .system
        default: self = .performance
        }
    }
}
