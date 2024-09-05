//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO

class EmbraceTestCrash: CRLCrash {
    override var category: String { return "Embrace" }
    override var title: String { return "Embrace Test Crash" }
    override var desc: String { return "Trigger an Embrace test crash" }

    override func crash() {
        Embrace.client?.crash()
    }
}
