import OpenTelemetrySdk

public protocol SpanReader {
    func fetchAll() throws -> [SpanData]
}

public protocol SpanWriter {

    func add(entry: SpanData) throws
    func add(entries: [SpanData]) throws

}

public protocol SpanStorage: SpanReader, SpanWriter { }
