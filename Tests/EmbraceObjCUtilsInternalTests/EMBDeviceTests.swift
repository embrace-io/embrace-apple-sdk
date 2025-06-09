//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@_implementationOnly import EmbraceObjCUtilsInternal

final class EMBDeviceTests: XCTestCase {

// MARK: - Operating System
    func test_operatingSystemVersion_returnsCorrectVersion() {
        let version = EMBDevice.operatingSystemVersion

        let processVersion = ProcessInfo.processInfo.operatingSystemVersion
        if processVersion.patchVersion == 0 {
            // should not contain patch version
            let expectedVersion = "\(processVersion.majorVersion).\(processVersion.minorVersion)"
            XCTAssertEqual(version, expectedVersion)
        } else {
            // should contain patch version
            let expectedVersion = "\(processVersion.majorVersion).\(processVersion.minorVersion).\(processVersion.patchVersion)"
            XCTAssertEqual(version, expectedVersion)
        }
    }
}
