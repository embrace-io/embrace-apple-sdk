//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

protocol ProcessUptimeProvider {
    func uptime(since date: Date) -> TimeInterval?
}
