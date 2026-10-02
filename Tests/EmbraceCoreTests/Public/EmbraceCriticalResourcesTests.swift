//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceStorageInternal
import XCTest

@testable import EmbraceCore

final class EmbraceCriticalResourcesTests: XCTestCase {

    func test_init_storesCriticalResources() throws {
        // given a storage
        let storage = try EmbraceStorage.createInMemoryDb()
        defer { storage.coreData.destroy() }

        // when the client is initialized without starting it
        let client = try Embrace(
            options: .init(appId: "debug", captureServices: [], crashReporter: nil),
            embraceStorage: storage
        )
        XCTAssertNotNil(client)

        // then all critical resources are stored for the current process
        let expected = AppInfoCaptureService.criticalResources.merging(DeviceInfoCaptureService.criticalResources) { current, _ in current }
        XCTAssertFalse(expected.isEmpty)

        let resources = storage.fetchResourcesForProcessId(ProcessIdentifier.current)
        for (key, value) in expected {
            let resource = resources.first { $0.key == key }
            XCTAssertNotNil(resource, "Missing critical resource \(key)")
            XCTAssertEqual(resource?.value, value)
        }
    }
}
