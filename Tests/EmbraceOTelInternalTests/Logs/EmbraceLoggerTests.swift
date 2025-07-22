//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import TestSupport
import XCTest

@testable import EmbraceOTelInternal

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

extension EmbraceLoggerTests {
    fileprivate func givenEmbraceLogger() {
        sut = .init(sharedState: MockEmbraceLogSharedState())
    }

    fileprivate func whenInvokingLogRecordBuilder() {
        logRecordBuilder = sut.logRecordBuilder()
    }

    fileprivate func whenInvokingEventBuilder(withName name: String = UUID().uuidString) {
        eventBuilder = sut.eventBuilder(name: name)
    }

    fileprivate func thenProducedBuilderIsEmbraceLogRecordBuilder() {
        XCTAssertTrue(logRecordBuilder is EmbraceLogRecordBuilder)
    }

    fileprivate func thenProducedEventBuilderIsEmbraceLogRecordBuilder() {
        XCTAssertTrue(eventBuilder is EmbraceLogRecordBuilder)
    }

    fileprivate func thenEventBuilderHas(attributes: [String: AttributeValue]) throws {
        let builder = try XCTUnwrap(eventBuilder as? EmbraceLogRecordBuilder)
        attributes.forEach {
            XCTAssertEqual(builder.attributes[$0.key], $0.value)
        }
    }
}
