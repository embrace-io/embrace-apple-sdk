//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceUploadInternal

class EmbraceUploadCacheOptionsTests: XCTestCase {

    func test_validCacheBaseUrl() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        let options = EmbraceUpload.CacheOptions(cacheBaseUrl: url)

        XCTAssertNotNil(options)
    }

    func test_invalidCacheBaseUrl() {
        if let url = URL(string: "https://embrace.io/") {
            let options = EmbraceUpload.CacheOptions(cacheBaseUrl: url)

            XCTAssertNil(options)
        }
    }
}
