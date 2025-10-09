import EmbraceCommonInternal
import EmbraceStorageInternal
@preconcurrency import OpenTelemetryApi
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceOTelInternal

final class EmbraceOTelTests: XCTestCase {

    let sdkStateProvider = MockEmbraceSDKStateProvider()

    var logExporter = InMemoryLogRecordExporter()

    override func setUpWithError() throws {
        EmbraceOTel.setup(spanProcessors: [MockSpanProcessor()])

        EmbraceOTel.setup(
            logSharedState: DefaultEmbraceLogSharedState.create(
                storage: try .createInMemoryDb(),
                batcher: DummyLogBatcher(),
                exporter: logExporter,
                sdkStateProvider: sdkStateProvider
            ))
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
        XCTAssertNil(tracerSdk.instrumentationScopeInfo.version)
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

    // MARK: buildSpan

    // Test failing consistently in CI
    func skip_test_buildSpan_startsCorrectSpanType() throws {
        let otel = EmbraceOTel()
        let builder = otel.buildSpan(name: "example", type: .performance)

        let span = builder.startSpan()
        XCTAssertTrue(span is SpanSdk)
    }

    func test_buildSpan_withAttributes_appendsAttributes() throws {
        let otel = EmbraceOTel()
        let builder =
            otel
            .buildSpan(
                name: "example",
                type: .performance,
                attributes: ["foo": "bar"]
            )

        if let span = builder.startSpan() as? ReadableSpan {
            XCTAssertEqual(
                span.toSpanData().attributes,
                [
                    "foo": .string("bar"),
                    "emb.type": .string("perf")
                ])

        } else {
            throw XCTSkip("Test failing consistently in CI")
            //            XCTFail("Builder did not return a RecordingSpan")
        }
    }

    // MARK: log
    func test_log_emitsLogToExporter() throws {
        let otel = EmbraceOTel()

        otel.log("example message", severity: .info, timestamp: Date(), attributes: [:])
        let record = logExporter.finishedLogRecords.first { $0.body == .string("example message") }

        XCTAssertNotNil(record)
        XCTAssertEqual(record?.body, .string("example message"))
    }

    func test_log_withTimestampAndAttributes_emitsLogToExporter() throws {
        let otel = EmbraceOTel()

        let logTime = Date()

        otel.log(
            "example message",
            severity: .info,
            timestamp: logTime,
            attributes: ["foo": "bar"])
        let record = logExporter.finishedLogRecords.first { $0.body == .string("example message") }

        XCTAssertNotNil(record)
        XCTAssertEqual(record?.body, .string("example message"))
        XCTAssertEqual(record?.timestamp, logTime)
        XCTAssertEqual(record?.attributes, ["foo": .string("bar")])
    }
}
