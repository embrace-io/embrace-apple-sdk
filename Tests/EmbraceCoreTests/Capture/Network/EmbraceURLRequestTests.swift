//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import TestSupport
import XCTest

@testable import EmbraceCore

class URLSessionExtensionTests: XCTestCase {
    private var sut: URLRequest!

    override func setUpWithError() throws {
        sut = URLRequest(url: URL(string: "https://www.embrace.io")!)
    }

    func test_addEmbraceHeaders_addsUUIDAsIdHeader() throws {
        let result = sut.addEmbraceHeaders()
        let id = try XCTUnwrap(result.allHTTPHeaderFields?["x-emb-id"])
        XCTAssertTrue(id.isUUID)
    }

    func test_addEmbraceHeaders_addsCurrentDateSerializedIntervalAsStartTimeHeader() throws {
        let result = sut.addEmbraceHeaders()
        let startTime = try XCTUnwrap(result.allHTTPHeaderFields?["x-emb-st"])
        XCTAssertLessThanOrEqual(Double(startTime)!, Date().timeIntervalSince1970 * 1000.0)
    }
}
