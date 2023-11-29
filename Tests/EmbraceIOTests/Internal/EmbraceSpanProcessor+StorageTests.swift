//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceIO
@testable import EmbraceOTel
import EmbraceStorage

final class EmbraceSpanProcessor_StorageTests: XCTestCase {

    func test_spanProcessor_withStorage_usesStorageExporter() throws {
        let storage = try EmbraceStorage(options: .init(named: #file))
        let processor = SingleSpanProcessor.with(storage: storage)
        XCTAssert(processor.spanExporter is StorageSpanExporter)
    }
}
