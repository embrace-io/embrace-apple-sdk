//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct LogType: Equatable {
    let primary: Primary
    let secondary: String?

    public init(primary: Primary, secondary: String? = nil) {
        self.primary = primary
        self.secondary = secondary
    }

    public init(system secondary: String) {
        self.primary = .system
        self.secondary = secondary
    }
}

extension LogType: RawRepresentable {
    public typealias RawValue = String

    public var rawValue: String {
        [primary.rawValue, secondary]
            .compactMap { $0 }
            .joined(separator: ".")
    }

    public init?(rawValue: String) {
        let components = rawValue.components(separatedBy: ".")
        guard let primary = Primary(rawValue: components.first ?? "") else {
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

extension LogType: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        guard let logType = LogType(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Invalid LogType: '\(rawValue.prefix(10))'")
        }

        self = logType
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension LogType: CustomStringConvertible {
    public var description: String { rawValue }
}

public extension LogType {
    enum Primary: String {
        case system = "sys"
    }
}
