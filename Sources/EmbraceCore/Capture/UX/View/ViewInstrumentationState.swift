//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

class ViewInstrumentationState: NSObject {
    var identifier: String? = nil
    var viewDidLoadSpanCreated = false
    var viewWillAppearSpanCreated = false
    var viewIsAppearingSpanCreated = false
    var viewDidAppearSpanCreated = false

    init(identifier: String? = nil) {
        self.identifier = identifier
    }
}
