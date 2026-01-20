//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorageInternal
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceOTelInternal

final class EmbraceSpanProcessor_StorageTests: XCTestCase {

    let sdkStateProvider = MockEmbraceSDKStateProvider()

    func test_spanProcessor_withStorage_usesStorageExporter() throws {
        let storage = try EmbraceStorage.createInMemoryDb()

        defer { storage.coreData.destroy() }

        let processor = EmbraceSpanProcessor(
            spanExporters: [
                StorageSpanExporter(
                    storage: storage,
                    logger: MockLogger()
                )
            ],
            sdkStateProvider: sdkStateProvider,
            criticalResourceGroup: DispatchGroup()
        )

        XCTAssert(processor.spanExporters.first is StorageSpanExporter)
    }
}
