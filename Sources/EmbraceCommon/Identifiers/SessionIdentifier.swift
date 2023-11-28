//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct SessionIdentifier: Equatable {
    let value: UUID

    public init(value: UUID) {
        self.value = value
    }

    public init?(value: String) {
        guard let uuid = UUID(uuidString: value) else {
            return nil
        }

        self.value = uuid
    }

    public var toString: String { value.uuidString }
}

extension SessionIdentifier {
    public static var random: SessionIdentifier {
        .init(value: UUID())
    }
}

extension SessionIdentifier: CustomStringConvertible {
    public var description: String { value.uuidString }
}
