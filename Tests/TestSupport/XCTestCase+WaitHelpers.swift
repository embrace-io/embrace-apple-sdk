//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

extension XCTestCase {

    /// Polls `condition` on the main run loop until it returns `true` or `timeout` elapses.
    ///
    /// Prefer synchronizing with the work directly (`queue.sync {}` on the queue that does it, an
    /// injected `MockQueue`, or a `waitForAllWork()` hook) and asserting afterwards. Poll only when the
    /// work runs somewhere the test cannot reach, such as a URLSession round trip.
    ///
    /// The condition is checked once before any polling, so a condition that is already true returns
    /// immediately. On timeout the failure is recorded at the caller's `file`/`line` and names
    /// `description`. The condition must not assert or unwrap: it runs while the state is still
    /// settling, so `!`, `as!` and subscripts trap the whole test process. Use `waitForValue` to get
    /// the settled value back and assert on it afterwards.
    ///
    /// - Returns: Whether the condition became true within `timeout`.
    @discardableResult
    public func wait(
        _ description: String = "condition to become true",
        timeout: TimeInterval = .defaultTimeout,
        interval: TimeInterval = .shortInterval,
        file: StaticString = #filePath,
        line: UInt = #line,
        until condition: @escaping () -> Bool
    ) -> Bool {
        if condition() {
            return true
        }

        let expectation = XCTestExpectation(description: description)
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if condition() {
                expectation.fulfill()
            }
        }
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        timer.invalidate()

        if result == .completed || condition() {
            return true
        }
        XCTFail("Timed out after \(timeout)s waiting for \(description)", file: file, line: line)
        return false
    }

    /// Polls `produce` until it returns a non-nil value or `timeout` elapses, and returns that value.
    ///
    /// Use it to replace predicates that unwrap inside the poll: return the optional from the poll with
    /// `?.` and `.first`, then `XCTUnwrap` and assert on the result outside it.
    ///
    ///     let log = try XCTUnwrap(waitForValue("log in the current batch") {
    ///         self.logController.batcher.currentBatch()?.logs.first
    ///     })
    ///
    /// - Returns: The first non-nil value, or `nil` after recording a timeout failure.
    public func waitForValue<T>(
        _ description: String,
        timeout: TimeInterval = .defaultTimeout,
        interval: TimeInterval = .shortInterval,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ produce: @escaping () -> T?
    ) -> T? {
        var value: T?
        wait(description, timeout: timeout, interval: interval, file: file, line: line) {
            value = produce()
            return value != nil
        }
        return value
    }
}
