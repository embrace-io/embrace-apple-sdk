//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceCommon

@testable import EmbraceIO

final class EmbraceSetupCaptureServicesTests: XCTestCase {

    class ExampleCaptureService: CaptureService {

        var didStart = false
        var didStop = false
        var available = true

        func setup(context: EmbraceCommon.CaptureServiceContext) { }

        func start() {
            didStart = true
        }

        func stop() {
            didStop = true
        }
    }

    class ExampleInstalledCaptureService: InstalledCaptureService {
        var didStart = false
        var didStop = false
        var available = true

        var didInstall = false
        var didShutdown = false

        func start() {
            didStart = true
        }

        func stop() {
            didStop = true
        }

        func install(context: EmbraceCommon.CaptureServiceContext) {
            didInstall = true
        }

        func uninstall() {
            didShutdown = true
        }
    }

    func test_EmbraceSetup_passesCaptureServices() throws {
        try Embrace.setup(options: .init(appId: "myAPP", captureServices: [
            ExampleCaptureService(),
            ExampleInstalledCaptureService()
        ]))

        let services = Embrace.client!.captureServices.services
        XCTAssertTrue(services.contains { $0 is ExampleCaptureService })
        XCTAssertTrue(services.contains { $0 is ExampleInstalledCaptureService })
    }
}
