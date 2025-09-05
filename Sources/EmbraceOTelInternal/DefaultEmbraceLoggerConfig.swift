//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

struct DefaultEmbraceLoggerConfig: EmbraceLoggerConfig {
    let batchLifetimeInSeconds: Int = 60
    let maximumTimeBetweenLogsInSeconds: Int = 20
    let maximumAttributes: Int = 10
    let maximumMessageLength: Int = 128
    let logAmountLimit: Int = 10
}
