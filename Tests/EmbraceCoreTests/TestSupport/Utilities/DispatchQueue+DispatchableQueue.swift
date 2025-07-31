//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation

// Only add this extension to Test Targets
extension DispatchQueue: DispatchableQueue {
    public func async(_ block: @escaping () -> Void) {
        self.async(execute: block)
    }
}
