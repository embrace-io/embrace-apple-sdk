//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCaptureService

class CaptureServiceOTelTests: XCTestCase {

    var otel: MockOTelSignalsHandler!
    var service: CaptureService!

    override func setUpWithError() throws {
        otel = MockOTelSignalsHandler()
        service = CaptureService()
        service.install(otel: otel)
    }

    override func tearDownWithError() throws {
        otel = nil
        service = nil
    }

    func test_createSpan_usesCaptureServiceSource() throws {
        // when creating a span from a capture service
        service.createSpan(name: "span")

        // then the span is created as a capture service signal
        XCTAssertEqual(otel.spanSources, [.captureService])
    }

    func test_addSessionEvent_usesCaptureServiceSource() throws {
        // when adding a session event from a capture service
        service.addSessionEvent(name: "event", type: nil, timestamp: Date(), attributes: [:])

        // then the event is added as a capture service signal
        XCTAssertEqual(otel.eventSources, [.captureService])
    }

    func test_log_usesCaptureServiceSource() throws {
        // when emitting a log from a capture service
        service.log("message")

        // then the log is emitted as a capture service signal
        XCTAssertEqual(otel.logSources, [.captureService])
    }

    func test_log_defaultType() throws {
        // when emitting a log without a type
        service.log("message")

        // then the log has the message type
        XCTAssertEqual(otel.logs.first?.type, .message)
    }

    func test_log_withType() throws {
        // when emitting a log with a type
        service.log("message", type: .crash)

        // then the log has the given type
        XCTAssertEqual(otel.logs.first?.type, .crash)
    }
}
