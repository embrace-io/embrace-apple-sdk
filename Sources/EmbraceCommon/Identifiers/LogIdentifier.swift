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
}

extension LogIdentifier {
    public static var random: LogIdentifier {
        .init(value: UUID())
    }
}
