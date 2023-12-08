//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommon
import EmbraceStorage
import OpenTelemetryApi
import UIKit
@testable import EmbraceOTel
@testable import EmbraceCore

class LowMemoryWarningCaptureServiceTests: XCTestCase {

    override func setUpWithError() throws {
        let storageOptions = EmbraceStorage.Options(named: #file)
        let storage = try EmbraceStorage(options: storageOptions)
        EmbraceOTel.setup(spanProcessor: .with(storage: storage))
    }

    func test_started() {
        // given a started service
        let service = LowMemoryWarningCaptureService()
        service.install(context: .testContext)
        service.start()

        let expectation = XCTestExpectation()
        service.onWarningCaptured = {
            expectation.fulfill()
        }

        // when a memory warning notification is received
        NotificationCenter.default.post(Notification(name: UIApplication.didReceiveMemoryWarningNotification))

        // then a span event is recorded
        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_notStarted() {
        // given a service that is not started
        let service = LowMemoryWarningCaptureService()
        service.install(context: .testContext)

        let expectation = XCTestExpectation()
        expectation.isInverted = true
        service.onWarningCaptured = {
            expectation.fulfill()
        }

        // when a memory warning notification is received
        NotificationCenter.default.post(Notification(name: UIApplication.didReceiveMemoryWarningNotification))

        // then a span event is not recorded
        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_stopped() {
        // given a service that is started
        let service = LowMemoryWarningCaptureService()
        service.install(context: .testContext)
        service.start()

        let expectation = XCTestExpectation()
        expectation.isInverted = true
        service.onWarningCaptured = {
            expectation.fulfill()
        }

        // when the service is stopped and a new notification is received
        service.stop()
        NotificationCenter.default.post(Notification(name: UIApplication.didReceiveMemoryWarningNotification))

        // then a span event is not recorded
        wait(for: [expectation], timeout: .defaultTimeout)
    }
}
