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

    func test_startBeforeInstall_isNoOp() throws {
        // given an uninstalled capture service
        let service = MockCaptureService()

        // when starting before installing
        service.start()

        // then it stays uninstalled and onStart is not called
        XCTAssertEqual(service.state.load(), .uninstalled)
        XCTAssertFalse(service.startCalled)
    }

    func test_stopBeforeStart_isNoOp() throws {
        // given an installed (but not started) capture service
        let service = MockCaptureService()
        service.install(otel: nil)

        // when stopping before starting
        service.stop()

        // then it stays installed and onStop is not called
        XCTAssertEqual(service.state.load(), .installed)
        XCTAssertFalse(service.stopCalled)
    }

    func test_install_isIdempotent() throws {
        // given an installed capture service
        let service = MockCaptureService()
        service.install(otel: nil)
        XCTAssertTrue(service.installCalled)

        // when installing again
        service.installCalled = false
        service.install(otel: nil)

        // then it remains installed and onInstall is not called a second time
        XCTAssertEqual(service.state.load(), .installed)
        XCTAssertFalse(service.installCalled)
    }

    func test_resumeFromPaused() throws {
        // given a paused capture service
        let service = MockCaptureService()
        service.install(otel: nil)
        service.start()
        service.stop()
        XCTAssertEqual(service.state.load(), .paused)

        // when starting again from paused
        service.startCalled = false
        service.start()

        // then it becomes active again and onStart is called
        XCTAssertEqual(service.state.load(), .active)
        XCTAssertTrue(service.startCalled)
    }
}
