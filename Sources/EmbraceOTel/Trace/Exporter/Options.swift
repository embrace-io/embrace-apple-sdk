import Foundation

 import EmbraceStorage

public extension SpanExporter {
    class Options {

        let storage: EmbraceStorage

        init(storage: EmbraceStorage) {
            self.storage = storage
        }

    }
}
