//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
@testable import EmbraceOTel
import EmbraceStorage

final class EmbraceSpanProcessor_StorageTests: XCTestCase {

    func test_spanProcessor_withStorage_usesStorageExporter() throws {
        let storage = try EmbraceStorage.createInMemoryDb()
        defer {
            try? storage.teardown()
        }
        let processor = SingleSpanProcessor.with(storage: storage)
        XCTAssert(processor.spanExporter is StorageSpanExporter)
    }
}
