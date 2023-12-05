//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit)
import XCTest
import UIKit
@testable import EmbraceIO
import TestSupport

final class TapsCaptureServiceTests: XCTestCase {
    func testInstall() {
        // Given
        let spy = TapsCaptureServiceHandlerSpy()
        let expectedEvent = UIEvent()

        let service = TapsCaptureService(handler: spy)
        service.install(context: .testContext)
        service.start()

        // When
        UIWindow().sendEvent(expectedEvent)

        // Then
        XCTAssertEqual(spy.collectedEvent, expectedEvent)
    }
}

final class TapsCaptureServiceHandlerSpy: TapCaptureServiceHandlerType {
    var collectedEvent: UIEvent?

    func handleCapturedEvent(_ event: UIEvent) {
        collectedEvent = event
    }
}
#endif
