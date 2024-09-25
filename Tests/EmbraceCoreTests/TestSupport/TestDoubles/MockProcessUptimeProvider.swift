//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
@testable import EmbraceCore

class MockProcessUptimeProvider: ProcessUptimeProvider {
    var uptime: TimeInterval

    convenience init() {
        self.init(uptime: 0)
    }

    init(uptime: TimeInterval = 0) {
        self.uptime = uptime
    }

    func uptime(since date: Date) -> TimeInterval? {
        return uptime
    }
}
