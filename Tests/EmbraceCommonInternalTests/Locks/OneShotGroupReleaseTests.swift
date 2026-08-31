//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCommonInternal

/// `DispatchGroup` traps on an unbalanced `leave()`, so any code path that must release a group
/// from several places needs the release to be idempotent. `Embrace.start()` is exactly that
/// shape: it returns through a success path, a kill-switch guard, an already-started guard, and
/// a throw, and `captureServicesGroup` must end up released exactly once.
final class OneShotGroupReleaseTests: XCTestCase {

    func test_release_satisfiesTheGroup() {
        let group = DispatchGroup()
        group.enter()
        let release = OneShotGroupRelease(group)

        XCTAssertEqual(group.wait(timeout: .now()), .timedOut, "group should be pending before release")

        release.release()

        XCTAssertEqual(group.wait(timeout: .now()), .success, "group should be satisfied after release")
    }

    func test_release_isIdempotent() {
        let group = DispatchGroup()
        group.enter()
        let release = OneShotGroupRelease(group)

        // A second leave() on a balanced group traps and takes the process down, so this
        // test failing means a crash, not an assertion failure.
        release.release()
        release.release()
        release.release()

        XCTAssertEqual(group.wait(timeout: .now()), .success)
    }

    func test_release_isIdempotentUnderConcurrency() {
        let group = DispatchGroup()
        group.enter()
        let release = OneShotGroupRelease(group)

        let iterations = 100
        let done = expectation(description: "all concurrent releases returned")
        done.expectedFulfillmentCount = iterations

        for _ in 0..<iterations {
            DispatchQueue.global().async {
                release.release()
                done.fulfill()
            }
        }

        wait(for: [done], timeout: .defaultTimeout)
        XCTAssertEqual(group.wait(timeout: .now()), .success)
    }

    func test_hasReleased_reportsState() {
        let group = DispatchGroup()
        group.enter()
        let release = OneShotGroupRelease(group)

        XCTAssertFalse(release.hasReleased)
        release.release()
        XCTAssertTrue(release.hasReleased)
    }
}
