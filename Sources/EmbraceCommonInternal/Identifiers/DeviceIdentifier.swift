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

extension DeviceIdentifier {
    /// Returns the integer value of the device identifier using the number of digits from the suffix
    /// - Parameters:
    ///   - digitCount: The number of digits to use for the deviceId calculation
    public func intValue(digitCount: Int) -> UInt64 {
        var deviceIdHexValue: UInt64 = UInt64.max // defaults to everything disabled

        let hexValue = hex
        if hexValue.count >= digitCount {
            deviceIdHexValue = UInt64.init(hexValue.suffix(digitCount), radix: 16) ?? .max
        }

        return deviceIdHexValue
    }
}
