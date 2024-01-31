//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

struct BatchLimits {
    let maxAge: TimeInterval
    let maxLogsPerBatch: Int

    static func from(loggerConfig: any EmbraceLoggerConfig) -> Self {
        .init(
            maxAge: Double(loggerConfig.batchLifetimeInSeconds),
            maxLogsPerBatch: loggerConfig.logAmountLimit
        )
    }
}
