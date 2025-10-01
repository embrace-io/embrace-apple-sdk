//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

@preconcurrency import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import EmbraceOTelInternal

class EmbraceLogRecordBuilderTests: XCTestCase {
    private var sut: EmbraceLogRecordBuilder!
    private var processor: SpyLoggerProcessor!

    override func setUpWithError() throws {
        processor = .init()
    }

    func test_onInit_instrumentationScopeHasOnlyEmbraceLoggerName() {
        givenEmbraceLogRecordBuilder()
        whenCallingEmit()
        thenProducedRecordHas(instrumentationInfo: .init(name: "EmbraceLogger"))
    }

    func test_onSetTimeStamp_valueShouldBeAddedToRecordLogOnEmit() {
        let aTimestamp = Date(timeIntervalSinceNow: .random(in: 0...1000))
        givenEmbraceLogRecordBuilder()
        whenSetting(timestamp: aTimestamp)
        whenCallingEmit()
        thenProducedRecordHas(timestamp: aTimestamp)
    }

    func test_onSetObservedTimestamp_valueShouldBeAddedToRecordLogOnEmit() {
        let aTimestamp = Date(timeIntervalSinceNow: .random(in: 0...1000))
        givenEmbraceLogRecordBuilder()
        whenSetting(observedTimestamp: aTimestamp)
        whenCallingEmit()
        thenProducedRecordHas(observedTimestamp: aTimestamp)
    }

    func test_onSetSpanContext_valueShouldBeAddedToRecordLogOnEmit() {
        let spanContext = SpanContext.create(
            traceId: .random(),
            spanId: .random(),
            traceFlags: .init(),
            traceState: .init())
        givenEmbraceLogRecordBuilder()
        whenSetting(spanContext: spanContext)
        whenCallingEmit()
        thenProducedRecordHas(spanContext: spanContext)
    }

    func test_whenActiveSpanContextSet_valueShouldBeAddedToRecordLogOnEmit() {
        givenEmbraceLogRecordBuilder()
        let spanContext = whenSpanContextActive()
        whenCallingEmit()
        thenProducedRecordHas(spanContext: spanContext)
    }

    func test_whenActiveSpanContextSet_andExplicitlySet_explicitValueShouldBeAddedToRecordLogOnEmit() {
        let explicitContext = SpanContext.create(
            traceId: .random(),
            spanId: .random(),
            traceFlags: .init(),
            traceState: .init())

        givenEmbraceLogRecordBuilder()
        _ = whenSpanContextActive()
        whenSetting(spanContext: explicitContext)
        whenCallingEmit()
        thenProducedRecordHas(spanContext: explicitContext)
    }

    func test_onSetSeverity_valueShouldBeAddedToRecordLogOnEmit() throws {
        let severity = try XCTUnwrap(Severity(rawValue: .random(in: 1...24)))
        givenEmbraceLogRecordBuilder()
        whenSetting(severity: severity)
        whenCallingEmit()
        thenProducedRecordHas(severity: severity)
    }

    func test_onSetBody_valueShouldBeAddedToRecordLogOnEmit() {
        let bodyString = UUID().uuidString
        givenEmbraceLogRecordBuilder()
        whenSetting(body: bodyString)
        whenCallingEmit()
        thenProducedRecordHas(body: bodyString)
    }

    func test_onSetAttributes_valuesShouldBeAddedToRecordLogOnEmit() {
        let randomAttribute: [String: AttributeValue] = [UUID().uuidString: .string(UUID().uuidString)]
        givenEmbraceLogRecordBuilder()
        whenSetting(attribute: randomAttribute)
        whenCallingEmit()
        thenProducedRecordHas(attribute: randomAttribute)
    }

    func test_onSetSameAttributeMultipleTimes_latestValueShouldBeTheOneAddedToRecordLogOnEmit() {
        givenEmbraceLogRecordBuilder()
        whenSetting(attribute: ["aKey": AttributeValue.string(UUID().uuidString)])
        whenSetting(attribute: ["aKey": AttributeValue.string("finalValue")])
        whenCallingEmit()
        thenProducedRecordHas(attribute: ["aKey": AttributeValue.string("finalValue")])
    }

    func test_onNotSettingTimeStamp_recordedLogOnEmitShouldHaveTimestamp() {
        givenEmbraceLogRecordBuilder()
        whenCallingEmit()
        thenProducedRecordHasTimestamp()
    }

    func test_onNotSettingObservedTimeStamp_recordedLogOnEmitShouldHaveObservedTimestamp() {
        givenEmbraceLogRecordBuilder()
        whenCallingEmit()
        thenProducedRecordHasObservedTimestamp()
    }
}

extension EmbraceLogRecordBuilderTests {
    fileprivate func givenEmbraceLogRecordBuilder() {
        sut = .init(sharedState: MockEmbraceLogSharedState(processors: [processor]), attributes: [:])
    }

    fileprivate func whenCallingEmit() {
        sut.emit()
    }

    fileprivate func whenSetting(timestamp: Date) {
        _ = sut.setTimestamp(timestamp)
    }

    fileprivate func whenSetting(observedTimestamp: Date) {
        _ = sut.setObservedTimestamp(observedTimestamp)
    }

    fileprivate func whenSetting(spanContext: SpanContext) {
        _ = sut.setSpanContext(spanContext)
    }

    fileprivate func whenSpanContextActive() -> SpanContext {
        let span = OpenTelemetry.instance.tracerProvider
            .get(instrumentationName: "test", instrumentationVersion: nil)
            .spanBuilder(spanName: "example-span")
            .setActive(true)
            .startSpan()

        OpenTelemetry.instance.contextProvider.setActiveSpan(span)

        return span.context
    }

    fileprivate func whenSetting(severity: Severity) {
        _ = sut.setSeverity(severity)
    }

    fileprivate func whenSetting(body: String) {
        _ = sut.setBody(.string(body))
    }

    fileprivate func whenSetting(attribute: [String: AttributeValue]) {
        _ = sut.setAttributes(attribute)
    }

    fileprivate func thenProducedRecordHas(attribute: [String: AttributeValue]) {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord)
        attribute.forEach {
            XCTAssertEqual(processor.receivedLogRecord?.attributes[$0.key], $0.value)
        }
    }

    fileprivate func thenProducedRecordHas(body: String) {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord)
        XCTAssertEqual(processor.receivedLogRecord?.body, .string(body))
    }

    fileprivate func thenProducedRecordHas(severity: Severity) {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord)
        XCTAssertEqual(processor.receivedLogRecord?.severity, severity)
    }

    fileprivate func thenProducedRecordHas(spanContext: SpanContext) {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord)
        XCTAssertEqual(processor.receivedLogRecord?.spanContext, spanContext)
    }

    fileprivate func thenProducedRecordHas(instrumentationInfo: InstrumentationScopeInfo) {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord)
        XCTAssertEqual(processor.receivedLogRecord?.instrumentationScopeInfo, instrumentationInfo)
    }

    fileprivate func thenProducedRecordHas(observedTimestamp: Date) {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord)
        XCTAssertEqual(processor.receivedLogRecord?.observedTimestamp, observedTimestamp)
    }

    fileprivate func thenProducedRecordHas(timestamp: Date) {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord)
        XCTAssertEqual(processor.receivedLogRecord?.timestamp, timestamp)
    }

    fileprivate func thenProducedRecordHasTimestamp() {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord?.timestamp)
    }

    fileprivate func thenProducedRecordHasObservedTimestamp() {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord?.observedTimestamp)
    }
}
