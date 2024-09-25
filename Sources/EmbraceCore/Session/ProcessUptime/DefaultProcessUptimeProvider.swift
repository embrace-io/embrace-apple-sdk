//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

class DefaultProcessUptimeProvider: ProcessUptimeProvider {
    func uptime(since date: Date = Date()) -> TimeInterval? {
        return ProcessMetadata.uptime(since: date)
    }
}
