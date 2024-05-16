//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceStorage

class EmbraceStorageOptionsTests: XCTestCase {

    func test_init_withBaseURLAndFileName() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        let options = EmbraceStorage.Options(baseUrl: url, fileName: "test.sqlite")

        XCTAssertNil(options.name)
        XCTAssertEqual(options.baseUrl, url)
        XCTAssertEqual(options.fileName, "test.sqlite")
        XCTAssertEqual(options.fileURL, url.appendingPathComponent("test.sqlite"))
    }

    func test_init_withName() {
        let options = EmbraceStorage.Options(named: "example")

        XCTAssertEqual(options.name, "example")
        XCTAssertNil(options.baseUrl)
        XCTAssertNil(options.fileName)
        XCTAssertNil(options.fileURL)
    }
}
