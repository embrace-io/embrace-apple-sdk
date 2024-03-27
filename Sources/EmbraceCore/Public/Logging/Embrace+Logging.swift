//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceOTel

extension Embrace {
    private var otel: EmbraceOTel { .init() }

    public func log(
        _ message: String,
        attributes: [String: String],
        severity: LogSeverity
    ) {
        /*
         If we want to keep this method cleaner, we could move that to `EmbraceLogAttributesBuilder`
         However that would cause to always add a frame to the stacktrace.
         */
        var stackTrace: [String] = []
        if severity != .info {
            stackTrace = Thread.callStackSymbols
        }

        let attributesBuilder = EmbraceLogAttributesBuilder(
            storage: storage,
            sessionControllable: sessionController,
            initialAttributes: attributes
        )

        let finalAttributes = attributesBuilder
            .addStackTrace(stackTrace)
            .addLogType(.default)
            .addApplicationState()
            .addApplicationProperties()
            .addSessionIdentifier()
            .build()

        otel.log(message, attributes: finalAttributes, severity: severity)
    }
}
