//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import TestSupport
import XCTest

@testable import EmbraceCore

class EmbraceSetupTests: XCTestCase {
    override func tearDown() {
        _ = try? Embrace.client?.stop()
        Embrace.client = nil
        super.tearDown()
    }

    func test_setupOnNonMainThread_shouldThrowInvalidThreadError() {
        let expectation = expectation(description: testName)
        DispatchQueue(label: "myThread").async {
            do {
                try Embrace.setup(
                    options: .init(
                        appId: "-----",
                        captureServices: [],
                        crashReporter: nil
                    )
                )
                XCTFail("This should've thrown an error")
                expectation.fulfill()
            } catch let exception {
                if case .invalidThread(_) = exception as? EmbraceSetupError {
                    // The description isn’t important; what matters is that the case is correct
                    XCTAssertTrue(true)
                } else {
                    XCTFail("Wrong EmbraceSetupError was thrown \(exception)")
                }
                expectation.fulfill()
            }
        }
        wait(for: [expectation])
    }

    func test_startWhenDisabled_transitionsToStopped_andReleasesCaptureServicesGate() throws {
        let runtimeConfig = MockEmbraceConfigurable(isSDKEnabled: false)

        let client = try Embrace.setup(
            options: .init(
                captureServices: [],
                crashReporter: nil,
                runtimeConfiguration: runtimeConfig
            )
        )

        XCTAssertEqual(client.state, .initialized)

        try client.start()

        XCTAssertEqual(client.state, .stopped)
        XCTAssertFalse(client.isSDKEnabled)
        XCTAssertEqual(client.captureServicesGroup.wait(timeout: .now()), .success)
    }

    func test_startAfterDisabledStart_isNoOp_evenIfConfigBecomesEnabled() throws {
        let runtimeConfig = MockEmbraceConfigurable(isSDKEnabled: false)

        let client = try Embrace.setup(
            options: .init(
                captureServices: [],
                crashReporter: nil,
                runtimeConfiguration: runtimeConfig
            )
        )

        try client.start()
        XCTAssertEqual(client.state, .stopped)

        runtimeConfig.isSDKEnabled = true
        try client.start()

        XCTAssertEqual(client.state, .stopped)
        XCTAssertFalse(client.isSDKEnabled)
        XCTAssertNil(client.currentSessionId())
        XCTAssertNil(client.currentUserSessionId())
    }
}
