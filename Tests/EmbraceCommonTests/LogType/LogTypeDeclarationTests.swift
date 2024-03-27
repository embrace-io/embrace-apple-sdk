//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest

@testable import EmbraceCommon

class LogTypeDeclarationTests: XCTestCase {
    // MARK: - System
    func test_logTypeSystem_isPrimarySystemSecondaryNil() {
        XCTAssertEqual(LogType.system, .system)
        XCTAssertNil(LogType.system.secondary)
    }

    func test_logTypeSystem_isSysString() {
        XCTAssertEqual(LogType.system.rawValue, "sys")
    }

    // MARK: - Default
    func test_logTypeDefault_isSysLogString() {
        XCTAssertEqual(LogType.default.rawValue, "sys.log")
    }

    func test_logTypeDefault_isPrimarySystemAndSecondaryLog() {
        XCTAssertEqual(LogType.default, .init(primary: .system, secondary: "log"))
    }
}
