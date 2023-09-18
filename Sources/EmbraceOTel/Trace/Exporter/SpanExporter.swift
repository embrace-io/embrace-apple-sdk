import Foundation
import OpenTelemetrySdk

import OSLog

public class SpanExporter: OpenTelemetrySdk.SpanExporter {

    public let configuration: ExporterConfiguration

    public init(configuration: ExporterConfiguration) {
        self.configuration = configuration
    }

    @discardableResult public func export(spans: [SpanData]) -> SpanExporterResultCode {
//        let dataStore = configuration.dataStoreForCurrentSession
//        let storage = configuration.storage

//        l

//        storage.add(entries: spans)

        for span in spans {
            // save to db
            print("span name: \(span.name)")

        }

        return .success
    }

    public func flush() -> SpanExporterResultCode {
        return .success
    }

    public func shutdown() {
        _ = flush()
    }

}
