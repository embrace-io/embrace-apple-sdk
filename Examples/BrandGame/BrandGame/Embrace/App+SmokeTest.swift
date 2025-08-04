//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO
import Foundation

extension BrandGameApp {
    /// This method creates a sample span which we verify in automated integration tests
    func smokeTestIfNecessary() {
        guard ProcessInfo.processInfo.arguments.count > 1 else {
            return
        }

        switch ProcessInfo.processInfo.arguments[1] {
        case "Metadata":
            Embrace.client?
                .buildSpan(name: "Test Started for Metadata", type: .performance)
                .startSpan()
                .end()
        default:
            break
        }
    }
}
