//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

final class SessionHeartbeatTests: XCTestCase {

    let queue = DispatchQueue(label: "com.embrace.test.heartbeat")

    func test_invalidInterval() throws {
        // when initializing a heartbeat with an invalid interval
        let heartbeat1 = SessionHeartbeat(queue: queue, interval: 0)
        let heartbeat2 = SessionHeartbeat(queue: queue, interval: -1)

        // then the interval is set to the default
        XCTAssertEqual(heartbeat1.interval, SessionHeartbeat.defaultInterval)
        XCTAssertEqual(heartbeat2.interval, SessionHeartbeat.defaultInterval)
    }

    func test_validInterval() throws {
        // when initializing a heartbeat with a valid interval
        let heartbeat1 = SessionHeartbeat(queue: queue, interval: 3)
        let heartbeat2 = SessionHeartbeat(queue: queue, interval: 15)

        // then the interval is correctly set
        XCTAssertEqual(heartbeat1.interval, 3)
        XCTAssertEqual(heartbeat2.interval, 15)
    }

    func test_callback() throws {
        let expectation = XCTestExpectation()

        // given a heartbeat
        let heartbeat = SessionHeartbeat(queue: queue, interval: 0.1)

        // given a callback
        heartbeat.callback = {
            expectation.fulfill()
            heartbeat.stop()
        }

        // when the the hearbeat is started
        heartbeat.start()

        // then the callback is called after 1 second
        wait(for: [expectation], timeout: .defaultTimeout)
    }
}
