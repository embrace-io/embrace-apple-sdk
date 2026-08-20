//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import EmbraceOTelBridge

final class EmbraceSpanIdGeneratorTests: XCTestCase {

    var generator: EmbraceSpanIdGenerator!

    override func setUp() {
        super.setUp()
        generator = EmbraceSpanIdGenerator()
    }

    // MARK: - reserveNextSpanId returns a valid SpanId

    func test_reserveNextSpanId_returnsValidSpanId() {
        let spanId = generator.reserveNextSpanId()
        XCTAssertTrue(spanId.isValid)
    }

    // MARK: - generateSpanId returns the reserved ID when one exists

    func test_generateSpanId_returnsReservedId() {
        let reserved = generator.reserveNextSpanId()
        let generated = generator.generateSpanId()
        XCTAssertEqual(reserved, generated)
    }

    // MARK: - generateSpanId returns a fresh random ID when no reservation exists

    func test_generateSpanId_returnsFreshId_whenNoReservation() {
        let id = generator.generateSpanId()
        XCTAssertTrue(id.isValid)
    }

    // MARK: - generateTraceId delegates to the inner RandomIdGenerator

    func test_generateTraceId_returnsValidTraceId() {
        let traceId = generator.generateTraceId()
        XCTAssertTrue(traceId.isValid)
    }

    func test_generateTraceId_returnsDifferentIdsOnSubsequentCalls() {
        let id1 = generator.generateTraceId()
        let id2 = generator.generateTraceId()
        XCTAssertNotEqual(id1, id2)
    }

    // MARK: - Reserved ID is consumed after one call to generateSpanId

    func test_reservedId_isConsumedAfterOneGenerate() {
        let reserved = generator.reserveNextSpanId()
        let first = generator.generateSpanId()
        let second = generator.generateSpanId()

        // First call should return the reserved ID
        XCTAssertEqual(first, reserved)
        // Second call should return a different (fresh) ID
        XCTAssertNotEqual(second, reserved)
    }

    // MARK: - Thread safety

    func test_concurrentReserveAndGenerate_doesNotCrash() {
        let iterations = 1000
        let expectation = expectation(description: "concurrent access completes")
        expectation.expectedFulfillmentCount = iterations * 2

        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        for _ in 0..<iterations {
            queue.async {
                _ = self.generator.reserveNextSpanId()
                expectation.fulfill()
            }
            queue.async {
                _ = self.generator.generateSpanId()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func test_concurrentGenerateSpanId_producesUniqueIds() {
        let iterations = 100
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        var ids = [SpanId]()
        let lock = NSLock()

        for _ in 0..<iterations {
            group.enter()
            queue.async {
                let id = self.generator.generateSpanId()
                lock.lock()
                ids.append(id)
                lock.unlock()
                group.leave()
            }
        }

        group.wait()
        let uniqueIds = Set(ids.map { $0.hexString })
        XCTAssertEqual(uniqueIds.count, iterations, "All generated span IDs should be unique")
    }
}
