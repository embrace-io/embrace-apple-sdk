//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

final class ProcessMetadataTests: XCTestCase {

    func test_startTime_isInThePast_doesNotReturnNil() {
        let startTime = ProcessMetadata.startTime
        XCTAssertNotNil(startTime)
        XCTAssertTrue(startTime! < Date())
    }

}
