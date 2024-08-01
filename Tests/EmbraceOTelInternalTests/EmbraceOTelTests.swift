import XCTest

@testable import EmbraceOTelInternal
import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport

final class EmbraceOTelTests: XCTestCase {

    override func setUpWithError() throws {
        EmbraceOTel.setup(spanProcessors: [MockSpanProcessor()])
    }

// MARK: Register Tracer

    func test_setup_setsTracerProviderSdk() {
        // DEV: test "setUpWithError" calls EmbraceOTel.setup method
        XCTAssertTrue(OpenTelemetry.instance.tracerProvider is TracerProviderSdk)
    }

    func testOnSettingUpTracer_tracer_isTracerSdk() {
        XCTAssertTrue(EmbraceOTel().tracer is TracerSdk)
    }

// MARK: Register Logger

    func test_setupLoggerProvider_setsLoggerProvider() {
        EmbraceOTel.setup(logSharedState: MockEmbraceLogSharedState())
        XCTAssertTrue(OpenTelemetry.instance.loggerProvider is DefaultEmbraceLoggerProvider)
    }

    func testOnSettingUpProvider_logger_isEmbraceLogger() {
        EmbraceOTel.setup(logSharedState: MockEmbraceLogSharedState())
        XCTAssertTrue(EmbraceOTel().logger is EmbraceLogger)
    }

// MARK: init

    func test_init_hasCorrectInstrumentationName() {
        let otel = EmbraceOTel()
        XCTAssertEqual(otel.instrumentationName, "EmbraceOpenTelemetry")
    }

// MARK: tracer

    func test_tracer_returnsTracerWithCorrectInstrumentationName() throws {
        let otel = EmbraceOTel()

        let tracer = otel.tracer(instrumentationName: "ExampleName")
        let tracerSdk = try XCTUnwrap(tracer as? TracerSdk)

        XCTAssertEqual(tracerSdk.instrumentationScopeInfo.name, "ExampleName")
        XCTAssertEqual(tracerSdk.instrumentationScopeInfo.version, "")  // DEV: looks like a side effect
                                                                        //  in TracerProviderSdk causes empty string
    }

    func test_tracer_returnsTracerWithCorrectInstrumentationName_andVersion() throws {
        let otel = EmbraceOTel()

        let tracer = otel.tracer(instrumentationName: "ExampleName", instrumentationVersion: "1.1.4")
        let tracerSdk = try XCTUnwrap(tracer as? TracerSdk)

        XCTAssertEqual(tracerSdk.instrumentationScopeInfo.name, "ExampleName")
        XCTAssertEqual(tracerSdk.instrumentationScopeInfo.version, "1.1.4")
    }

    func test_tracer_returnsSameTracerInstance_whenSameNamePassed() throws {
        let otel = EmbraceOTel()

        let first = otel.tracer(instrumentationName: "ExampleName")
        let second = otel.tracer(instrumentationName: "ExampleName")

        // compare memory address of first and second
        XCTAssertTrue(first === second)
    }

// MARK: recordSpan with block

    func test_recordSpan_returnsGenericResult_whenInt() throws {
        let otel = EmbraceOTel()

        let spanResult = otel.recordSpan(name: "math_test", type: .performance) {
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

    func test_recordSpan_returnsGenericResult_whenString() throws {
        let otel = EmbraceOTel()

        let spanResult = otel.recordSpan(name: "math_test", type: .performance) {
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
        XCTAssertTrue(span is RecordEventsReadableSpan)
    }

    func test_buildSpan_withAttributes_appendsAttributes() throws {
        let otel = EmbraceOTel()
        let builder = otel
                        .buildSpan(
                            name: "example",
                            type: .performance,
                            attributes: ["foo": "bar"]
                        )

        if let span = builder.startSpan() as? ReadableSpan {
            XCTAssertEqual(span.toSpanData().attributes, [
                "foo": .string("bar"),
                "emb.type": .string("perf")
            ])

        } else {
            XCTFail("Builder did not return a RecordingSpan")
        }
    }

}
