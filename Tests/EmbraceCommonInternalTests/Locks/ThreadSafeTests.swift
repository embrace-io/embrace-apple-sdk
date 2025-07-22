//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import TestSupport
import XCTest

@testable import EmbraceCommonInternal

class ThreadSafeTests: XCTestCase {
    @ThreadSafe private var sut: Int = 0

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = 0
    }

    func test_initialState() {
        XCTAssertEqual(sut, 0)
    }

    func test_set_shouldModifyValue() {
        sut = 100
        XCTAssertEqual(sut, 100)
    }

    func test_multipleSet_shouldModifyValue() {
        sut = 2
        XCTAssertEqual(sut, 2)

        sut = 1
        XCTAssertEqual(sut, 1)
    }

    func test_modify_shouldSafelyModifyInBlock() {
        sut = 2
        _sut.modify { value in
            value += 1
        }
        XCTAssertEqual(sut, 3)
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
                self._sut.modify { $0 += 1 }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)
        XCTAssertEqual(sut, tries)
    }

    func test_parallelExecutionAndConcurrentAccess() {
        let tries = 1000

        DispatchQueue.concurrentPerform(iterations: tries) { _ in
            self._sut.modify { $0 += 1 }
        }

        XCTAssertEqual(sut, tries)
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
                self.sut = .random()
                writeExpectation.fulfill()
            }
        }

        wait(for: [readExpectation, writeExpectation], timeout: 10.0)
    }
}
