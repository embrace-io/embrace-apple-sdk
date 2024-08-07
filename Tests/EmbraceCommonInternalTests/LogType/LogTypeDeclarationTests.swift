//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest

@testable import EmbraceCommonInternal

class LogTypeDeclarationTests: XCTestCase {
    // MARK: - System
    func test_logTypeSystem_isPrimarySystemSecondaryNil() {
        XCTAssertEqual(LogType.system, .system)
        XCTAssertNil(LogType.system.secondary)
    }

    func test_logTypeSystem_isSysString() {
        XCTAssertEqual(LogType.system.rawValue, "sys")
    }

    // MARK: - Message
    func test_logTypeMessage_isSysLogString() {
        XCTAssertEqual(LogType.message.rawValue, "sys.log")
    }

    func test_logTypeMessage_isPrimarySystemAndSecondaryLog() {
        XCTAssertEqual(LogType.message, .init(primary: .system, secondary: "log"))
    }
}
