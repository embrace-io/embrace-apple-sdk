//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if !os(watchOS) && !os(macOS)

    import TestSupport
    import XCTest

    @testable import EmbraceCore

    final class DisplayLinkFrameDisplayedSourceTests: XCTestCase {

        private var source: DisplayLinkFrameDisplayedSource!

        override func setUp() {
            super.setUp()
            source = DisplayLinkFrameDisplayedSource()
        }

        override func tearDown() {
            source.stop()
            source = nil
            super.tearDown()
        }

        /// Waits for the source to report a frame, spinning the main run loop until it does.
        @discardableResult
        private func waitForNextFrame() -> TimeInterval {
            let frame = expectation(description: "frame displayed")
            var timestamp: TimeInterval = 0
            source.requestNextFrame {
                timestamp = $0
                frame.fulfill()
            }
            wait(for: [frame], timeout: .longTimeout)
            return timestamp
        }

        /// Records whether the main run loop has passed the point where Core Animation commits.
        private func observeCommits() -> (passed: () -> Bool, remove: () -> Void) {
            var passed = false
            let observer = CFRunLoopObserverCreateWithHandler(
                kCFAllocatorDefault,
                CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.exit.rawValue,
                true,
                DisplayLinkFrameDisplayedSource.coreAnimationCommitOrder
            ) { _, _ in
                passed = true
            }
            CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
            return ({ passed }, { CFRunLoopObserverInvalidate(observer) })
        }

        func test_request_firesOnceAfterCommit_onUptimeClock() {
            // given a request
            let commits = observeCommits()
            defer { commits.remove() }
            let before = ProcessInfo.processInfo.systemUptime
            let frame = expectation(description: "frame displayed")
            var timestamps: [TimeInterval] = []
            var firedAfterCommit = false
            source.requestNextFrame {
                timestamps.append($0)
                firedAfterCommit = commits.passed()
                frame.fulfill()
            }

            // it doesn't fire synchronously
            XCTAssertTrue(timestamps.isEmpty)

            // when the run loop commits and displays a frame
            wait(for: [frame], timeout: .longTimeout)
            let after = ProcessInfo.processInfo.systemUptime

            // and later frames are displayed
            waitForNextFrame()

            // then it fired exactly once, after a commit, with a time on the uptime clock
            XCTAssertEqual(timestamps.count, 1)
            XCTAssertTrue(firedAfterCommit)
            XCTAssertGreaterThanOrEqual(timestamps[0], before)
            XCTAssertLessThanOrEqual(timestamps[0], after)
        }

        func test_waitersInOneBatch_shareOneFrame() {
            // given two requests before the same commit
            let frames = expectation(description: "frames displayed")
            frames.expectedFulfillmentCount = 2
            var first: [TimeInterval] = []
            var second: [TimeInterval] = []
            source.requestNextFrame {
                first.append($0)
                frames.fulfill()
            }
            source.requestNextFrame {
                second.append($0)
                frames.fulfill()
            }

            // when a frame is displayed, and then another
            wait(for: [frames], timeout: .longTimeout)
            waitForNextFrame()

            // then each fired once, with the same frame
            XCTAssertEqual(first.count, 1)
            XCTAssertEqual(second.count, 1)
            XCTAssertEqual(first, second)
        }

        func test_noWaiters_tearsDown() {
            // given an idle source
            XCTAssertFalse(source.isActive)

            // when a request is made, it starts up
            let frame = expectation(description: "frame displayed")
            source.requestNextFrame { _ in frame.fulfill() }
            XCTAssertTrue(source.isActive)

            // then once it is answered, nothing is left running
            wait(for: [frame], timeout: .longTimeout)
            XCTAssertFalse(source.isActive)
        }

        func test_stop_cancelsPendingRequests_andTearsDown() {
            // given a pending request
            var cancelledFired = false
            source.requestNextFrame { _ in cancelledFired = true }

            // when the source is stopped
            source.stop()

            // then it is torn down
            XCTAssertFalse(source.isActive)

            // and the cancelled request never fires, even after frames are displayed
            waitForNextFrame()
            XCTAssertFalse(cancelledFired)
        }

        func test_stopFromHandler_cancelsRestOfBatch() {
            // given two requests answered by the same frame, the first of which stops the source
            let frame = expectation(description: "frame displayed")
            var cancelledFired = false
            source.requestNextFrame { [unowned self] _ in
                source.stop()
                frame.fulfill()
            }
            source.requestNextFrame { _ in cancelledFired = true }

            // when that frame is displayed, and then another
            wait(for: [frame], timeout: .longTimeout)
            waitForNextFrame()

            // then the second request never fires
            XCTAssertFalse(cancelledFired)
        }
    }

#endif  // !os(watchOS) && !os(macOS)
