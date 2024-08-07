//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore
@testable import EmbraceOTelInternal
import EmbraceStorageInternal
import TestSupport

final class EmbraceSpanProcessor_StorageTests: XCTestCase {

    func test_spanProcessor_withStorage_usesStorageExporter() throws {
        let storage = try EmbraceStorage.createInMemoryDb()
        defer {
            try? storage.teardown()
        }
        let processor = SingleSpanProcessor(
            spanExporter: StorageSpanExporter(
                options: .init(storage: storage),
                logger: MockLogger()
            )
        )
        XCTAssert(processor.spanExporter is StorageSpanExporter)
    }
}
