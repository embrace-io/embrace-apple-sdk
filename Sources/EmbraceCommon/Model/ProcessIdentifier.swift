//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// The unique identifier for this process that has a higher cardinality than the system PID
public struct ProcessIdentifier {
    let value: UInt32

    ///  Returns the base16 encoding of this SpanId.
    public var hex: String {
        return String(format: "%08lx", value)
    }
}

extension ProcessIdentifier {
    /// The identifier for the current process
    public static let current: ProcessIdentifier = .random
}

extension ProcessIdentifier {
    /// Should not be used outside of testing
    public static var random: ProcessIdentifier { ProcessIdentifier(value: .random(in: 1 ... .max)) }
}

extension ProcessIdentifier: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(UInt32.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
