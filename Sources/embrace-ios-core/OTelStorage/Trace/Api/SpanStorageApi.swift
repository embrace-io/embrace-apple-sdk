
protocol SpanReader {
    func fetchAll() throws -> [EmbraceSpanData]
}

protocol SpanWriter {

    func add(entry: EmbraceSpanData) throws
    func add(entries: [EmbraceSpanData]) throws

}

protocol SpanStorage : SpanReader, SpanWriter { }
