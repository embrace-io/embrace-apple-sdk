//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

extension XCTestCase {

    /// Wait for a block to return true
    /// - Parameters:
    ///   - timeout: The longest time you are willing to wait
    ///   - interval: The interval in which to check the block
    ///   - block: A block to execute, return true 
    public func wait(timeout: TimeInterval = .defaultTimeout, interval: TimeInterval = 0.1, until block: @escaping () throws -> Bool) {
        let expectation = expectation(description: "wait for block to pass")
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            do {
                if try block() {
                    expectation.fulfill()
                }
            } catch {
                fatalError("Waiting for operation that threw an error: \(error)")
            }
        }

        wait(for: [expectation], timeout: timeout)
        timer.invalidate()
    }

    /// Waits the given amount of seconds
    /// - Parameter delay: Seconds to wait
    public func wait(delay: TimeInterval = .defaultTimeout) {
        let expectation = XCTestExpectation()

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            expectation.fulfill()
        }

        wait(for: [expectation])
    }
}
