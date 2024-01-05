//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore

final class CaptureServiceFactoryTests: XCTestCase {

    func test_requiredCaptureServices_returnsCorrectCaptureServiceTypes() throws {
        let services = CaptureServiceFactory.requiredServices

        XCTAssertEqual(services.count, 2)
        XCTAssertTrue(services.contains { $0 is AppInfoCaptureService })
        XCTAssertTrue(services.contains { $0 is DeviceInfoCaptureService })
    }
}
