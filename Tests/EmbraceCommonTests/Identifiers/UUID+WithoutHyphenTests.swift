//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore

final class UUID_WithoutHyphenTests: XCTestCase {

    func test_initWithoutHyphen_returnsUUID_whenValid_nilOtherwise() {
        XCTAssertNil(UUID(withoutHyphen: ""))
        XCTAssertNil(UUID(withoutHyphen: "343C6D56D07"))

        XCTAssertNil(UUID(withoutHyphen: String(repeating: "z", count: 32)))
        XCTAssertNil(UUID(withoutHyphen: String(repeating: "-", count: 32)))

        XCTAssertNotNil(UUID(withoutHyphen: String(repeating: "a", count: 32)))
        XCTAssertNotNil(UUID(withoutHyphen: String(repeating: "0", count: 32)))

        XCTAssertEqual(
            UUID(withoutHyphen: "343C6D56D07644B2AD650025CF5866FF"),
            UUID(uuidString: "343C6D56-D076-44B2-AD65-0025CF5866FF")
        )
    }

    func test_initWithoutHyphen_returnsUUID_whenStringHasHyphens() {
        XCTAssertEqual(
            UUID(withoutHyphen: "343C6D56-D076-44B2-AD65-0025CF5866FF"),
            UUID(uuidString: "343C6D56-D076-44B2-AD65-0025CF5866FF")
        )
    }

    func test_withoutHyphen_stripsHyphens() {
        XCTAssertEqual(
            UUID(uuidString: "343C6D56-D076-44B2-AD65-0025CF5866FF")?.withoutHyphen,
            "343C6D56D07644B2AD650025CF5866FF"
        )
    }

}
