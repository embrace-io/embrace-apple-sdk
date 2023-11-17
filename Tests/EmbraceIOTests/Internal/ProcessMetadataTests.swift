//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceIO

final class ProcessMetadataTests: XCTestCase {

    func test_startTime_isInThePast_doesNotReturnNil() {
        let startTime = ProcessMetadata.startTime
        XCTAssertNotNil(startTime)
        XCTAssertTrue(startTime! < Date())
    }

    func test_uptime_isPositive_doesNotReturnNil() {
        let uptime = ProcessMetadata.uptime()
        XCTAssertNotNil(uptime)
        XCTAssertTrue(uptime! > 0)
    }

}
