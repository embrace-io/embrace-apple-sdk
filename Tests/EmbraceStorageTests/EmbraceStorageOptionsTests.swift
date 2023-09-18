//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceStorage

class EmbraceStorageOptionsTests: XCTestCase {

    func test_validBaseUrl() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        let options = EmbraceStorageOptions(baseUrl: url, fileName: "test.sqlite")

        XCTAssertNotNil(options)
    }

    func test_invalidBaseUrl() {
        if let url = URL(string: "https://embrace.io/") {
            let options = EmbraceStorageOptions(baseUrl: url, fileName: "test.sqlite")

            XCTAssertNil(options)
        }
    }
}
