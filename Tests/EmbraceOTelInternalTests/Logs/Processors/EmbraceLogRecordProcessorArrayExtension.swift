//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk
import TestSupport
import XCTest

@testable import EmbraceOTelInternal

class EmbraceLogRecordProcessorArrayExtensionTests: XCTestCase {

    let sdkStateProvider = MockEmbraceSDKStateProvider()

    func test_onDefaultWithExporters_returnSingleLogRecordProcessorInstance() throws {
        let processors: [LogRecordProcessor] = .default(sdkStateProvider: sdkStateProvider)
        XCTAssertEqual(processors.count, 1)
        XCTAssertTrue(try XCTUnwrap(processors.first) is SingleLogRecordProcessor)
    }
}
