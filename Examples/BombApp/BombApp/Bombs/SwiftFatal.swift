//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

class SwiftFatal: CRLCrash {
    override var category: String { return "Various" }
    override var title: String { return "Swift Fatal" }
    override var desc: String { return "Trigger a Swift fatal error." }

    override func crash() {
        fatalError()
    }
}
