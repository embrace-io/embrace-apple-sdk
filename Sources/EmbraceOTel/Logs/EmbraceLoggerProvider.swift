//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public protocol EmbraceLoggerProvider: LoggerProvider {
    func get() -> Logger
}

class DefaultEmbraceLoggerProvider: EmbraceLoggerProvider {
    private let sharedState: EmbraceLoggerSharedState

    init(sharedState: EmbraceLoggerSharedState = .default()) {
        self.sharedState = sharedState
    }

    /// The parameter is not going to be used, as we're always going to create an `EmbraceLogger`
    /// which always has the same `instrumentationScope` (version & name)
    func get(instrumentationScopeName: String) -> Logger {
        get()
    }

    func get() -> Logger {
        EmbraceLogger(sharedState: sharedState)
    }

    /// The parameter is not going to be used, as we're always going to create an `EmbraceLoggerBuilder`
    /// which will be used to create an `EmbraceLogger` instance which always the same
    /// `instrumentationScope` (version & name)
    func loggerBuilder(instrumentationScopeName: String) -> LoggerBuilder {
        EmbraceLoggerBuilder(sharedState: sharedState)
    }

    func update(_ config: any EmbraceLoggerConfig) {
        sharedState.update(config)
    }
}
