//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import OpenTelemetryApi
import OpenTelemetrySdk

@testable import EmbraceOTel

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
        let spanContext = SpanContext.create(traceId: .random(),
                                         spanId: .random(),
                                         traceFlags: .init(),
                                         traceState: .init())
        givenEmbraceLogRecordBuilder()
        whenSetting(spanContext: spanContext)
        whenCallingEmit()
        thenProducedRecordHas(spanContext: spanContext)
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

private extension EmbraceLogRecordBuilderTests {
    func givenEmbraceLogRecordBuilder() {
        sut = .init(sharedState: MockEmbraceLogSharedState(processors: [processor]), attributes: [:])
    }

    func whenCallingEmit() {
        sut.emit()
    }

    func whenSetting(timestamp: Date) {
        _ = sut.setTimestamp(timestamp)
    }

    func whenSetting(observedTimestamp: Date) {
        _ = sut.setObservedTimestamp(observedTimestamp)
    }

    func whenSetting(spanContext: SpanContext) {
        _ = sut.setSpanContext(spanContext)
    }

    func whenSetting(severity: Severity) {
        _ = sut.setSeverity(severity)
    }

    func whenSetting(body: String) {
        _ = sut.setBody(body)
    }

    func whenSetting(attribute: [String: AttributeValue]) {
        _ = sut.setAttributes(attribute)
    }

    func thenProducedRecordHas(attribute: [String: AttributeValue]) {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord)
        attribute.forEach {
            XCTAssertEqual(processor.receivedLogRecord?.attributes[$0.key], $0.value)
        }
    }

    func thenProducedRecordHas(body: String) {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord)
        XCTAssertEqual(processor.receivedLogRecord?.body, body)
    }

    func thenProducedRecordHas(severity: Severity) {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord)
        XCTAssertEqual(processor.receivedLogRecord?.severity, severity)
    }

    func thenProducedRecordHas(spanContext: SpanContext) {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord)
        XCTAssertEqual(processor.receivedLogRecord?.spanContext, spanContext)
    }

    func thenProducedRecordHas(instrumentationInfo: InstrumentationScopeInfo) {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord)
        XCTAssertEqual(processor.receivedLogRecord?.instrumentationScopeInfo, instrumentationInfo)
    }

    func thenProducedRecordHas(observedTimestamp: Date) {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord)
        XCTAssertEqual(processor.receivedLogRecord?.observedTimestamp, observedTimestamp)
    }

    func thenProducedRecordHas(timestamp: Date) {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord)
        XCTAssertEqual(processor.receivedLogRecord?.timestamp, timestamp)
    }

    func thenProducedRecordHasTimestamp() {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord?.timestamp)
    }

    func thenProducedRecordHasObservedTimestamp() {
        XCTAssertTrue(processor.didCallOnEmit)
        XCTAssertNotNil(processor.receivedLogRecord?.observedTimestamp)
    }
}
