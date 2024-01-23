//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol EmbraceLoggerConfig {
    var maxInactivityTime: Int { get }
    var maxTimeBetweenLogs: Int { get }
    var maxMessageLength: Int { get }
    var maxAttributes: Int { get }
    var logAmountLimit: Int { get }
}

struct DefaultEmbraceLoggerConfig: EmbraceLoggerConfig {
    var maxInactivityTime: Int = 60
    var maxTimeBetweenLogs: Int = 20
    var maxAttributes: Int = 10
    var maxMessageLength: Int = 128
    var logAmountLimit: Int = 10
}
