//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol EmbraceLoggerConfig: Equatable {
    var maxInactivityTime: Int { get }
    var maxTimeBetweenLogs: Int { get }
    var maxMessageLength: Int { get }
    var maxAttributes: Int { get }
    var logAmountLimit: Int { get }
}

extension EmbraceLoggerConfig {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.maxInactivityTime == rhs.maxInactivityTime &&
        lhs.maxTimeBetweenLogs == rhs.maxTimeBetweenLogs &&
        lhs.maxMessageLength == rhs.maxMessageLength &&
        lhs.maxAttributes == rhs.maxAttributes &&
        lhs.logAmountLimit == rhs.logAmountLimit
    }
}

struct DefaultEmbraceLoggerConfig: EmbraceLoggerConfig {
    let maxInactivityTime: Int = 60
    let maxTimeBetweenLogs: Int = 20
    let maxAttributes: Int = 10
    let maxMessageLength: Int = 128
    let logAmountLimit: Int = 10
}
