//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import XCTest
    import UIKit
    @testable import EmbraceCore
    import TestSupport

    final class WindowEventObserverTests: SwizzlerTestCase {

        private var observer: WindowEventObserver!

        override func setUpWithError() throws {
            try super.setUpWithError()
            observer = WindowEventObserver()
        }

        override func tearDownWithError() throws {
            observer = nil
            restoreSwizzleCacheAdditions()
            try super.tearDownWithError()
        }

        func test_handlers_eachReceiveEventOnce() throws {
            // two handlers share one swizzle, so neither sees an event twice
            var first: [UIEvent] = []
            var second: [UIEvent] = []
            try observer.add { first.append($0) }
            try observer.add { second.append($0) }

            let event = MockTapEvent(mockedTouches: [MockUITouch()])
            UIWindow().sendEvent(event)

            XCTAssertEqual(first.count, 1)
            XCTAssertTrue(first.first === event)
            XCTAssertEqual(second.count, 1)
            XCTAssertTrue(second.first === event)
        }

        func test_removedHandler_receivesNothing() throws {
            var removed = 0
            var kept = 0
            let token = try observer.add { _ in removed += 1 }
            try observer.add { _ in kept += 1 }

            observer.remove(token)
            UIWindow().sendEvent(MockTapEvent(mockedTouches: [MockUITouch()]))

            XCTAssertEqual(removed, 0)
            XCTAssertEqual(kept, 1)
        }

        func test_tapCapture_stillCapturesAlongsideOtherHandlers() throws {
            let otel = MockOTelSignalsHandler()
            let service = TapCaptureService(options: .init(), lock: NSLock(), windowEventObserver: observer)
            service.install(otel: otel)
            service.start()

            var other = 0
            try observer.add { _ in other += 1 }
            UIWindow().sendEvent(MockTapEvent(mockedTouches: [MockUITouch(touchedView: UIView())]))

            XCTAssertEqual(other, 1)
            XCTAssertEqual(otel.events.count, 1)
        }
    }

#endif
