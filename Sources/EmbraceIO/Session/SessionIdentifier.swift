//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

struct SessionIdentifier: Equatable {
    let value: UUID

    init(value: UUID) {
        self.value = value
    }

    init?(value: String) {
        guard let uuid = UUID(uuidString: value) else {
            return nil
        }

        self.value = uuid
    }

    var toString: String { value.uuidString }
}

extension SessionIdentifier {
    static var random: SessionIdentifier {
        .init(value: UUID())
    }
}

extension SessionIdentifier: CustomStringConvertible {
    var description: String { value.uuidString }
}
