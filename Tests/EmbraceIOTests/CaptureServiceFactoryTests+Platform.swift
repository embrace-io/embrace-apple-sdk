//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
@testable import EmbraceIO
import EmbraceCrash

final class CaptureServiceFactoryTests: XCTestCase {
#if os(iOS)
    func test_platformCaptureServices_returnsCorrectCaptureServiceTypes() {
        let services = CaptureServiceFactory.platformCaptureServices

        XCTAssertEqual(services.count, 4)
        XCTAssertTrue(services.contains { $0 is URLSessionCaptureService })
        XCTAssertTrue(services.contains { $0 is TapCaptureService })
        XCTAssertTrue(services.contains { $0 is LowMemoryWarningCaptureService })
        XCTAssertTrue(services.contains { $0 is LowPowerModeCaptureService })
    }
#else
    func test_platformCaptureServices_returnsCorrectCaptureServiceTypes() throws {
        let services = CaptureServiceFactory.platformCaptureServices

        XCTAssertEqual(services.count, 0)
    }
#endif
}
