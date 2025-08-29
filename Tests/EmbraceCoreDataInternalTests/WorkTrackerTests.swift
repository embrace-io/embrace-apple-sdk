//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import EmbraceCommonInternal
import Foundation
import TestSupport
import XCTest

@testable import EmbraceCoreDataInternal

class WorkTrackerTests: XCTestCase {

    func test_idle() throws {

        let tracker = WorkTracker(name: "test", logger: MockLogger())

        let expectation = XCTestExpectation()

        tracker.onIdle {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .longTimeout)
    }

    func test_noDebounce() throws {

        let tracker = WorkTracker(name: "test", logger: MockLogger())

        let expectation = XCTestExpectation()

        let id = tracker.increment()
        tracker.decrement(id: id, afterDebounce: false)
        tracker.onIdle {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .longTimeout)
    }

    func test_withDebounce() throws {

        let tracker = WorkTracker(name: "test", logger: MockLogger())

        let expectation = XCTestExpectation()

        let id = tracker.increment()
        tracker.decrement(id: id, afterDebounce: true, debounceInterval: 0.1)
        tracker.onIdle {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: .longTimeout)
    }

    func test_tonsOfWork() throws {

        let tracker = WorkTracker(name: "test", logger: MockLogger())

        let expectation = XCTestExpectation()
        tracker.onIdle {
            expectation.fulfill()
        }

        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            let id = tracker.increment()
            DispatchQueue.global(qos: .default).async {
                tracker.decrement(id: id, afterDebounce: true, debounceInterval: 0.1)
            }
        }

        wait(for: [expectation], timeout: .longTimeout)
    }
}
