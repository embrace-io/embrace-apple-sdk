//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi

class EmbraceTracer: Tracer {

    let spanProcessor: EmbraceSpanProcessor

    init(spanProcessor: EmbraceSpanProcessor) {
        self.spanProcessor = spanProcessor
    }

    func spanBuilder(spanName: String) -> OpenTelemetryApi.SpanBuilder {
        return EmbraceSpanBuilder(spanName: spanName, processor: spanProcessor)
    }
}
