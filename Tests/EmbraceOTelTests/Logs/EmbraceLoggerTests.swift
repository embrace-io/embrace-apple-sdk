//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import OpenTelemetryApi

import TestSupport
@testable import EmbraceOTel

class EmbraceLoggerTests: XCTestCase {
    private var sut: EmbraceLogger!
    private var processor: SpyLoggerProcessor!
    private var logRecordBuilder: LogRecordBuilder!
    private var eventBuilder: EventBuilder!

    override func setUpWithError() throws {
        processor = .init()
    }

    func test_onInvokingLogRecordBuilder_producedBuilderIsEmbraceSpecific() {
        givenEmbraceLogger()
        whenInvokingLogRecordBuilder()
        thenProducedBuilderIsEmbraceLogRecordBuilder()
    }

    func test_onInvokingEventBuilder_instanceShouldBeEmbraceLogRecordBuilder() {
        givenEmbraceLogger()
        whenInvokingEventBuilder()
        thenProducedEventBuilderIsEmbraceLogRecordBuilder()
    }

    func testGivenLogger_onInvokingEventBuilder_attributesShouldBeEmptyAsWeDontSupportEventAPI() throws {
        givenEmbraceLogger()
        whenInvokingEventBuilder(withName: "embraceEventName")
        try thenEventBuilderHas(attributes: .empty())
    }
}

private extension EmbraceLoggerTests {
    func givenEmbraceLogger() {
        sut = .init(sharedState: .init(
            resource: .init(),
            config: DefaultEmbraceLoggerConfig(),
            processors: [processor]
        ))
    }

    func whenInvokingLogRecordBuilder() {
        logRecordBuilder = sut.logRecordBuilder()
    }

    func whenInvokingEventBuilder(withName name: String = UUID().uuidString) {
        eventBuilder = sut.eventBuilder(name: name)
    }

    func thenProducedBuilderIsEmbraceLogRecordBuilder() {
        XCTAssertTrue(logRecordBuilder is EmbraceLogRecordBuilder)
    }

    func thenProducedEventBuilderIsEmbraceLogRecordBuilder() {
        XCTAssertTrue(eventBuilder is EmbraceLogRecordBuilder)
    }

    func thenEventBuilderHas(attributes: [String: AttributeValue]) throws {
        let builder = try XCTUnwrap(eventBuilder as? EmbraceLogRecordBuilder)
        attributes.forEach {
            XCTAssertEqual(builder.attributes[$0.key], $0.value)
        }
    }
}
