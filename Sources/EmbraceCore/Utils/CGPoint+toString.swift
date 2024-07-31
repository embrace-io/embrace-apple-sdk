//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension CGPoint {
    func toString() -> String {
        "\(Int(trunc(x))),\(Int(trunc(y)))"
    }
}
