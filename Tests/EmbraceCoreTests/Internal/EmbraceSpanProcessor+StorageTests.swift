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
        let sessionController = MockSessionController()

        defer { storage.coreData.destroy() }

        let processor = SingleSpanProcessor(
            spanExporter: StorageSpanExporter(
                options: .init(storage: storage, sessionController: sessionController),
                logger: MockLogger()
            ),
            sdkStateProvider: sdkStateProvider
        )
        XCTAssert(processor.spanExporter is StorageSpanExporter)
    }
}
