//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import Foundation

class EmbraceLoggerBuilder: LoggerBuilder {
    let sharedState: EmbraceLoggerSharedState
    private var eventDomain: String?
    private var attributes: [String: AttributeValue]

    init(sharedState: EmbraceLoggerSharedState) {
        self.sharedState = sharedState
        self.attributes = [:]
    }

    public func setEventDomain(_ eventDomain: String) -> Self {
        self.eventDomain = eventDomain
        return self
    }

    /// This implementation does nothing at all. The schemaUrl affects the instrumentationScope which will be always
    /// the same for every instance of `EmbraceLogger` generated.
    public func setSchemaUrl(_ schemaUrl: String) -> Self {
        return self
    }

    /// This implementation does nothing at all. InstrumentationVersion for every instance of `EmbraceLogger` generated.
    public func setInstrumentationVersion(_ instrumentationVersion: String) -> Self {
        return self
    }

    /// This implementation does nothing at all. We'll try to always include trace context whenever it's possible.
    public func setIncludeTraceContext(_ includeTraceContext: Bool) -> Self {
        return self
    }

    public func setAttributes(_ attributes: [String: AttributeValue]) -> Self {
        attributes.forEach {
            self.attributes[$0.key] = $0.value
        }
        return self
    }

    func build() -> OpenTelemetryApi.Logger {
        EmbraceLogger(sharedState: sharedState,
                      eventDomain: eventDomain,
                      attributes: attributes)
    }
}
