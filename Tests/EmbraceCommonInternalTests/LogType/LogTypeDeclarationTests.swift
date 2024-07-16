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

    // MARK: - Default
    func test_logTypeDefault_isSysLogString() {
        XCTAssertEqual(LogType.default.rawValue, "sys.log")
    }

    func test_logTypeDefault_isPrimarySystemAndSecondaryLog() {
        XCTAssertEqual(LogType.default, .init(primary: .system, secondary: "log"))
    }

    // MARK: - Breadcrumb
    func test_logTypeBreadcrumb_isSysBreadcrumbString() {
        XCTAssertEqual(LogType.breadcrumb.rawValue, "sys.breadcrumb")
    }

    func test_logTypeBreadcrumb_isPrimarySystemAndSecondaryBreadcrumb() {
        XCTAssertEqual(LogType.breadcrumb, .init(primary: .system, secondary: "breadcrumb"))
    }
}
