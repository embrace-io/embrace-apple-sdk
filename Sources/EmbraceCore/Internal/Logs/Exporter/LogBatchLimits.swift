//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

struct LogBatchLimits {
    let maxBatchAge: TimeInterval
    let maxLogsPerBatch: Int

    init(maxBatchAge: TimeInterval = 60, maxLogsPerBatch: Int = 20) {
        self.maxBatchAge = maxBatchAge
        self.maxLogsPerBatch = maxLogsPerBatch
    }
}
