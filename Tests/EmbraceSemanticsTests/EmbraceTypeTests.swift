//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceSemantics

class EmbraceTypeTests: XCTestCase {

    func test_rawValues() {
        let type1 = EmbraceType(primary: .performance, secondary: nil)
        let type2 = EmbraceType(primary: .performance, secondary: "test")
        XCTAssertEqual(type1.rawValue, "perf")
        XCTAssertEqual(type2.rawValue, "perf.test")

        let type3 = EmbraceType(primary: .ux, secondary: nil)
        let type4 = EmbraceType(primary: .ux, secondary: "test")
        XCTAssertEqual(type3.rawValue, "ux")
        XCTAssertEqual(type4.rawValue, "ux.test")

        let type5 = EmbraceType(primary: .system, secondary: nil)
        let type6 = EmbraceType(primary: .system, secondary: "test")
        XCTAssertEqual(type5.rawValue, "sys")
        XCTAssertEqual(type6.rawValue, "sys.test")
    }

    /// State spans serialize to the bare `"state"` — deliberately not abbreviated like
    /// `perf`/`ux`/`sys`, because that literal is the cross-platform wire contract.
    func test_stateRawValue() {
        XCTAssertEqual(EmbraceType.state.rawValue, "state")
        XCTAssertEqual(EmbraceType(primary: .state, secondary: nil).rawValue, "state")
    }

    /// Guards the deserialization half. `PrimaryType.init(name:)` falls back to `.performance` for
    /// unknown names, so a missing `"state"` case would silently read every persisted state span
    /// back as `perf` instead of failing.
    func test_stateRoundTrip() throws {
        let restored = try XCTUnwrap(EmbraceType(rawValue: "state"))
        XCTAssertEqual(restored.primary, .state)
        XCTAssertNil(restored.secondary)
        XCTAssertEqual(restored, EmbraceType.state)
        XCTAssertEqual(restored.rawValue, "state")
    }
}
