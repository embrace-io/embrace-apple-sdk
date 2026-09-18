//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
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

    // MARK: - withReservation reserves a valid SpanId

    func test_withReservation_providesValidSpanId() {
        var reserved: SpanId?
        generator.withReservation { reserved = $0 }

        XCTAssertNotNil(reserved)
        XCTAssertTrue(reserved!.isValid)
    }

    func test_withReservation_returnsClosureValue() {
        let result = generator.withReservation { _ in "value" }
        XCTAssertEqual(result, "value")
    }

    func test_withReservation_rethrowsClosureError() {
        struct TestError: Error {}

        XCTAssertThrowsError(
            try generator.withReservation { _ -> Void in
                throw TestError()
            }
        )
    }

    // MARK: - generateSpanId returns the reservation while it is held

    func test_generateSpanId_returnsReservedId_insideReservation() {
        generator.withReservation { reserved in
            XCTAssertEqual(generator.generateSpanId(), reserved)
        }
    }

    // MARK: - generateSpanId returns a fresh random ID when no reservation exists

    func test_generateSpanId_returnsFreshId_whenNoReservation() {
        let id = generator.generateSpanId()
        XCTAssertTrue(id.isValid)
    }

    func test_generateSpanId_returnsFreshId_afterReservationEnds() {
        var reserved: SpanId?
        generator.withReservation { reserved = $0 }

        XCTAssertNotEqual(generator.generateSpanId(), reserved)
    }

    // MARK: - The reservation is consumed exactly once

    func test_reservedId_isConsumedByFirstGenerateOnly() {
        generator.withReservation { reserved in
            let first = generator.generateSpanId()
            let second = generator.generateSpanId()

            XCTAssertEqual(first, reserved)
            XCTAssertNotEqual(second, reserved)
        }
    }

    // MARK: - The reservation is released even when it was never consumed

    func test_reservation_isReleased_whenNeverConsumed() {
        var reserved: SpanId?
        generator.withReservation { reserved = $0 }

        // The unconsumed reservation must not leak into the next span created on this thread.
        generator.withReservation { next in
            XCTAssertNotEqual(next, reserved)
            XCTAssertEqual(generator.generateSpanId(), next)
        }
    }

    func test_reservation_isReleased_whenClosureThrows() {
        struct TestError: Error {}

        var reserved: SpanId?
        try? generator.withReservation { id -> Void in
            reserved = id
            throw TestError()
        }

        XCTAssertNotEqual(generator.generateSpanId(), reserved)
    }

    // MARK: - Reservations are per-thread

    func test_reservation_isNotVisibleToOtherThreads() {
        let otherThreadDidGenerate = expectation(description: "other thread generated an id")
        let idFromOtherThread = EmbraceMutex<SpanId?>(nil)

        generator.withReservation { reserved in
            DispatchQueue.global().async {
                idFromOtherThread.withLock { $0 = self.generator.generateSpanId() }
                otherThreadDidGenerate.fulfill()
            }
            wait(for: [otherThreadDidGenerate], timeout: 10.0)

            // The other thread had no reservation of its own, so it must not have taken ours.
            XCTAssertNotEqual(idFromOtherThread.safeValue, reserved)

            // Ours is still here to be consumed.
            XCTAssertEqual(generator.generateSpanId(), reserved)
        }
    }

    func test_concurrentReservations_doNotCrossWires() {
        let iterations = 500
        let mismatches = EmbraceMutex(0)

        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            generator.withReservation { reserved in
                if generator.generateSpanId() != reserved {
                    mismatches.withLock { $0 += 1 }
                }
            }
        }

        XCTAssertEqual(mismatches.safeValue, 0, "Concurrent reservations consumed each other's IDs")
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

    // MARK: - Thread safety

    func test_concurrentGenerateSpanId_producesUniqueIds() {
        let iterations = 100
        let ids = EmbraceMutex([SpanId]())

        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            let id = generator.generateSpanId()
            ids.withLock { $0.append(id) }
        }

        let uniqueIds = Set(ids.safeValue.map { $0.hexString })
        XCTAssertEqual(uniqueIds.count, iterations, "All generated span IDs should be unique")
    }
}
