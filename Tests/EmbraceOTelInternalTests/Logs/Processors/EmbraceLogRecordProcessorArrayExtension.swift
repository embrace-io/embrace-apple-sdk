//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest

import OpenTelemetrySdk

@testable import EmbraceOTelInternal

class EmbraceLogRecordProcessorArrayExtensionTests: XCTestCase {
    func test_onDefaultWithExporters_returnSingleLogRecordProcessorInstance() throws {
        let processors: [EmbraceLogRecordProcessor] = .default(withExporters: [])
        XCTAssertEqual(processors.count, 1)
        XCTAssertTrue(try XCTUnwrap(processors.first) is SingleLogRecordProcessor)
    }
}
