//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension Int {
    static func random(maxValue: Int = 1000) -> Int {
        return Int.random(in: 1...maxValue)
    }
}
