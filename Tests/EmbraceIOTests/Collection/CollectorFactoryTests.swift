//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceIO
import EmbraceCrash

final class CollectorFactoryTests: XCTestCase {

    func test_requiredCollectors_returnsCorrectCollectorTypes() throws {
        let collectors = CollectorFactory.requiredCollectors

        XCTAssertEqual(collectors.count, 2)
        XCTAssertTrue(collectors.contains { $0 is AppInfoCollector })
        XCTAssertTrue(collectors.contains { $0 is DeviceInfoCollector })
    }

    #if os(iOS)
    func test_platformCollectors_returnsCorrectCollectorTypes() {
        let collectors = CollectorFactory.platformCollectors
        XCTAssertEqual(collectors.count, 1)

        XCTAssertTrue(collectors.first is EmbraceCrashReporter)
    }
    #else
    func test_platformCollectors_returnsCorrectCollectorTypes() throws {
        let collectors = CollectorFactory.platformCollectors
        XCTAssertEqual(collectors.count, 0)
    }
    #endif
}
