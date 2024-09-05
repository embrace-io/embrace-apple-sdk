//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

class EmbraceTestIndexOutOfBounds: CRLCrash {
    override var category: String { return "Embrace" }
    override var title: String { return "Embrace Test Crash with an out of bounds exception" }
    override var desc: String { return "Trigger an Embrace test crash with an out of bounds exception" }

    override func crash() {
        let array = NSArray.init(objects: 1)
        let obj = array[1]
        print(obj)
    }
}
