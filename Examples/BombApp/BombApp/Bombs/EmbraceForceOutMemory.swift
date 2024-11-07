//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

class EmbraceForceOutMemory: CRLCrash {
    override var category: String { return "Embrace" }
    override var title: String { return "Embrace Force Out of Memory" }
    override var desc: String { return "Trigger an Embrace test crash" }

    override func crash() {
        var largeArray: [Int] = []
        while true {
            largeArray.append(contentsOf: Array(repeating: 0, count: 1_000_000))
        }
    }
}

