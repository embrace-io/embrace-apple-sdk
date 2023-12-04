//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit)
import XCTest
import UIKit
@testable import EmbraceIO
import TestSupport

final class TapsCollectorTests: XCTestCase {
    func testInstall() {
        // Given
        let spy = TapsCollectorHandlerSpy()
        let expectedEvent = UIEvent()
        let collector = TapsCollector(handler: spy)
        collector.install(context: .testContext)
        collector.start()

        // When
        UIWindow().sendEvent(expectedEvent)

        // Then
        XCTAssertEqual(spy.collectedEvent, expectedEvent)
    }
}

final class TapsCollectorHandlerSpy: TapCollectorHandlerType {
    var collectedEvent: UIEvent?

    func handleCollectedEvent(_ event: UIEvent) {
        collectedEvent = event
    }
}
#endif
