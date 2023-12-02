//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct SessionIdentifier: Equatable {
    let value: UUID

    public init(value: UUID) {
        self.value = value
    }

    public init?(string: String) {
        guard let uuid = UUID(uuidString: string) else {
            return nil
        }

        self.value = uuid
    }

    public var toString: String { value.uuidString }
}

extension SessionIdentifier: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(UUID.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
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
