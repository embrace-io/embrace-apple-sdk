//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest
import OpenTelemetrySdk
@testable import EmbraceOTelInternal
import TestSupport

class EmbraceLogRecordProcessorArrayExtensionTests: XCTestCase {

    let sdkStateProvider = MockEmbraceSDKStateProvider()

    func test_onDefaultWithExporters_returnSingleLogRecordProcessorInstance() throws {
        let processors: [LogRecordProcessor] = .default(withExporters: [], sdkStateProvider: sdkStateProvider)
        XCTAssertEqual(processors.count, 1)
        XCTAssertTrue(try XCTUnwrap(processors.first) is SingleLogRecordProcessor)
    }
}
