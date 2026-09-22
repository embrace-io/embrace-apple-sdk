//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

class URLEmbraceTests: XCTestCase {

    func test_endpoints_appendVersionedApiPath() {
        // the three telemetry endpoints append their versioned api path to the base
        let base = "https://example.com"
        XCTAssertEqual(URL.spansEndpoint(basePath: base)?.absoluteString, "https://example.com/v2/spans")
        XCTAssertEqual(URL.logsEndpoint(basePath: base)?.absoluteString, "https://example.com/v2/logs")
        XCTAssertEqual(URL.attachmentsEndpoint(basePath: base)?.absoluteString, "https://example.com/v2/attachments")
    }

}
