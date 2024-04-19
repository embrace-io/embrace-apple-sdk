//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore

class CGPointToStringTests: XCTestCase {
    func test_toString_ReturnsXAndYPointsSeparatedByComma() {
        XCTAssertEqual("1,2", CGPoint(x: 1, y: 2).toString())
        XCTAssertEqual("-1,-2", CGPoint(x: -1, y: -2).toString())
    }

    func test_toString_TruncatesEachPoint() {
        XCTAssertEqual("1,2", CGPoint(x: 1.234456, y: 2.987654).toString())
    }
}
