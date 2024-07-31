//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension Collection where Element == LogDataValidator {
    static var `default`: [Element] {
        return [
            LengthOfBodyValidator()
        ]
    }
}
