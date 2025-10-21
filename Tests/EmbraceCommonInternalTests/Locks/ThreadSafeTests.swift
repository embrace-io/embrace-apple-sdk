//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCommonInternal

class ThreadSafeTests: XCTestCase {
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
        sut.withLock { value in
            value += 1
        }
        XCTAssertEqual(sut.safeValue, 3)
    }
}

// MARK: - Functional Tests
extension ThreadSafeTests {
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
