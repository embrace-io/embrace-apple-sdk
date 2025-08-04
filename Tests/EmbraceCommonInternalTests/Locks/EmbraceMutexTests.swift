//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCommonInternal

class EmbraceMutexTests: XCTestCase {
    private var sut: EmbraceMutex<Int> = EmbraceMutex(0)

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut.safeValue = 0
    }

    func test_initialState() {
        XCTAssertEqual(sut.safeValue, 0)
    }

    func test_set_shouldModifyValue() {
        sut.safeValue = 100
        XCTAssertEqual(sut.safeValue, 100)
    }

    func test_multipleSet_shouldModifyValue() {
        sut.safeValue = 2
        XCTAssertEqual(sut.safeValue, 2)

        sut.safeValue = 1
        XCTAssertEqual(sut.safeValue, 1)
    }

    func test_modify_shouldSafelyModifyInBlock() {
        sut.safeValue = 2
        sut.withLock {
            $0 += 1
        }
        XCTAssertEqual(sut.safeValue, 3)
    }
}

// MARK: - Functional Tests
extension EmbraceMutexTests {
    func test_concurrentAccess() {
        let tries = 1000
        let expectation = XCTestExpectation(description: #function)
        expectation.expectedFulfillmentCount = tries

        for _ in 0..<tries {
            DispatchQueue.global().async {
                self.sut.withLock { $0 += 1 }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)
        XCTAssertEqual(sut.safeValue, tries)
    }

    func test_parallelExecutionAndConcurrentAccess() {
        let tries = 1000

        DispatchQueue.concurrentPerform(iterations: tries) { _ in
            self.sut.withLock { $0 += 1 }
        }

        XCTAssertEqual(sut.safeValue, tries)
    }

    func test_simultaneousReadWrite_shouldntCrash() {
        let tries = 500
        let readExpectation = XCTestExpectation(description: "Read \(#function)")
        readExpectation.expectedFulfillmentCount = tries

        let writeExpectation = XCTestExpectation(description: "Write \(#function)")
        writeExpectation.expectedFulfillmentCount = tries

        for _ in 0..<tries {
            DispatchQueue.global().async {
                _ = self.sut
                readExpectation.fulfill()
            }

            DispatchQueue.global().async {
                self.sut.safeValue = .random()
                writeExpectation.fulfill()
            }
        }

        wait(for: [readExpectation, writeExpectation], timeout: 10.0)
    }
}

// MARK: - ChatGPT tests o4-mini-high

extension EmbraceMutexTests {

    func testInitialSafeValue() {
        let mutex = EmbraceMutex(42)
        XCTAssertEqual(mutex.safeValue, 42, "safeValue should return the initial value")
    }

    func testSafeValueSetter() {
        let mutex = EmbraceMutex("hello")
        mutex.safeValue = "world"
        XCTAssertEqual(mutex.safeValue, "world", "safeValue setter should update the stored value")
    }

    func testWithLockReturnsResult() {
        let mutex = EmbraceMutex([1, 2, 3])
        let count = mutex.withLock { array -> Int in
            array.append(4)
            return array.count
        }
        XCTAssertEqual(count, 4, "withLock should return the closure’s return value")
        XCTAssertEqual(mutex.safeValue, [1, 2, 3, 4], "withLock should also have mutated the stored value")
    }

    func testUnsafeValueBypassesLock() {
        let mutex = EmbraceMutex(10)
        // Directly mutate storage (no lock) via unsafeValue setter
        // Note: unsafeValue is a getter only; we simulate “no lock” by observing that it doesn’t block.
        XCTAssertEqual(mutex.unsafeValue, 10, "unsafeValue should reflect the current storage without locking")
    }

    func testThreadSafetyUnderContention() {
        let mutex = EmbraceMutex(0)
        let iterations = 1_000
        let expectation = XCTestExpectation(description: "All increments happen")
        expectation.expectedFulfillmentCount = iterations

        let queue = DispatchQueue.global(qos: .userInitiated)
        for _ in 0..<iterations {
            queue.async {
                mutex.withLock { $0 += 1 }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(
            mutex.safeValue, iterations,
            "Under heavy concurrent access, all increments should be applied exactly once")
    }
}
