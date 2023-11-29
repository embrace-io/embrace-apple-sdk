import XCTest

@testable import EmbraceOTel
import EmbraceStorage
import OpenTelemetryApi
import OpenTelemetrySdk

final class EmbraceOTelTests: XCTestCase {

    override func setUpWithError() throws {
        let storage = try EmbraceStorage(options: .init(named: #file))
        let exporter = StorageSpanExporter(options: .init(storage: storage))

        EmbraceOTel.setup(spanProcessor: SingleSpanProcessor(spanExporter: exporter))
    }

// MARK: registerTracer

    func test_setup_setsEmbraceTracerProvider() {
        // DEV: test "setUpWithError" calls EmbraceOTel.setup method
        XCTAssertTrue(OpenTelemetry.instance.tracerProvider is EmbraceTracerProvider)
    }

// MARK: init

    func test_init() {
        let otel = EmbraceOTel()
        XCTAssertEqual(otel.instrumentationName, "EmbraceTracer")
    }

// MARK: addSpan with block

    func test_addSpan_returnsGenericResult_whenInt() throws {
        let otel = EmbraceOTel()

        let spanResult = otel.addSpan(name: "math_test", type: .performance) {
            var result = 0
            for i in 0...10 {
                // 1 + 4 + 9 + 16 + 25 + 36 + 49 + 64 + 81 + 100
                result += i * i
            }

            XCTAssertEqual(result, 385)
            return result
        }

        XCTAssertEqual(spanResult, 385)
    }

    func test_addSpan_returnsGenericResult_whenString() throws {
        let otel = EmbraceOTel()

        let spanResult = otel.addSpan(name: "math_test", type: .performance) {
            for i in 0...10 {
                // 1 + 4 + 9 + 16 + 25 + 36 + 49 + 64 + 81 + 100
                _ = i * i
            }

            return "example_result"
        }

        XCTAssertEqual(spanResult, "example_result")
    }

    // MARK: buildSpan

    func test_buildSpan_startsCorrectSpanType() throws {
        let otel = EmbraceOTel()
        let builder = otel.buildSpan(name: "example", type: .performance)

        let span = builder.startSpan()
        XCTAssertTrue(span is RecordingSpan)
    }

    func test_buildSpan_withAttributes_appendsAttributes() throws {
        let otel = EmbraceOTel()
        let builder = otel
                        .buildSpan(
                            name: "example",
                            type: .performance,
                            attributes: ["foo": "bar"]
                        )

        if let span = builder.startSpan() as? RecordingSpan {
            XCTAssertEqual(span.attributes, [
                "foo": .string("bar"),
                "emb.type": .string("performance")
            ])

        } else {
            XCTFail("Builder did not return a RecordingSpan")
        }
    }

}
