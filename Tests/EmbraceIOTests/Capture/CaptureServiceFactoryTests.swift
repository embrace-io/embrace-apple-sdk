//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceIO
import EmbraceCrash

final class CaptureServiceFactoryTests: XCTestCase {

    func test_requiredCaptureServices_returnsCorrectCaptureServiceTypes() throws {
        let services = CaptureServiceFactory.requiredServices

        XCTAssertEqual(services.count, 2)
        XCTAssertTrue(services.contains { $0 is AppInfoCaptureService })
        XCTAssertTrue(services.contains { $0 is DeviceInfoCaptureService })
    }

    #if os(iOS)
    func test_platformCaptureServices_returnsCorrectCaptureServiceTypes() {
        let services = CaptureServiceFactory.platformCaptureServices

        XCTAssertEqual(services.count, 1)
        XCTAssertTrue(services.first is EmbraceCrashReporter)
    }
    #else
    func test_platformCaptureServices_returnsCorrectCaptureServiceTypes() throws {
        let services = CaptureServiceFactory.platformCaptureServices

        XCTAssertEqual(services.count, 0)
    }
    #endif
}
