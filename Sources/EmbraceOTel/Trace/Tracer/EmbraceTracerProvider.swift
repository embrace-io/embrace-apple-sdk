//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

class EmbraceTracerProvider: TracerProvider {

    let spanProcessor: EmbraceSpanProcessor

    init(spanProcessor: EmbraceSpanProcessor) {
        self.spanProcessor = spanProcessor
    }

    func get(instrumentationName: String, instrumentationVersion: String?) -> OpenTelemetryApi.Tracer {
        return EmbraceTracer(spanProcessor: spanProcessor)
    }
}
