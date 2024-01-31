//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol EmbraceLoggerConfig: Equatable {
    var batchLifetimeInSeconds: Int { get }
    var maximumTimeBetweenLogsInSeconds: Int { get }
    var maximumMessageLength: Int { get }
    var maximumAttributes: Int { get }
    var logAmountLimit: Int { get }
}

extension EmbraceLoggerConfig {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.batchLifetimeInSeconds == rhs.batchLifetimeInSeconds &&
        lhs.maximumTimeBetweenLogsInSeconds == rhs.maximumTimeBetweenLogsInSeconds &&
        lhs.maximumMessageLength == rhs.maximumMessageLength &&
        lhs.maximumAttributes == rhs.maximumAttributes &&
        lhs.logAmountLimit == rhs.logAmountLimit
    }
}
