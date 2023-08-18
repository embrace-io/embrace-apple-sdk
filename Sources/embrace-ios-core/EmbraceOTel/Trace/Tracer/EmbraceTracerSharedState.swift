import Foundation
import OpenTelemetrySdk

extension EmbraceTracer {
    class SharedState {

        let idGenerator: IdGenerator
        let spanProcessor: SpanProcessor

        init(idGenerator: IdGenerator, spanProcessor: SpanProcessor) {
            self.idGenerator = idGenerator
            self.spanProcessor = spanProcessor
        }

    }
}
