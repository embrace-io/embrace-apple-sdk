//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public protocol EmbraceLoggerProvider: LoggerProvider {
    func get() -> Logger
    func update(_ config: any EmbraceLoggerConfig)
}

class DefaultEmbraceLoggerProvider: EmbraceLoggerProvider {
    private lazy var logger: EmbraceLogger = EmbraceLogger(sharedState: sharedState)

    let sharedState: EmbraceLogSharedState

    init(sharedState: EmbraceLogSharedState) {
        self.sharedState = sharedState
    }

    func get() -> Logger {
        logger
    }

    func update(_ config: any EmbraceLoggerConfig) {
        sharedState.update(config)
    }

    /// The parameter is not going to be used, as we're always going to create an `EmbraceLogger`
    /// which always has the same `instrumentationScope` (version & name)
    func get(instrumentationScopeName: String) -> Logger {
        get()
    }

    /// This method, defined by the `LoggerProvider` protocol, is intended to
    /// create a `LoggerBuilder` for a named `Logger` instance.
    ///
    /// In our implementation, the `instrumentationScopeName` parameter is not utilized since we
    /// consistently create an `EmbraceLoggerBuilder`. This builder, in turn, produces an `EmbraceLogger`
    /// instance with a fixed `instrumentationScope` (version & name).
    ///
    /// Consequently, we advise using `get()` or `get(instrumentationScopeName)` for standard
    /// `EmbraceLogger` retrieval. Directly instantiate an `EmbraceLoggerBuilder` only if you need a
    /// `Logger` with a distinct set of attributes.
    ///
    /// - Parameter instrumentationScopeName: An unused parameter in this context.
    /// - Returns: An instance of `EmbraceLoggerBuilder` which conforms to the `LoggerBuilder` interface.
    func loggerBuilder(instrumentationScopeName: String) -> LoggerBuilder {
        EmbraceLoggerBuilder(sharedState: sharedState)
    }
}
