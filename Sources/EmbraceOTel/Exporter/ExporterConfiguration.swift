import Foundation

public extension SpanExporter {
    class ExporterConfiguration {

        let storage: SpanStorage

        init(storage: SpanStorage) {
            self.storage = storage
        }

    }
}
