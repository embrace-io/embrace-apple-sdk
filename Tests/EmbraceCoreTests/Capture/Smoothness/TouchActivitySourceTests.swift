//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import XCTest
    import UIKit

    @testable import EmbraceCore

    final class TouchActivitySourceTests: SwizzlerTestCase {

        override func tearDownWithError() throws {
            restoreSwizzleCacheAdditions()
            try super.tearDownWithError()
        }

        func test_touchBegan_firesOnTouch() throws {
            let source = TouchActivitySource()
            var touchCount = 0
            source.onTouch = { touchCount += 1 }

            let event = MockTapEvent(mockedTouches: [MockUITouch(phase: .began)])
            UIWindow().sendEvent(event)

            XCTAssertEqual(touchCount, 1)
        }

        func test_touchMoved_firesOnTouch() throws {
            let source = TouchActivitySource()
            var touchCount = 0
            source.onTouch = { touchCount += 1 }

            let event = MockTapEvent(mockedTouches: [MockUITouch(phase: .moved)])
            UIWindow().sendEvent(event)

            XCTAssertEqual(touchCount, 1)
        }

        func test_touchEnded_firesOnTouch() throws {
            let source = TouchActivitySource()
            var touchCount = 0
            source.onTouch = { touchCount += 1 }

            let event = MockTapEvent(mockedTouches: [MockUITouch(phase: .ended)])
            UIWindow().sendEvent(event)

            XCTAssertEqual(touchCount, 1)
        }

        func test_multipleSources_allFire() throws {
            // given two independently-installed sources, mirroring how a touch-activity source
            // and another swizzler on the same selector (e.g. TapCaptureService) can coexist
            let source1 = TouchActivitySource()
            let source2 = TouchActivitySource()
            var count1 = 0
            var count2 = 0
            source1.onTouch = { count1 += 1 }
            source2.onTouch = { count2 += 1 }

            let event = MockTapEvent(mockedTouches: [MockUITouch(phase: .began)])
            UIWindow().sendEvent(event)

            XCTAssertEqual(count1, 1)
            XCTAssertEqual(count2, 1)
        }

        func test_noTouches_doesNotFire() throws {
            let source = TouchActivitySource()
            var touchCount = 0
            source.onTouch = { touchCount += 1 }

            let event = MockTapEvent(mockedTouches: [])
            UIWindow().sendEvent(event)

            XCTAssertEqual(touchCount, 0)
        }
    }

#endif
