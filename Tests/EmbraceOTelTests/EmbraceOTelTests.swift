import XCTest

@testable import EmbraceOTel
import OpenTelemetryApi
import OpenTelemetrySdk

final class EmbraceOTelTests: XCTestCase {

    let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
    let queue = DispatchQueue(label: "io.embrace.persistence")
    var spanProcessor: SimpleSpanProcessor!

//    let storage = SpanStor
//    let configuration: SpanExporter.ExporterConfiguration(storage: )

    override func setUp() {

    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpURL)
    }

//    func createSubject() -> EmbraceOTel {
//        let exporter = SpanExporter(configuration: self)
//        spanProcessor = SimpleSpanProcessor(spanExporter: exporter)
//        return EmbraceOTel(spanProcessor: spanProcessor)
//    }

//    func test_init() throws {
//        let processor = EmbraceOTel.createEmbraceBatchProcessor(configuration: self)
//        let otel = EmbraceOTel(spanProcessor: processor)
//        XCTAssertNotNil(otel)
//    }
//
// MARK: addSpan with block
//
//    func test_addSpan_returnsGenericResult_whenInt() throws {
//        let otel = createSubject()
//
//        let spanResult = otel.addSpan(name: "math_test", type: .performance) {
//            var result = 0
//            for i in 0...10 {
//                // 1 + 4 + 9 + 16 + 25 + 36 + 49 + 64 + 81 + 100
//                result += i * i
//            }
//
//            XCTAssertEqual(result, 385)
//            return result
//        }
//
//        XCTAssertEqual(spanResult, 385)
//    }
//
//    func test_addSpan_returnsGenericResult_whenString() throws {
//        let otel = createSubject()
//
//        let spanResult = otel.addSpan(name: "math_test", type: .performance) {
//            for i in 0...10 {
//                // 1 + 4 + 9 + 16 + 25 + 36 + 49 + 64 + 81 + 100
//                let _ = i * i
//            }
//
//            return "example_result"
//        }
//
//        XCTAssertEqual(spanResult, "example_result")
//    }
//
//    func test_addSpan_withAttributes_appendsAttributesToSpan() throws {
//        createSubject().addSpan(name: "example", type: .performance, attributes: ["foo":"bar"]) {
//            for i in 0...10 {
//                // 1 + 4 + 9 + 16 + 25 + 36 + 49 + 64 + 81 + 100
//                let _ = i * i
//            }
//        }
//        spanProcessor.shutdown()
//
//        let spans = dataStoreForCurrentSession.recentClosedSpansNamed("example", withLimit: 5, andType: EmbraceOTelSpan.self)
//        XCTAssertEqual(spans.count, 1)
//
//        if let span = spans.first as? EmbraceOTelSpan {
//            XCTAssertEqual(
//                span.endProperties as? [String:String],
//                [
//                    "foo":"bar",
//                    "emb.type" : "performance"
//                ] )
//        } else {
//            XCTFail("`example` Span is not an EmbraceOTelSpan ")
//        }
//    }
//
//    // MARK: buildSpan
//
//    func test_buildSpan_returnsSpanBuilder() throws {
//        let builder = createSubject().buildSpan(name: "example", type: .performance)
//        XCTAssertTrue(builder is SpanBuilder)
//    }
//
//    func test_buildSpan_withAttributes_appendsAttributes() throws {
//        let builder = createSubject()
//                        .buildSpan(
//                            name: "example",
//                            type: .performance,
//                            attributes: ["foo" : "bar"]
//                        )
//
//        let span = builder.startSpan()
//        span.end()
//        spanProcessor.shutdown()
//
//        // check the in memory object gets created correctly
//        if let readableSpan = span as? ReadableSpan {
//            let spanData = readableSpan.toSpanData()
//            XCTAssertEqual(
//                spanData.attributes,
//                [
//                    "foo" : AttributeValue.string("bar"),
//                    "emb.type" : AttributeValue.string("performance")
//                ] )
//        } else {
//            XCTFail("Span is not a ReadableSpan or does not produce SpanData correctly")
//        }
//
//        // check it gets exported to persistence correctly
//        let spans = dataStoreForCurrentSession.recentClosedSpansNamed("example", withLimit: 5, andType: EmbraceOTelSpan.self)
//        XCTAssertEqual(spans.count, 1)
//        if let span = spans.first as? EmbraceOTelSpan {
//            XCTAssertEqual(
//                span.endProperties as? [String:String],
//                [
//                    "foo":"bar",
//                    "emb.type" : "performance"
//                ] )
//        } else {
//            XCTFail("`example` Span is not an EmbraceOTelSpan")
//        }
//    }

}
