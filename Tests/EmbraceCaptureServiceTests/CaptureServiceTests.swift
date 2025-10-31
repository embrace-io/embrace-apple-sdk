//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCaptureService

class MockCaptureService: CaptureService {
    var installCalled = false
    override func onInstall() {
        installCalled = true
    }

    var startCalled = false
    override func onStart() {
        startCalled = true
    }

    var stopCalled = false
    override func onStop() {
        stopCalled = true
    }
}

class CaptureServiceTests: XCTestCase {

    func test_initialState() throws {
        // given a capture service
        let service = CaptureService()

        // then the initial state is correct
        XCTAssertEqual(service.state.load(), .uninstalled)
    }

    func test_installed() throws {
        // given a capture service
        let service = CaptureService()

        // when installing it
        service.install(otel: nil)

        // then the initial state is correct
        XCTAssertEqual(service.state.load(), .installed)
    }

    func test_active() throws {
        // given a capture service
        let service = CaptureService()

        // when installing and starting it
        service.install(otel: nil)
        service.start()

        // then the initial state is correct
        XCTAssertEqual(service.state.load(), .active)
    }

    func test_paused() throws {
        // given a capture service
        let service = CaptureService()

        // when installing, starting and stopping it
        service.install(otel: nil)
        service.start()
        service.stop()

        // then the initial state is correct
        XCTAssertEqual(service.state.load(), .paused)
    }

    func test_internalCalls() throws {
        // given a capture service
        let service = MockCaptureService()

        // when installing it
        service.install(otel: nil)

        // then onInstall is called
        XCTAssertTrue(service.installCalled)

        // when starting it
        service.start()

        // then onStart is called
        XCTAssertTrue(service.startCalled)

        // when stopping it
        service.stop()

        // then onStop is called
        XCTAssertTrue(service.stopCalled)
    }
}
