//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceIO
import XCTest

/// Only `EmbraceIO` is imported in this file, so it only compiles if everything needed to write a capture service is reachable from it.
final class EmbraceIOPublicInterfaceTests: XCTestCase {

    func test_captureService_canBeSubclassedImportingOnlyEmbraceIO() {
        // given a capture service written with only the EmbraceIO import
        let service = PublicInterfaceCaptureService()

        // then it's a capture service that can be added to the SDK
        let captureService: CaptureService = service
        XCTAssertTrue(captureService.isUninstalled)
        EmbraceIO.shared.add(captureService: service)
    }
}

private final class PublicInterfaceCaptureService: CaptureService {
    var config: EmbraceConfigurable?

    override func onConfigUpdated(_ config: EmbraceConfigurable) {
        self.config = config
    }
}
