//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import XCTest
    import UIKit
    @testable import EmbraceCore

    final class UIWindowScreenLoadTapSourceTests: XCTestCase {

        private var source: UIWindowScreenLoadTapSource!
        private var tapUps: [TimeInterval]!

        override func setUp() {
            super.setUp()
            tapUps = []
            source = UIWindowScreenLoadTapSource()
            source.onTapUp = { [unowned self] in tapUps.append($0) }
        }

        override func tearDown() {
            source = nil
            tapUps = nil
            super.tearDown()
        }

        func test_ended_reportsEventTimestamp() {
            // given a source with a listener

            // when a touch ends
            source.handle(event([.ended], timestamp: 12.5))

            // then the tap up is reported with the event timestamp
            XCTAssertEqual(tapUps, [12.5])
        }

        func test_otherPhases_areIgnored() {
            // given a source with a listener

            // when touches begin, move, stay still or are cancelled
            source.handle(event([.began], timestamp: 1))
            source.handle(event([.moved], timestamp: 2))
            source.handle(event([.stationary], timestamp: 3))
            source.handle(event([.cancelled], timestamp: 4))

            // then no tap up is reported
            XCTAssertEqual(tapUps, [])
        }

        func test_endedWhileAnotherTouchIsDown_isIgnored() {
            // given a source with a listener

            // when a touch ends while another is still down
            source.handle(event([.ended, .stationary], timestamp: 1))
            source.handle(event([.ended, .moved], timestamp: 2))

            // then no tap up is reported
            XCTAssertEqual(tapUps, [])
        }

        func test_endedAndCancelled_isIgnored() {
            // given a source with a listener

            // when one touch ends and another is cancelled
            source.handle(event([.ended, .cancelled], timestamp: 3))

            // then no tap up is reported
            XCTAssertEqual(tapUps, [])
        }

        func test_allCancelled_isIgnored() {
            // given a source with a listener

            // when every touch is cancelled
            source.handle(event([.cancelled, .cancelled], timestamp: 3))

            // then no tap up is reported
            XCTAssertEqual(tapUps, [])
        }

        func test_nonTouchEvent_isIgnored() {
            // given a source with a listener

            // when a non-touch event ends
            source.handle(event([.ended], type: .presses, timestamp: 3))

            // then no tap up is reported
            XCTAssertEqual(tapUps, [])
        }

        func test_noTouches_isIgnored() {
            // given a source with a listener

            // when a touch event has no touches
            source.handle(MockTapEvent(mockedTouches: [], timestamp: 3))

            // then no tap up is reported
            XCTAssertEqual(tapUps, [])
        }

        func test_noListener_doesNothing() {
            // given a source without a listener
            source.onTapUp = nil

            // when a touch ends
            source.handle(event([.ended], timestamp: 5))

            // then no tap up is reported
            XCTAssertEqual(tapUps, [])
        }

        private func event(
            _ phases: [UITouch.Phase],
            type: UIEvent.EventType = .touches,
            timestamp: TimeInterval
        ) -> MockTapEvent {
            MockTapEvent(mockedTouches: Set(phases.map { MockUITouch(phase: $0) }), type: type, timestamp: timestamp)
        }
    }
#endif
