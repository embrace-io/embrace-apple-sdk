//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import XCTest
    import TestSupport
    import EmbraceCommonInternal
    import UIKit
    @testable import EmbraceCore

    class LowMemoryWarningCaptureServiceTests: XCTestCase {
        private var otel: MockEmbraceOpenTelemetry!

        override func setUpWithError() throws {
            otel = MockEmbraceOpenTelemetry()
        }

        override func tearDownWithError() throws {
            otel = nil
        }

        func test_started() {
            // given a started service
            let service = LowMemoryWarningCaptureService()
            service.install(otel: otel)
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
            service.install(otel: otel)

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
            service.install(otel: otel)
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
#endif
