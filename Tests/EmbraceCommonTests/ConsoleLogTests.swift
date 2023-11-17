//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCommon

class ConsoleLogTests: XCTestCase {
    override func tearDown() {
        ConsoleLog.shared.level = .debug
    }

    func test_none() {
        ConsoleLog.shared.level = .none

        XCTAssertFalse(ConsoleLog.trace("trace"))
        XCTAssertFalse(ConsoleLog.debug("debug"))
        XCTAssertFalse(ConsoleLog.info("info"))
        XCTAssertFalse(ConsoleLog.warning("warning"))
        XCTAssertFalse(ConsoleLog.error("error"))
    }

    func test_trace() {
        ConsoleLog.shared.level = .trace

        XCTAssert(ConsoleLog.trace("trace"))
        XCTAssert(ConsoleLog.debug("debug"))
        XCTAssert(ConsoleLog.info("info"))
        XCTAssert(ConsoleLog.warning("warning"))
        XCTAssert(ConsoleLog.error("error"))
    }

    func test_debug() {
        ConsoleLog.shared.level = .debug

        XCTAssertFalse(ConsoleLog.trace("trace"))
        XCTAssert(ConsoleLog.debug("debug"))
        XCTAssert(ConsoleLog.info("info"))
        XCTAssert(ConsoleLog.warning("warning"))
        XCTAssert(ConsoleLog.error("error"))
    }

    func test_info() {
        ConsoleLog.shared.level = .info

        XCTAssertFalse(ConsoleLog.trace("trace"))
        XCTAssertFalse(ConsoleLog.debug("debug"))
        XCTAssert(ConsoleLog.info("info"))
        XCTAssert(ConsoleLog.warning("warning"))
        XCTAssert(ConsoleLog.error("error"))
    }

    func test_warning() {
        ConsoleLog.shared.level = .warning

        XCTAssertFalse(ConsoleLog.trace("trace"))
        XCTAssertFalse(ConsoleLog.debug("debug"))
        XCTAssertFalse(ConsoleLog.info("info"))
        XCTAssert(ConsoleLog.warning("warning"))
        XCTAssert(ConsoleLog.error("error"))
    }

    func test_error() {
        ConsoleLog.shared.level = .error

        XCTAssertFalse(ConsoleLog.trace("trace"))
        XCTAssertFalse(ConsoleLog.debug("debug"))
        XCTAssertFalse(ConsoleLog.info("info"))
        XCTAssertFalse(ConsoleLog.warning("warning"))
        XCTAssert(ConsoleLog.error("error"))
    }
}
