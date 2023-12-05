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
@testable import EmbraceIO

// swiftlint:disable force_cast

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

        // when a memory warning notification is received
        NotificationCenter.default.post(Notification(name: UIApplication.didReceiveMemoryWarningNotification))

        // then a span event is recorded
        // TODO: Need session span to test this!
    }

    func test_notStarted() {
        // given a service that is not started
        let service = LowMemoryWarningCaptureService()
        service.install(context: .testContext)

        // when a memory warning notification is received
        NotificationCenter.default.post(Notification(name: UIApplication.didReceiveMemoryWarningNotification))

        // then a span event is not recorded
        // TODO: Need session span to test this!
    }

    func test_stopped() {
        // given a service that is started
        let service = LowMemoryWarningCaptureService()
        service.install(context: .testContext)
        service.start()

        // when the service is stopped and a new notification is received
        service.stop()
        NotificationCenter.default.post(Notification(name: UIApplication.didReceiveMemoryWarningNotification))

        // then a span event is not recorded
        // TODO: Need session span to test this!
    }
}

// swiftlint:enable force_cast
