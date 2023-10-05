//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import UIKit
@testable import EmbraceIO

final class TapsCollectorTests: XCTestCase {
    func testInstall() {
        // Given
        let spy = TapsCollectorHandlerSpy()
        let expectedEvent = UIEvent()
        let collector = TapsCollector(handler: spy)
        collector.install()
        collector.start()
        
        //When
        UIWindow().sendEvent(expectedEvent)

        //Then
        XCTAssertEqual(spy.collectedEvent, expectedEvent)
    }
}

final class TapsCollectorHandlerSpy: TapCollectorHandlerType {
    var collectedEvent: UIEvent?

    func handleCollectedEvent(_ event: UIEvent) {
        collectedEvent = event
    }
}
