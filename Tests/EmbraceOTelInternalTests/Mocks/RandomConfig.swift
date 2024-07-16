//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@testable import EmbraceOTelInternal

class RandomConfig: EmbraceLoggerConfig {
    var batchLifetimeInSeconds: Int = .random(in: 0...1000)
    var maximumTimeBetweenLogsInSeconds: Int = .random(in: 0...1000)
    var maximumMessageLength: Int = .random(in: 0...1000)
    var maximumAttributes: Int = .random(in: 0...1000)
    var logAmountLimit: Int = .random(in: 0...1000)
}
