//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// An EmbraceType is an Embrace specific concept to allow for better categorization of Telemetry Primitives.
/// - This struct will be serialized into an `emb.type` attribute.
/// - This struct is encoded as a String with the format `<primary>.<secondary>`.
/// - The primary category is required, but the secondary category is optional.
@objc public class EmbraceType: NSObject, RawRepresentable {

    public let primary: PrimaryType
    public let secondary: String?

    @objc public init(primary: PrimaryType, secondary: String? = nil) {
        self.primary = primary
        self.secondary = secondary
    }

    // MARK: Convenience initializers
    @objc public convenience init(performance secondary: String) {
        self.init(primary: .performance, secondary: secondary)
    }

    @objc public convenience init(ux secondary: String) {
        self.init(primary: .ux, secondary: secondary)
    }

    @objc public convenience init(system secondary: String) {
        self.init(primary: .system, secondary: secondary)
    }

    @objc public static var performance: EmbraceType {
        .init(primary: .performance, secondary: nil)
    }
    @objc public static var ux: EmbraceType {
        .init(primary: .ux, secondary: nil)
    }
    @objc public static var system: EmbraceType {
        .init(primary: .system, secondary: nil)
    }

    // MARK: RawRepresentable
    @objc public var rawValue: String {
        [primary.name, secondary]
            .compactMap { $0 }
            .joined(separator: ".")
    }

    @objc override public var description: String {
        rawValue
    }

    @objc required public convenience init?(rawValue: String) {
        let components = rawValue.components(separatedBy: ".")
        guard let first = components.first else {
            return nil
        }

        let secondary = components.count > 1 ? components.dropFirst().joined(separator: ".") : nil

        self.init(primary: PrimaryType(name: first), secondary: secondary)
    }

    @objc override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Self else {
            return false
        }

        return primary == other.primary && secondary == other.secondary
    }

    @objc override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(primary)
        hasher.combine(secondary ?? "")
        return hasher.finalize()
    }
}

/// Top level category for the EmbraceType
@objc public enum PrimaryType: Int, CaseIterable {
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
