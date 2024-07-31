//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct DeviceIdentifier: Equatable {

    let value: UUID

    public init(value: UUID) {
        self.value = value
    }

    public init?(string: String?) {
        guard let string = string,
              let uuid = UUID(withoutHyphen: string) else {
            return nil
        }

        self.value = uuid
    }

    public var hex: String { value.withoutHyphen }
}
