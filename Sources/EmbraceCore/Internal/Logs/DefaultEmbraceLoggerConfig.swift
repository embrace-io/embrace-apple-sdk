//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceOTelInternal
#endif

struct DefaultEmbraceLoggerConfig: EmbraceLoggerConfig {
    let batchLifetimeInSeconds: Int = 60
    let maximumTimeBetweenLogsInSeconds: Int = 20
    let maximumAttributes: Int = 10
    let maximumMessageLength: Int = 128
    let logAmountLimit: Int = 10
}
